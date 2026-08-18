import 'package:btc_miner_fun/core/avalanche.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un bon hachage change en moyenne la moitie des bits de sortie quand un seul
/// bit d'entree change. Si ce test echouait, cela voudrait dire que notre
/// SHA-256 est casse.
void main() {
  test('changer un bit change environ la moitie des 256 bits du hash', () async {
    final result = await runAvalancheTest(trials: 200);
    expect(result.trials, 200);
    expect(result.averageBitsChanged, greaterThan(112));
    expect(result.averageBitsChanged, lessThan(144));
    expect(result.percentChanged, closeTo(50, 6));
  });

  test('aucun essai ne laisse le hash inchange', () async {
    final result = await runAvalancheTest(trials: 100);
    expect(result.minBitsChanged, greaterThan(60));
    expect(result.maxBitsChanged, lessThanOrEqualTo(256));
  });
}
