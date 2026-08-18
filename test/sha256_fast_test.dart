import 'dart:math';
import 'dart:typed_data';

import 'package:btc_miner_fun/core/bitcoin_utils.dart';
import 'package:btc_miner_fun/core/sha256_fast.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le moteur optimise n'a d'interet que s'il donne exactement le meme
/// resultat que la reference. Ces tests sont la garantie que la vitesse ne
/// s'achete pas au prix de la justesse.
void main() {
  final fast = Sha256Fast();

  group('SHA-256 maison contre le paquet crypto', () {
    test('le bloc reel 125552 donne le hash officiel', () {
      const headerHex =
          '0100000081cd02ab7e569e8bcd9317e2fe99f2de44d49ab2b8851ba4a308000000000000'
          'e320b6c2fffc8d750423db8b1eb942ae710e951ed797f7affc8892b0f1fc122b'
          'c7f5d74df2b9441a42a14695';
      final header = hexToBytes(headerHex);

      expect(
        bytesToHex(reverseBytes(fast.doubleHashFull(header))),
        '00000000000000001e8d6829a8a21adc5d38d0a473b144b6765798e61f98bd1d',
      );
    });

    test('mille en-tetes aleatoires donnent le meme hash que la reference', () {
      final random = Random(42);
      for (var essai = 0; essai < 1000; essai++) {
        final header = Uint8List(80);
        for (var i = 0; i < 80; i++) {
          header[i] = random.nextInt(256);
        }
        expect(
          bytesToHex(fast.doubleHashFull(header)),
          bytesToHex(sha256d(header)),
          reason: 'divergence sur l en-tete ${bytesToHex(header)}',
        );
      }
    });
  });

  group('Midstate', () {
    test('le chemin midstate donne le meme hash que le calcul complet', () {
      final random = Random(7);
      final header = Uint8List(80);
      for (var i = 0; i < 80; i++) {
        header[i] = random.nextInt(256);
      }

      fast.prepare(header);
      for (final nonce in [0, 1, 42, 65535, 0x7fffffff, 0xfffffffe]) {
        header[76] = nonce & 0xff;
        header[77] = (nonce >> 8) & 0xff;
        header[78] = (nonce >> 16) & 0xff;
        header[79] = (nonce >> 24) & 0xff;

        fast.hashNonce(nonce);
        expect(
          bytesToHex(fast.digest()),
          bytesToHex(sha256d(header)),
          reason: 'divergence sur le nonce $nonce',
        );
      }
    });

    test('le mot renvoye correspond bien aux premiers octets du hash retourne',
        () {
      final random = Random(11);
      final header = Uint8List(80);
      for (var i = 0; i < 80; i++) {
        header[i] = random.nextInt(256);
      }
      fast.prepare(header);

      for (var nonce = 0; nonce < 200; nonce++) {
        final word = fast.hashNonce(nonce);
        final head = ((word & 0xff) << 24) |
            (((word >> 8) & 0xff) << 16) |
            (((word >> 16) & 0xff) << 8) |
            ((word >> 24) & 0xff);
        final reversed = reverseBytes(fast.digest());
        final expected = (reversed[0] << 24) |
            (reversed[1] << 16) |
            (reversed[2] << 8) |
            reversed[3];
        expect(head, expected, reason: 'nonce $nonce');
      }
    });

    test('preparer un nouvel en-tete change bien le resultat', () {
      final a = Uint8List(80);
      final b = Uint8List(80)..[10] = 1;
      fast.prepare(a);
      fast.hashNonce(5);
      final first = bytesToHex(fast.digest());
      fast.prepare(b);
      fast.hashNonce(5);
      expect(bytesToHex(fast.digest()), isNot(first));
    });
  });
}
