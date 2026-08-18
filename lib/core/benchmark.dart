import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'bitcoin_utils.dart';
import 'hash_mode.dart';
import 'sha256_fast.dart';

/// Resultat du banc d'essai : le debit mesure pour chaque moteur, sur un seul
/// coeur, avec exactement le meme en-tete.
class BenchmarkResult {
  const BenchmarkResult(this.rates, this.identical);

  /// Hachages par seconde, par moteur.
  final Map<HashMode, double> rates;

  /// Vrai si les trois moteurs ont produit le meme hash : la preuve que le
  /// gain de vitesse ne coute aucune justesse.
  final bool identical;

  double get best => rates.values.fold(0.0, (a, b) => a > b ? a : b);

  double gainOver(HashMode reference, HashMode mode) {
    final r = rates[reference] ?? 0;
    final m = rates[mode] ?? 0;
    if (r <= 0) return 0;
    return m / r;
  }
}

/// Lance la mesure dans un isolate separe : l'interface reste fluide pendant
/// les quelques secondes de calcul intensif.
Future<BenchmarkResult> runBenchmarkOnDevice({int millisPerMode = 2500}) async {
  final raw = await Isolate.run(() => _measure(millisPerMode));
  return BenchmarkResult(
    {
      HashMode.compatible: raw['compatible'] as double,
      HashMode.maison: raw['maison'] as double,
      HashMode.midstate: raw['midstate'] as double,
    },
    raw['identical'] as bool,
  );
}

Map<String, dynamic> _measure(int millisPerMode) {
  final random = Random(20090103); // date du bloc de genese, pour reproduire
  final header = Uint8List(80);
  for (var i = 0; i < 80; i++) {
    header[i] = random.nextInt(256);
  }

  final fast = Sha256Fast();

  // Verification prealable : les trois chemins doivent donner le meme hash.
  const probe = 123456;
  header[76] = probe & 0xff;
  header[77] = (probe >> 8) & 0xff;
  header[78] = (probe >> 16) & 0xff;
  header[79] = (probe >> 24) & 0xff;
  final reference = bytesToHex(sha256d(header));
  final full = bytesToHex(fast.doubleHashFull(header));
  fast.prepare(header);
  fast.hashNonce(probe);
  final mid = bytesToHex(fast.digest());
  final identical = reference == full && reference == mid;

  double measure(void Function(int nonce) hashOne, {bool prepare = false}) {
    if (prepare) fast.prepare(header);
    final start = DateTime.now().microsecondsSinceEpoch;
    final deadline = start + millisPerMode * 1000;
    var count = 0;
    var nonce = 0;
    while (DateTime.now().microsecondsSinceEpoch < deadline) {
      for (var i = 0; i < 500; i++) {
        hashOne(nonce++);
        count++;
      }
    }
    final elapsed = DateTime.now().microsecondsSinceEpoch - start;
    return count * 1000000 / elapsed;
  }

  void writeNonce(int nonce) {
    header[76] = nonce & 0xff;
    header[77] = (nonce >> 8) & 0xff;
    header[78] = (nonce >> 16) & 0xff;
    header[79] = (nonce >> 24) & 0xff;
  }

  final compatible = measure((n) {
    writeNonce(n);
    sha256d(header);
  });

  final maison = measure((n) {
    writeNonce(n);
    fast.doubleHashFull(header);
  });

  final midstate = measure((n) => fast.hashNonce(n), prepare: true);

  return {
    'compatible': compatible,
    'maison': maison,
    'midstate': midstate,
    'identical': identical,
  };
}
