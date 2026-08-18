import 'dart:typed_data';

/// SHA-256 ecrit a la main, pense pour le minage.
///
/// Deux differences avec une implementation generique :
///
///  - **Le midstate.** L'en-tete fait 80 octets et SHA-256 travaille par blocs
///    de 64. Le premier bloc ne contient jamais le nonce : il est identique
///    pour des milliards de tentatives, donc calcule une seule fois par
///    travail. C'est un tiers du calcul supprime.
///  - **Zero allocation.** Les tampons sont reutilises d'un hachage a l'autre,
///    la ou un appel generique cree des objets a chaque tentative.
class Sha256Fast {
  static const List<int> _k = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static const List<int> _iv = <int>[
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  ];

  final Uint32List _w = Uint32List(64);
  final Uint32List _state = Uint32List(8);
  final Uint32List _midstate = Uint32List(8);
  final Uint32List _first = Uint32List(8);
  final Uint8List _digest = Uint8List(32);

  static int _rotr(int x, int n) =>
      ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;

  /// Compression d'un bloc : les 16 premiers mots de [_w] doivent etre remplis.
  void _compress(Uint32List h) {
    final w = _w;
    for (var i = 16; i < 64; i++) {
      final x = w[i - 15];
      final y = w[i - 2];
      final s0 = _rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3);
      final s1 = _rotr(y, 17) ^ _rotr(y, 19) ^ (y >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
    }

    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];

    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
      final t1 = (hh + s1 + ch + _k[i] + w[i]) & 0xFFFFFFFF;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xFFFFFFFF;

      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xFFFFFFFF;
    }

    h[0] = (h[0] + a) & 0xFFFFFFFF;
    h[1] = (h[1] + b) & 0xFFFFFFFF;
    h[2] = (h[2] + c) & 0xFFFFFFFF;
    h[3] = (h[3] + d) & 0xFFFFFFFF;
    h[4] = (h[4] + e) & 0xFFFFFFFF;
    h[5] = (h[5] + f) & 0xFFFFFFFF;
    h[6] = (h[6] + g) & 0xFFFFFFFF;
    h[7] = (h[7] + hh) & 0xFFFFFFFF;
  }

  void _loadBlock(Uint8List data, int offset) {
    final w = _w;
    for (var i = 0; i < 16; i++) {
      final j = offset + i * 4;
      w[i] = (data[j] << 24) |
          (data[j + 1] << 16) |
          (data[j + 2] << 8) |
          data[j + 3];
    }
  }

  /// Calcule et memorise l'etat intermediaire des 64 premiers octets de
  /// l'en-tete. A appeler une fois par travail recu du pool.
  void prepare(Uint8List header80) {
    _midstate.setAll(0, _iv);
    _loadBlock(header80, 0);
    _compress(_midstate);

    // Le second bloc : les 16 derniers octets de l'en-tete, dont le nonce.
    _tail0 = (header80[64] << 24) |
        (header80[65] << 16) |
        (header80[66] << 8) |
        header80[67];
    _tail1 = (header80[68] << 24) |
        (header80[69] << 16) |
        (header80[70] << 8) |
        header80[71];
    _tail2 = (header80[72] << 24) |
        (header80[73] << 16) |
        (header80[74] << 8) |
        header80[75];
  }

  int _tail0 = 0;
  int _tail1 = 0;
  int _tail2 = 0;

  /// Hache l'en-tete prepare avec ce nonce, et renvoie le mot de poids fort du
  /// resultat (celui qui doit etre nul pour une solution valable).
  ///
  /// Le resultat complet reste disponible dans [digest] : on ne le serialise
  /// que si le rejet precoce ne suffit pas a trancher.
  int hashNonce(int nonce) {
    final w = _w;

    // --- Premier SHA-256 : second bloc, en repartant du midstate ---
    w[0] = _tail0;
    w[1] = _tail1;
    w[2] = _tail2;
    // Le nonce est stocke en petit-boutiste dans l'en-tete.
    w[3] = ((nonce & 0xff) << 24) |
        (((nonce >> 8) & 0xff) << 16) |
        (((nonce >> 16) & 0xff) << 8) |
        ((nonce >> 24) & 0xff);
    w[4] = 0x80000000;
    for (var i = 5; i < 15; i++) {
      w[i] = 0;
    }
    w[15] = 640; // 80 octets = 640 bits

    _first.setAll(0, _midstate);
    _compress(_first);

    // --- Second SHA-256 : les 32 octets du premier resultat ---
    for (var i = 0; i < 8; i++) {
      w[i] = _first[i];
    }
    w[8] = 0x80000000;
    for (var i = 9; i < 15; i++) {
      w[i] = 0;
    }
    w[15] = 256; // 32 octets = 256 bits

    _state.setAll(0, _iv);
    _compress(_state);

    // Le mot 7 forme les 4 derniers octets du hash, donc les 4 premiers une
    // fois le hash retourne : c'est la partie qui doit etre nulle.
    return _state[7];
  }

  /// Serialise le dernier resultat de [hashNonce] en 32 octets.
  Uint8List digest() {
    for (var i = 0; i < 8; i++) {
      final v = _state[i];
      _digest[i * 4] = (v >> 24) & 0xff;
      _digest[i * 4 + 1] = (v >> 16) & 0xff;
      _digest[i * 4 + 2] = (v >> 8) & 0xff;
      _digest[i * 4 + 3] = v & 0xff;
    }
    return _digest;
  }

  /// Double SHA-256 complet, sans midstate : sert de reference et de point de
  /// comparaison dans le banc d'essai.
  Uint8List doubleHashFull(Uint8List data80) {
    _state.setAll(0, _iv);
    _loadBlock(data80, 0);
    _compress(_state);

    final w = _w;
    w[0] = (data80[64] << 24) |
        (data80[65] << 16) |
        (data80[66] << 8) |
        data80[67];
    w[1] = (data80[68] << 24) |
        (data80[69] << 16) |
        (data80[70] << 8) |
        data80[71];
    w[2] = (data80[72] << 24) |
        (data80[73] << 16) |
        (data80[74] << 8) |
        data80[75];
    w[3] = (data80[76] << 24) |
        (data80[77] << 16) |
        (data80[78] << 8) |
        data80[79];
    w[4] = 0x80000000;
    for (var i = 5; i < 15; i++) {
      w[i] = 0;
    }
    w[15] = 640;
    _compress(_state);

    for (var i = 0; i < 8; i++) {
      _first[i] = _state[i];
      w[i] = _state[i];
    }
    w[8] = 0x80000000;
    for (var i = 9; i < 15; i++) {
      w[i] = 0;
    }
    w[15] = 256;
    _state.setAll(0, _iv);
    _compress(_state);
    return digest();
  }
}
