import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Scrypt tel que l'utilisent Litecoin et Dogecoin : N=1024, r=1, p=1.
///
/// Contrairement a SHA-256, cet algorithme est concu pour couter de la
/// memoire : chaque hachage remplit et relit un tableau de 128 kio. C'etait le
/// pari de Litecoin en 2011 - rendre les machines dediees inutiles. Le pari a
/// echoue, mais la contrainte demeure : un hachage Scrypt coute environ mille
/// fois plus cher qu'un double SHA-256.
///
/// Piege classique de l'implementation, rencontre pendant l'ecriture : dans la
/// rotation de Salsa20, l'addition doit etre ramenee a 32 bits **avant** de
/// tourner. Sans cela le resultat reste plausible mais faux.
class Scrypt {
  Scrypt() : _v = Uint8List(128 * _n);

  static const int _n = 1024;

  /// Le tableau de 128 kio, alloue une fois et reutilise a chaque hachage.
  final Uint8List _v;
  final Uint8List _x = Uint8List(128);
  final Uint8List _y = Uint8List(128);
  final Uint8List _block = Uint8List(64);
  final Uint32List _salsa = Uint32List(16);
  final Uint32List _origin = Uint32List(16);

  static int _rotl(int value, int bits) {
    final v = value & 0xFFFFFFFF;
    return ((v << bits) | (v >> (32 - bits))) & 0xFFFFFFFF;
  }

  /// Noyau Salsa20/8 : quatre doubles rondes sur seize mots.
  void _salsaCore(Uint8List data, int offset) {
    final x = _salsa;
    for (var i = 0; i < 16; i++) {
      final j = offset + i * 4;
      x[i] = data[j] |
          (data[j + 1] << 8) |
          (data[j + 2] << 16) |
          (data[j + 3] << 24);
      _origin[i] = x[i];
    }

    for (var round = 0; round < 4; round++) {
      x[4] ^= _rotl(x[0] + x[12], 7);
      x[8] ^= _rotl(x[4] + x[0], 9);
      x[12] ^= _rotl(x[8] + x[4], 13);
      x[0] ^= _rotl(x[12] + x[8], 18);
      x[9] ^= _rotl(x[5] + x[1], 7);
      x[13] ^= _rotl(x[9] + x[5], 9);
      x[1] ^= _rotl(x[13] + x[9], 13);
      x[5] ^= _rotl(x[1] + x[13], 18);
      x[14] ^= _rotl(x[10] + x[6], 7);
      x[2] ^= _rotl(x[14] + x[10], 9);
      x[6] ^= _rotl(x[2] + x[14], 13);
      x[10] ^= _rotl(x[6] + x[2], 18);
      x[3] ^= _rotl(x[15] + x[11], 7);
      x[7] ^= _rotl(x[3] + x[15], 9);
      x[11] ^= _rotl(x[7] + x[3], 13);
      x[15] ^= _rotl(x[11] + x[7], 18);

      x[1] ^= _rotl(x[0] + x[3], 7);
      x[2] ^= _rotl(x[1] + x[0], 9);
      x[3] ^= _rotl(x[2] + x[1], 13);
      x[0] ^= _rotl(x[3] + x[2], 18);
      x[6] ^= _rotl(x[5] + x[4], 7);
      x[7] ^= _rotl(x[6] + x[5], 9);
      x[4] ^= _rotl(x[7] + x[6], 13);
      x[5] ^= _rotl(x[4] + x[7], 18);
      x[11] ^= _rotl(x[10] + x[9], 7);
      x[8] ^= _rotl(x[11] + x[10], 9);
      x[9] ^= _rotl(x[8] + x[11], 13);
      x[10] ^= _rotl(x[9] + x[8], 18);
      x[12] ^= _rotl(x[15] + x[14], 7);
      x[13] ^= _rotl(x[12] + x[15], 9);
      x[14] ^= _rotl(x[13] + x[12], 13);
      x[15] ^= _rotl(x[14] + x[13], 18);
    }

    for (var i = 0; i < 16; i++) {
      final value = (x[i] + _origin[i]) & 0xFFFFFFFF;
      final j = offset + i * 4;
      data[j] = value & 0xff;
      data[j + 1] = (value >> 8) & 0xff;
      data[j + 2] = (value >> 16) & 0xff;
      data[j + 3] = (value >> 24) & 0xff;
    }
  }

  /// BlockMix pour r=1 : deux blocs de 64 octets melanges en chaine.
  void _blockMix(Uint8List input, Uint8List output) {
    // X part du dernier bloc.
    for (var i = 0; i < 64; i++) {
      _block[i] = input[64 + i];
    }
    for (var i = 0; i < 2; i++) {
      for (var j = 0; j < 64; j++) {
        _block[j] ^= input[i * 64 + j];
      }
      _salsaCore(_block, 0);
      for (var j = 0; j < 64; j++) {
        output[i * 64 + j] = _block[j];
      }
    }
  }

  /// ROMix : mille vingt-quatre passages aller, puis autant en acces
  /// aleatoire. C'est cette seconde boucle qui rend l'algorithme couteux en
  /// memoire : impossible de deviner a l'avance quel bloc sera relu.
  void _roMix() {
    for (var i = 0; i < _n; i++) {
      for (var j = 0; j < 128; j++) {
        _v[i * 128 + j] = _x[j];
      }
      _blockMix(_x, _y);
      for (var j = 0; j < 128; j++) {
        _x[j] = _y[j];
      }
    }

    for (var i = 0; i < _n; i++) {
      final j = (_x[64] |
              (_x[65] << 8) |
              (_x[66] << 16) |
              (_x[67] << 24)) &
          (_n - 1);
      for (var k = 0; k < 128; k++) {
        _x[k] ^= _v[j * 128 + k];
      }
      _blockMix(_x, _y);
      for (var k = 0; k < 128; k++) {
        _x[k] = _y[k];
      }
    }
  }

  /// PBKDF2-HMAC-SHA256 avec une seule iteration, le cas utilise par Scrypt.
  static Uint8List _pbkdf2(List<int> password, List<int> salt, int length) {
    final hmac = Hmac(sha256, password);
    final out = Uint8List(length);
    var written = 0;
    var block = 1;
    while (written < length) {
      final input = <int>[
        ...salt,
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];
      final digest = hmac.convert(input).bytes;
      final take =
          (length - written) < digest.length ? (length - written) : digest.length;
      for (var i = 0; i < take; i++) {
        out[written + i] = digest[i];
      }
      written += take;
      block++;
    }
    return out;
  }

  /// Hachage Scrypt d'un en-tete de bloc : le sel est l'en-tete lui-meme.
  Uint8List hash(Uint8List header) {
    final initial = _pbkdf2(header, header, 128);
    for (var i = 0; i < 128; i++) {
      _x[i] = initial[i];
    }
    _roMix();
    return _pbkdf2(header, _x, 32);
  }
}
