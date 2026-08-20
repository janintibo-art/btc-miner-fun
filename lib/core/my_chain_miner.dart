import 'dart:isolate';
import 'dart:typed_data';

import 'bitcoin_utils.dart';
import 'my_chain.dart';
import 'sha256_fast.dart';

/// Resultat d'un lot de minage sur la chaine personnelle.
class ChainMiningResult {
  const ChainMiningResult({
    required this.found,
    required this.nonce,
    required this.hashes,
  });

  final bool found;
  final int nonce;
  final int hashes;
}

/// Mine un lot de nonces dans un isolate.
///
/// Le travail est decoupe en lots plutot que lance en continu : l'interface
/// peut ainsi afficher la progression, et l'utilisateur arreter a tout moment.
Future<ChainMiningResult> mineChainBatch({
  required Uint8List header,
  required int bits,
  required int startNonce,
  required int count,
}) =>
    Isolate.run(() => _mineBatch(header, bits, startNonce, count));

ChainMiningResult _mineBatch(
  Uint8List header,
  int bits,
  int startNonce,
  int count,
) {
  final target = targetBytesFromBits(bits);
  final fast = Sha256Fast();
  final work = Uint8List.fromList(header);
  fast.prepare(work);

  // Le rejet precoce du moteur principal s'applique ici aussi : les quatre
  // premiers octets suffisent presque toujours a trancher.
  final targetHead = (target[0] << 24) |
      (target[1] << 16) |
      (target[2] << 8) |
      target[3];

  var nonce = startNonce;
  for (var i = 0; i < count; i++) {
    final head = _swap32(fast.hashNonce(nonce));
    if (head <= targetHead) {
      final digest = Uint8List.fromList(fast.digest());
      if (hashMeetsTarget(digest, target)) {
        return ChainMiningResult(found: true, nonce: nonce, hashes: i + 1);
      }
    }
    nonce = (nonce + 1) & 0xFFFFFFFF;
  }

  return ChainMiningResult(found: false, nonce: nonce, hashes: count);
}

int _swap32(int v) =>
    ((v & 0xff) << 24) |
    (((v >> 8) & 0xff) << 16) |
    (((v >> 16) & 0xff) << 8) |
    ((v >> 24) & 0xff);
