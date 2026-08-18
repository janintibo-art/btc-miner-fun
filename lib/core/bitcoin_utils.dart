import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Outils bas niveau pour le minage Bitcoin (hex, endianness, SHA-256d, cibles).

const String _hexChars = '0123456789abcdef';

Uint8List hexToBytes(String hex) {
  final clean = hex.trim();
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String bytesToHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(_hexChars[(b >> 4) & 0x0f]);
    sb.write(_hexChars[b & 0x0f]);
  }
  return sb.toString();
}

Uint8List reverseBytes(List<int> bytes) {
  final out = Uint8List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    out[i] = bytes[bytes.length - 1 - i];
  }
  return out;
}

/// Inverse chaque mot de 4 octets, sans changer l'ordre des mots.
/// C'est le format attendu pour le champ "previous block hash" envoye par
/// un pool Stratum.
Uint8List swapEndianWords(List<int> bytes) {
  final out = Uint8List(bytes.length);
  for (var i = 0; i < bytes.length; i += 4) {
    for (var j = 0; j < 4; j++) {
      out[i + j] = bytes[i + 3 - j];
    }
  }
  return out;
}

/// Double SHA-256, la fonction de hachage du protocole Bitcoin.
Uint8List sha256d(List<int> data) {
  return Uint8List.fromList(sha256.convert(sha256.convert(data).bytes).bytes);
}

/// Racine de Merkle a partir du hash de la coinbase et des branches du pool.
Uint8List merkleRootFromBranch(Uint8List coinbaseHash, List<String> branch) {
  var root = coinbaseHash;
  for (final b in branch) {
    final buffer = Uint8List(64)
      ..setRange(0, 32, root)
      ..setRange(32, 64, hexToBytes(b));
    root = sha256d(buffer);
  }
  return root;
}

/// Cible correspondant a la difficulte 1 (reseau Bitcoin).
final BigInt diff1Target = BigInt.parse(
  '00000000FFFF0000000000000000000000000000000000000000000000000000',
  radix: 16,
);

/// Convertit une difficulte de pool en cible de 32 octets (big endian).
Uint8List targetFromDifficulty(double difficulty) {
  if (difficulty <= 0) difficulty = 1;
  const scale = 1000000;
  final scaled = BigInt.from((difficulty * scale).round());
  final target = (diff1Target * BigInt.from(scale)) ~/ scaled;
  return bigIntTo32Bytes(target);
}

/// Cible "facile" definie par un nombre de bits a zero (utile en mode demo).
Uint8List targetFromLeadingZeroBits(int bits) {
  final t = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    final start = i * 8;
    if (start + 8 <= bits) {
      t[i] = 0x00;
    } else if (start >= bits) {
      t[i] = 0xff;
    } else {
      t[i] = 0xff >> (bits - start);
    }
  }
  return t;
}

Uint8List bigIntTo32Bytes(BigInt value) {
  final out = Uint8List(32);
  var v = value;
  final mask = BigInt.from(0xff);
  for (var i = 31; i >= 0; i--) {
    out[i] = (v & mask).toInt();
    v = v >> 8;
    if (v == BigInt.zero) break;
  }
  return out;
}

/// Le hash sort en little endian : on le retourne puis on compare a la cible.
bool hashMeetsTarget(Uint8List hashLittleEndian, Uint8List targetBigEndian) {
  for (var i = 0; i < 32; i++) {
    final h = hashLittleEndian[31 - i];
    final t = targetBigEndian[i];
    if (h < t) return true;
    if (h > t) return false;
  }
  return true;
}

/// Difficulte reelle d'un hash trouve (indicatif, affiche dans les logs).
double difficultyOfHash(Uint8List hashLittleEndian) {
  final be = reverseBytes(hashLittleEndian);
  final value = BigInt.parse(bytesToHex(be), radix: 16);
  if (value == BigInt.zero) return double.infinity;
  final ratio = diff1Target * BigInt.from(1000000) ~/ value;
  return ratio.toDouble() / 1000000;
}

String formatHashrate(double hps) {
  if (hps >= 1e9) return '${(hps / 1e9).toStringAsFixed(2)} GH/s';
  if (hps >= 1e6) return '${(hps / 1e6).toStringAsFixed(2)} MH/s';
  if (hps >= 1e3) return '${(hps / 1e3).toStringAsFixed(2)} kH/s';
  return '${hps.toStringAsFixed(0)} H/s';
}

String formatCount(int n) {
  final s = n.toString();
  final sb = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) sb.write(' ');
    sb.write(s[i]);
  }
  return sb.toString();
}

String formatDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
