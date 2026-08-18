import 'package:btc_miner_fun/core/bitcoin_utils.dart';
import 'package:btc_miner_fun/core/stratum_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Outils de bas niveau', () {
    test('hex aller-retour', () {
      const h = '00ff1a2b';
      expect(bytesToHex(hexToBytes(h)), h);
    });

    test('une chaine hex de longueur impaire est refusee', () {
      expect(() => hexToBytes('abc'), throwsFormatException);
    });

    test('inversion complete', () {
      expect(bytesToHex(reverseBytes(hexToBytes('01020304'))), '04030201');
    });

    test('inversion par mots de 4 octets', () {
      expect(
        bytesToHex(swapEndianWords(hexToBytes('0102030405060708'))),
        '0403020108070605',
      );
    });
  });

  group('Bloc reel 125552 (vecteur de reference)', () {
    // En-tete authentique du bloc 125552 de la chaine Bitcoin.
    const headerHex =
        '0100000081cd02ab7e569e8bcd9317e2fe99f2de44d49ab2b8851ba4a308000000000000'
        'e320b6c2fffc8d750423db8b1eb942ae710e951ed797f7affc8892b0f1fc122b'
        'c7f5d74df2b9441a42a14695';
    const expectedHash =
        '00000000000000001e8d6829a8a21adc5d38d0a473b144b6765798e61f98bd1d';

    test('le double SHA-256 redonne le hash officiel du bloc', () {
      final hash = sha256d(hexToBytes(headerHex));
      expect(bytesToHex(reverseBytes(hash)), expectedHash);
    });

    test('l en-tete fait bien 80 octets', () {
      expect(hexToBytes(headerHex).length, 80);
    });

    test('ce hash satisfait largement la difficulte 1', () {
      final hash = sha256d(hexToBytes(headerHex));
      expect(hashMeetsTarget(hash, targetFromDifficulty(1)), isTrue);
      expect(difficultyOfHash(hash), greaterThan(1000000));
    });
  });

  group('Cibles et difficulte', () {
    test('difficulte 1 donne la cible de reference', () {
      expect(
        bytesToHex(targetFromDifficulty(1)),
        '00000000ffff0000000000000000000000000000000000000000000000000000',
      );
    });

    test('une difficulte positive extremement faible ne divise pas par zero', () {
      expect(targetFromDifficulty(0.00000001).length, 32);
    });

    test('une difficulte plus haute donne une cible plus basse', () {
      final easy = targetFromDifficulty(1);
      final hard = targetFromDifficulty(1024);
      var comparison = 0;
      for (var i = 0; i < 32 && comparison == 0; i++) {
        comparison = hard[i].compareTo(easy[i]);
      }
      expect(comparison, lessThan(0));
    });

    test('un hash nul satisfait toute cible, un hash maximal aucune', () {
      final zero = hexToBytes('00' * 32);
      final max = hexToBytes('ff' * 32);
      expect(hashMeetsTarget(zero, targetFromDifficulty(1)), isTrue);
      expect(hashMeetsTarget(max, targetFromDifficulty(1)), isFalse);
    });
  });

  group('Construction du travail Stratum', () {
    final job = StratumJob(
      jobId: 'test',
      prevHash:
          '0000000000000000000a1b2c3d4e5f60718293a4b5c6d7e8f900112233445566',
      coinb1: '01000000434f494e42312d',
      coinb2: '2d434f494e4232',
      merkleBranch: ['aa' * 32, 'bb' * 32],
      version: '20000000',
      nBits: '17034219',
      nTime: '65f0a1b2',
      cleanJobs: true,
    );

    test('racine de Merkle conforme au vecteur', () {
      expect(
        bytesToHex(job.merkleRootFor('1a2b3c4d', '00000007')),
        'b46d1db15392744ef11f2187dc1d94438287187ca4335b26468cbd6c9df81192',
      );
    });

    test('en-tete de 80 octets conforme au vecteur', () {
      final root = job.merkleRootFor('1a2b3c4d', '00000007');
      final header = job.headerFor(root);
      expect(header.length, 80);
      expect(
        bytesToHex(header),
        '0000002000000000000000002c1b0a00605f4e3da4938271e8d7c6b5221100f966554433'
        'b46d1db15392744ef11f2187dc1d94438287187ca4335b26468cbd6c9df81192'
        'b2a1f0651942031700000000',
      );
    });

    test('changer l extranonce2 change la racine de Merkle', () {
      final a = job.merkleRootFor('1a2b3c4d', '00000007');
      final b = job.merkleRootFor('1a2b3c4d', '00000008');
      expect(bytesToHex(a), isNot(bytesToHex(b)));
    });

    test('le nonce occupe les 4 derniers octets et part a zero', () {
      final header = job.headerFor(job.merkleRootFor('1a2b3c4d', '00000007'));
      expect(header.sublist(76), [0, 0, 0, 0]);
    });
  });

  group('Format des parts', () {
    test('le nonce se soumet en hexadecimal sur 8 caracteres', () {
      final share = FoundShare(
        jobId: 'x',
        extranonce2: '00000001',
        nTime: '65f0a1b2',
        nonce: 0x9546a142,
        hashHex: '00' * 32,
        difficulty: 1,
      );
      expect(share.nonceHex, '9546a142');
      expect(share.nonceHex.length, 8);
    });
  });
}
