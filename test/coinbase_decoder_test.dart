import 'package:btc_miner_fun/core/bitcoin_utils.dart';
import 'package:btc_miner_fun/core/coinbase_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coinbase construite de toutes pieces, avec hauteur BIP 34, extranonce,
/// message de pool, une sortie de recompense et un engagement SegWit.
const _coinb1 = '01000000010000000000000000000000000000000000000000000000'
    '000000000000000000ffffffff290340d10c08';
const _coinb2 = '2f4254434d696e657246756e2f73616c7574206c65206d6f6e64652fffffffff02'
    '4000a8120000000016001411111111111111111111111111111111111111110000'
    '000000000000266a24aa21a9ed2222222222222222222222222222222222222222'
    '22222222222222222222222200000000';

void main() {
  group('Decodage de la coinbase', () {
    final decoded = decodeCoinbase(
      coinb1: _coinb1,
      extranonce1: '1a2b3c4d',
      extranonce2: '00000007',
      coinb2: _coinb2,
    );

    test('la transaction est lue entierement', () {
      expect(decoded.complete, isTrue, reason: decoded.error ?? '');
      expect(decoded.totalBytes, 170);
      expect(decoded.version, 1);
      expect(decoded.lockTime, 0);
    });

    test('la hauteur du bloc est extraite du scriptSig (BIP 34)', () {
      expect(decoded.blockHeight, 840000);
    });

    test('le message du pool est retrouve', () {
      expect(decoded.messages.join(' '), contains('BTCMinerFun'));
      expect(decoded.messages.join(' '), contains('salut le monde'));
    });

    test('les sorties et la recompense sont correctes', () {
      expect(decoded.outputs, hasLength(2));
      expect(decoded.outputs.first.satoshis, 313000000);
      expect(decoded.totalBtc, closeTo(3.13, 0.000001));
      expect(decoded.outputs.first.kind, contains('P2WPKH'));
      expect(decoded.outputs[1].kind, contains('SegWit'));
      expect(decoded.outputs[1].satoshis, 0);
    });

    test('l extranonce se retrouve bien dans le scriptSig', () {
      expect(decoded.scriptSigHex, contains('1a2b3c4d00000007'));
    });
  });

  group('Robustesse', () {
    test('une coinbase tronquee rend un decodage partiel sans exception', () {
      final partial = decodeCoinbase(
        coinb1: _coinb1,
        extranonce1: '1a2b3c4d',
        extranonce2: '00000007',
        coinb2: '2f4254434d696e657246756e2f',
      );
      expect(partial.complete, isFalse);
      expect(partial.error, isNotNull);
      expect(partial.totalBytes, greaterThan(0));
    });

    test('des donnees invalides ne font pas planter', () {
      final bad = decodeCoinbase(
        coinb1: 'pas de l hexa',
        extranonce1: '',
        extranonce2: '',
        coinb2: '',
      );
      expect(bad.complete, isFalse);
    });
  });

  group('Extraction de texte', () {
    test('les suites imprimables sont isolees', () {
      final data = hexToBytes('00112f4254432f0099');
      expect(extractReadableText(data), contains('/BTC/'));
    });

    test('les fragments trop courts sont ignores', () {
      final data = hexToBytes('004100');
      expect(extractReadableText(data), isEmpty);
    });
  });
}
