import 'package:btc_miner_fun/core/bitcoin_utils.dart';
import 'package:btc_miner_fun/core/price_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mise en forme des montants', () {
    test('les euros sont groupes par milliers', () {
      expect(formatEuros(1234567), '1 234 567 €');
      expect(formatEuros(12.5), '12,50 €');
      expect(formatEuros(0.0125), '0,0125 €');
    });

    test('les bitcoins perdent leurs zeros inutiles', () {
      expect(formatBtc(1), '1');
      expect(formatBtc(0.5), '0.5');
      expect(formatBtc(0.00000001), '0.00000001');
    });

    test('un bitcoin fait cent millions de satoshis', () {
      expect(kSatoshisPerBtc, 100000000);
    });
  });

  group('Esperance de gain', () {
    test('la moitie du reseau rapporte la moitie des blocs', () {
      final btc = expectedBtcPerDay(50, 100);
      expect(btc, closeTo(kBlocksPerDay * kBlockSubsidy / 2, 0.0001));
    });

    test('une puissance nulle ne rapporte rien', () {
      expect(expectedBtcPerDay(0, 1000), 0);
      expect(expectedBtcPerDay(1000, 0), 0);
    });

    test('un telephone face au reseau reel donne un resultat infime', () {
      // 500 kH/s contre 800 EH/s
      final btc = expectedBtcPerDay(500000, 8e20);
      expect(btc, lessThan(0.000000001));
      expect(btc, greaterThan(0));
    });
  });

  group('Durees tres longues', () {
    test('les grandes echelles restent lisibles', () {
      expect(formatLongDuration(0.5), contains('heures'));
      expect(formatLongDuration(30), contains('jours'));
      expect(formatLongDuration(3652.5), contains('ans'));
      expect(formatLongDuration(365250000), contains('millions'));
    });

    test('une duree nulle ou negative ne casse rien', () {
      expect(formatLongDuration(0), 'jamais');
      expect(formatLongDuration(double.infinity), 'jamais');
    });
  });

  group('Donnees de marche', () {
    test('encodage et decodage conservent les valeurs', () {
      final data = MarketData(
        eurPerBtc: 61234.5,
        usdPerBtc: 66000,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        networkHashrate: 8e20,
        difficulty: 1.2e14,
      );
      final back = MarketData.tryDecode(data.encode());
      expect(back, isNotNull);
      expect(back!.eurPerBtc, 61234.5);
      expect(back.networkHashrate, 8e20);
      expect(back.manual, isFalse);
    });

    test('un contenu invalide ne fait pas planter', () {
      expect(MarketData.tryDecode('pas du json'), isNull);
      expect(MarketData.tryDecode(null), isNull);
    });
  });
}
