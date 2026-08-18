import 'package:btc_miner_fun/core/lottery_sim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simulation de loterie', () {
    test('avec la moitie du reseau, presque tous les univers gagnent', () async {
      // 50 % du reseau pendant un an : environ 26 000 blocs attendus.
      final r = await runLotterySimulation(
        hashrate: 50,
        networkHashrate: 100,
        years: 1,
        universes: 200,
      );
      expect(r.winners, 200);
      expect(r.expectedBlocks, greaterThan(20000));
      expect(r.exactProbability, closeTo(1, 0.0001));
    });

    test('avec un telephone face au vrai reseau, aucun univers ne gagne',
        () async {
      final r = await runLotterySimulation(
        hashrate: 500000, // 500 kH/s
        networkHashrate: 8e20, // 800 EH/s
        years: 50,
        universes: 2000,
      );
      expect(r.winners, 0);
      expect(r.expectedBlocks, lessThan(0.000001));
      expect(r.oneInHowMany, greaterThan(1000000));
    });

    test('la simulation reste coherente avec la formule', () async {
      // Un cas intermediaire ou les deux doivent se rejoindre.
      final r = await runLotterySimulation(
        hashrate: 1,
        networkHashrate: 100000,
        years: 2,
        universes: 4000,
      );
      expect(r.simulatedProbability,
          closeTo(r.exactProbability, r.exactProbability * 0.5 + 0.02));
    });

    test('une puissance nulle ne gagne jamais', () async {
      final r = await runLotterySimulation(
        hashrate: 0,
        networkHashrate: 8e20,
        years: 100,
        universes: 100,
      );
      expect(r.winners, 0);
      expect(r.exactProbability, 0);
      expect(r.oneInHowMany, double.infinity);
    });
  });
}
