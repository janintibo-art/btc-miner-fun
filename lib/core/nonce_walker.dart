import 'dart:math';

import 'package:crypto/crypto.dart';

import 'bitcoin_utils.dart';

/// La strategie d'exploration de l'espace des nonces.
///
/// Aucune ne change la probabilite de trouver une solution : chaque nonce a
/// exactement la meme chance que les autres, et il y en a 4 294 967 296 a
/// tester par travail. Ce qui change, c'est le chemin parcouru, et la
/// garantie de ne jamais repasser deux fois au meme endroit.
enum NonceStrategy {
  /// Nonce + 1 a chaque tentative. Simple, previsible.
  sequentielle,

  /// Tirage pseudo-aleatoire. Peut retomber sur un nonce deja teste.
  aleatoire,

  /// Ta marche personnelle : une permutation de tout l'espace des nonces,
  /// derivee de ta phrase signature. Elle passe par les 4 milliards de nonces
  /// exactement une fois chacun, dans un ordre que personne d'autre n'a.
  signature,
}

extension NonceStrategyInfo on NonceStrategy {
  String get label => switch (this) {
        NonceStrategy.sequentielle => 'Sequentielle',
        NonceStrategy.aleatoire => 'Aleatoire',
        NonceStrategy.signature => 'Signature',
      };

  String get description => switch (this) {
        NonceStrategy.sequentielle =>
          'On part d\'un nonce tire au sort et on avance de un en un. '
              'Aucune repetition, mais un chemin identique pour tout le monde.',
        NonceStrategy.aleatoire =>
          'Chaque tentative tire un nonce au hasard. Statistiquement, un '
              'nonce sur trois aura deja ete teste au bout d\'un tour complet.',
        NonceStrategy.signature =>
          'Une permutation complete de l\'espace des nonces, calculee a partir '
              'de ta phrase. Elle visite les quatre milliards de nonces une '
              'fois chacun, dans un ordre qui n\'appartient qu\'a toi.',
      };

  static NonceStrategy fromName(String? name) => NonceStrategy.values.firstWhere(
        (s) => s.name == name,
        orElse: () => NonceStrategy.signature,
      );
}

/// Les trois constantes tirees d'une phrase signature.
class NonceSignature {
  const NonceSignature(this.multiplier, this.increment, this.start);

  final int multiplier;
  final int increment;
  final int start;

  /// Derive une signature d'une phrase quelconque.
  ///
  /// Les conditions de Hull-Dobell garantissent que la suite passe par les
  /// 2^32 nonces avant de boucler : multiplicateur congru a 1 modulo 4,
  /// increment impair.
  factory NonceSignature.fromPhrase(String phrase) {
    final digest = sha256.convert(phrase.codeUnits).bytes;
    int word(int i) =>
        (digest[i] << 24) | (digest[i + 1] << 16) | (digest[i + 2] << 8) | digest[i + 3];

    final multiplier = (word(0) & 0xFFFFFFFC) | 1; // ... 01 en binaire
    final increment = word(4) | 1; // impair
    final start = word(8);
    return NonceSignature(multiplier, increment, start);
  }

  /// Representation courte, affichable : la carte d'identite de ta marche.
  String get fingerprint =>
      '${multiplier.toRadixString(16).padLeft(8, '0')}-'
      '${increment.toRadixString(16).padLeft(8, '0')}';

  Map<String, int> toMap() => {'a': multiplier, 'c': increment, 's': start};

  factory NonceSignature.fromMap(Map<dynamic, dynamic> m) =>
      NonceSignature(m['a'] as int, m['c'] as int, m['s'] as int);
}

/// Produit la suite de nonces a tester pour un coeur donne.
class NonceWalker {
  NonceWalker._(this._state, this._a, this._c, this._random);

  int _state;
  final int _a;
  final int _c;
  final Random? _random;

  static const int _mask = 0xFFFFFFFF;

  /// [offset] est l'indice du coeur, [stride] le nombre de coeurs : chaque
  /// coeur avance de `stride` pas dans la suite, ils ne se recoupent donc
  /// jamais.
  factory NonceWalker.create({
    required NonceStrategy strategy,
    required NonceSignature signature,
    required int startNonce,
    required int offset,
    required int stride,
  }) {
    switch (strategy) {
      case NonceStrategy.sequentielle:
        return NonceWalker._((startNonce + offset) & _mask, 1, stride, null);

      case NonceStrategy.aleatoire:
        return NonceWalker._(0, 0, 0, Random(startNonce + offset));

      case NonceStrategy.signature:
        // Etat de depart : la suite avancee `offset` fois.
        var state = signature.start;
        for (var i = 0; i < offset; i++) {
          state = (signature.multiplier * state + signature.increment) & _mask;
        }
        // Pas du coeur : la suite composee avec elle-meme `stride` fois.
        var a = 1, c = 0;
        for (var i = 0; i < stride; i++) {
          c = (signature.multiplier * c + signature.increment) & _mask;
          a = (a * signature.multiplier) & _mask;
        }
        return NonceWalker._(state, a, c, null);
    }
  }

  /// Le prochain nonce a tester.
  int next() {
    final random = _random;
    if (random != null) return random.nextInt(0x100000000);
    final current = _state;
    _state = (_a * _state + _c) & _mask;
    return current;
  }
}

/// Phrase signature par defaut : derivee de l'adresse et du nom du worker,
/// pour que deux appareils du meme utilisateur n'explorent pas la meme suite.
String defaultSignaturePhrase(String wallet, String worker) {
  final base = '$wallet/$worker';
  return base.isEmpty ? 'btc-miner-fun' : base;
}

/// Empreinte lisible d'une phrase, utilisee dans l'interface.
String signatureFingerprint(String phrase) =>
    NonceSignature.fromPhrase(phrase).fingerprint;

/// Verifie les conditions de Hull-Dobell, exposees pour les tests.
bool signatureCoversWholeSpace(NonceSignature s) =>
    s.multiplier % 4 == 1 && s.increment.isOdd;

/// Petit utilitaire de mise en forme, reutilise par l'interface.
String describeSignature(NonceSignature s) =>
    'a=${bytesToHex([
          (s.multiplier >> 24) & 0xff,
          (s.multiplier >> 16) & 0xff,
          (s.multiplier >> 8) & 0xff,
          s.multiplier & 0xff
        ])} '
    'c=${bytesToHex([
          (s.increment >> 24) & 0xff,
          (s.increment >> 16) & 0xff,
          (s.increment >> 8) & 0xff,
          s.increment & 0xff
        ])}';
