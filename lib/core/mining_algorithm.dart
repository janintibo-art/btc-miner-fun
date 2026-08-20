import 'dart:typed_data';

import 'bitcoin_utils.dart';
import 'scrypt.dart';

/// Les algorithmes que le moteur sait calculer.
///
/// Chacun apporte trois choses : sa fonction de hachage, sa cible de reference
/// (la difficulte 1 n'est pas la meme partout), et le nombre de hachages qu'il
/// est raisonnable d'enchainer avant de rendre la main a l'interface. Un
/// hachage Scrypt coute environ mille fois un double SHA-256 : garder des lots
/// de mille figerait l'affichage plusieurs secondes.
enum MiningAlgorithm {
  sha256d(
    label: 'SHA-256d',
    batchSize: 1000,
    diff1Hex:
        '00000000FFFF0000000000000000000000000000000000000000000000000000',
    coins: <String>['BTC', 'BCH', 'BSV', 'XEC', 'DGB', 'NMC', 'PPC'],
    description:
        'Deux passages de SHA-256. Rapide, sans besoin de memoire, et '
        'totalement domine par les machines dediees.',
  ),
  scrypt(
    label: 'Scrypt',
    batchSize: 4,
    diff1Hex:
        '0000FFFF00000000000000000000000000000000000000000000000000000000',
    coins: <String>['LTC', 'DOGE'],
    description:
        'Chaque hachage remplit et relit 128 kio de memoire. Environ mille '
        'fois plus lent que SHA-256d, et c\'etait le but : rendre les machines '
        'dediees inutiles. Elles sont arrivees quand meme, en 2014.',
  );

  const MiningAlgorithm({
    required this.label,
    required this.batchSize,
    required this.diff1Hex,
    required this.coins,
    required this.description,
  });

  final String label;

  /// Hachages enchaines avant de rendre la main.
  final int batchSize;

  /// Cible correspondant a la difficulte 1 sur cette famille de chaines.
  final String diff1Hex;

  /// Symboles des monnaies concernees.
  final List<String> coins;

  final String description;

  static MiningAlgorithm forCoin(String symbol) {
    for (final algorithm in MiningAlgorithm.values) {
      if (algorithm.coins.contains(symbol)) return algorithm;
    }
    return MiningAlgorithm.sha256d;
  }

  static MiningAlgorithm fromName(String? name) => MiningAlgorithm.values
      .firstWhere((a) => a.name == name, orElse: () => MiningAlgorithm.sha256d);

  /// Cible correspondant a une difficulte de pool, pour cet algorithme.
  Uint8List targetForDifficulty(double difficulty) {
    if (difficulty <= 0) difficulty = 1;
    final diff1 = BigInt.parse(diff1Hex, radix: 16);
    const scale = 1000000;
    final scaled = BigInt.from((difficulty * scale).round());
    return bigIntTo32Bytes((diff1 * BigInt.from(scale)) ~/ scaled);
  }
}

/// Enveloppe un algorithme pour le moteur : tampons prets, une seule methode.
class AlgorithmRunner {
  AlgorithmRunner(this.algorithm)
      : _scrypt = algorithm == MiningAlgorithm.scrypt ? Scrypt() : null;

  final MiningAlgorithm algorithm;
  final Scrypt? _scrypt;

  /// Hachage complet de l'en-tete, nonce deja ecrit dedans.
  Uint8List hash(Uint8List header80) {
    switch (algorithm) {
      case MiningAlgorithm.sha256d:
        return sha256d(header80);
      case MiningAlgorithm.scrypt:
        return _scrypt!.hash(header80);
    }
  }
}
