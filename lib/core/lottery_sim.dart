import 'dart:isolate';
import 'dart:math';

/// Le resultat d'une simulation Monte-Carlo : on fait vivre des milliers
/// d'univers paralleles avec ta puissance de calcul, et on compte ceux ou tu
/// as trouve au moins un bloc.
class LotteryResult {
  const LotteryResult({
    required this.universes,
    required this.years,
    required this.winners,
    required this.bestUniverseBlocks,
    required this.expectedBlocks,
    required this.exactProbability,
  });

  /// Nombre d'univers simules.
  final int universes;
  final int years;

  /// Univers dans lesquels au moins un bloc a ete trouve.
  final int winners;

  /// Le meilleur univers, en nombre de blocs.
  final int bestUniverseBlocks;

  /// Esperance mathematique, pour comparer la simulation a la formule.
  final double expectedBlocks;

  /// Probabilite exacte d'au moins un bloc : 1 - e^(-lambda).
  final double exactProbability;

  double get simulatedProbability => winners / universes;

  /// "Un univers sur X". Retourne l'infini si aucun gagnant n'est plausible.
  double get oneInHowMany =>
      exactProbability <= 0 ? double.infinity : 1 / exactProbability;
}

/// Combien d'univers faut-il pour esperer un gagnant ? La simulation le montre,
/// la formule le confirme. Les deux sont affiches cote a cote : quand la
/// probabilite est minuscule, la simulation donne zero et c'est la formule qui
/// devient parlante.
Future<LotteryResult> runLotterySimulation({
  required double hashrate,
  required double networkHashrate,
  int years = 50,
  int universes = 10000,
}) =>
    Isolate.run(() => _simulate(hashrate, networkHashrate, years, universes));

LotteryResult _simulate(
  double hashrate,
  double networkHashrate,
  int years,
  int universes,
) {
  // Un bloc toutes les dix minutes : 52 560 blocs par an.
  final blocks = years * 52560.0;
  final share = networkHashrate <= 0 ? 0.0 : hashrate / networkHashrate;
  final lambda = share * blocks; // nombre moyen de blocs sur la periode

  final random = Random.secure();
  var winners = 0;
  var best = 0;

  // Loi de Poisson par la methode de Knuth. Pour un lambda minuscule, la
  // boucle s'arrete presque toujours des le premier tirage.
  final limit = exp(-lambda);
  for (var universe = 0; universe < universes; universe++) {
    var blocksFound = 0;
    var product = random.nextDouble();
    while (product > limit && blocksFound < 1000) {
      blocksFound++;
      product *= random.nextDouble();
    }
    if (blocksFound > 0) winners++;
    if (blocksFound > best) best = blocksFound;
  }

  return LotteryResult(
    universes: universes,
    years: years,
    winners: winners,
    bestUniverseBlocks: best,
    expectedBlocks: lambda,
    exactProbability: 1 - exp(-lambda),
  );
}
