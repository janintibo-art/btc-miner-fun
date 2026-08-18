import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'bitcoin_utils.dart';

/// Resultat du banc d'avalanche.
class AvalancheResult {
  const AvalancheResult({
    required this.trials,
    required this.averageBitsChanged,
    required this.minBitsChanged,
    required this.maxBitsChanged,
    required this.exampleBefore,
    required this.exampleAfter,
    required this.exampleBitsChanged,
    required this.exampleBitFlipped,
  });

  final int trials;
  final double averageBitsChanged;
  final int minBitsChanged;
  final int maxBitsChanged;

  final String exampleBefore;
  final String exampleAfter;
  final int exampleBitsChanged;
  final int exampleBitFlipped;

  /// Un hachage ideal change la moitie des 256 bits de sortie.
  double get percentChanged => averageBitsChanged / 256 * 100;
}

/// Change un seul bit de l'en-tete et compte combien de bits changent dans le
/// hash. C'est la demonstration, en une seconde, de pourquoi aucun calcul
/// approche n'est possible : un bit d'entree modifie la moitie de la sortie.
Future<AvalancheResult> runAvalancheTest({int trials = 400}) =>
    Isolate.run(() => _avalanche(trials));

AvalancheResult _avalanche(int trials) {
  final random = Random(20081031); // date du livre blanc de Bitcoin
  final header = Uint8List(80);
  for (var i = 0; i < 80; i++) {
    header[i] = random.nextInt(256);
  }

  var total = 0;
  var minimum = 256;
  var maximum = 0;
  var exampleBefore = '';
  var exampleAfter = '';
  var exampleBits = 0;
  var exampleFlipped = 0;

  for (var trial = 0; trial < trials; trial++) {
    final before = sha256d(header);

    final bitIndex = random.nextInt(80 * 8);
    final byteIndex = bitIndex ~/ 8;
    final mask = 1 << (bitIndex % 8);
    header[byteIndex] ^= mask;

    final after = sha256d(header);
    var changed = 0;
    for (var i = 0; i < 32; i++) {
      changed += _popcount(before[i] ^ after[i]);
    }

    total += changed;
    if (changed < minimum) minimum = changed;
    if (changed > maximum) maximum = changed;
    if (trial == 0) {
      exampleBefore = bytesToHex(reverseBytes(before));
      exampleAfter = bytesToHex(reverseBytes(after));
      exampleBits = changed;
      exampleFlipped = bitIndex;
    }
    // Le bit reste inverse : chaque essai part de l'en-tete precedent.
  }

  return AvalancheResult(
    trials: trials,
    averageBitsChanged: total / trials,
    minBitsChanged: minimum,
    maxBitsChanged: maximum,
    exampleBefore: exampleBefore,
    exampleAfter: exampleAfter,
    exampleBitsChanged: exampleBits,
    exampleBitFlipped: exampleFlipped,
  );
}

int _popcount(int byte) {
  var count = 0;
  var value = byte;
  while (value != 0) {
    count += value & 1;
    value >>= 1;
  }
  return count;
}
