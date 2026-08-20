import 'coin_stats.dart';
import 'coins.dart';

/// Ce qu'une chaine rapporterait, en esperance, a une puissance donnee.
class RankedCoin {
  const RankedCoin({
    required this.coin,
    required this.stats,
    required this.dollarsPerDay,
    required this.daysPerBlock,
    required this.rewardValue,
  });

  final Coin coin;
  final CoinStats stats;

  /// Esperance de gain quotidien, en dollars.
  final double dollarsPerDay;

  /// Attente moyenne avant de trouver un bloc.
  final double daysPerBlock;

  /// Valeur d'un bloc entier, en dollars.
  final double rewardValue;
}

/// Classe les chaines minables par esperance de gain.
///
/// Le calcul est le meme partout : la part du reseau que represente la
/// machine, multipliee par le nombre de blocs quotidiens et par la valeur
/// d'un bloc. C'est ce qui permet de comparer des chaines dont les
/// difficultes different d'un facteur un million.
///
/// Le resultat est souvent contre-intuitif : une difficulte basse ne suffit
/// pas, encore faut-il que la recompense vaille quelque chose.
List<RankedCoin> rankCoins({
  required double hashrate,
  required Map<String, CoinStats> allStats,
}) {
  if (hashrate <= 0) return const <RankedCoin>[];

  final ranked = <RankedCoin>[];
  for (final coin in kCoins) {
    if (!coin.isMinableHere) continue;
    final stats = allStats[coin.symbol];
    if (stats == null || stats.hashrate <= 0) continue;

    final blocksPerDay = 1440 / coin.blockMinutes;
    final share = hashrate / stats.hashrate;
    final rewardValue = coin.blockReward * stats.priceUsd;

    ranked.add(RankedCoin(
      coin: coin,
      stats: stats,
      dollarsPerDay: share * blocksPerDay * rewardValue,
      daysPerBlock: share <= 0 ? double.infinity : 1 / (share * blocksPerDay),
      rewardValue: rewardValue,
    ));
  }

  ranked.sort((a, b) => b.dollarsPerDay.compareTo(a.dollarsPerDay));
  return ranked;
}

/// Comparaison entre deux chaines : combien de fois l'une rapporte plus que
/// l'autre, a puissance egale.
double ratioBetween(RankedCoin better, RankedCoin worse) {
  if (worse.dollarsPerDay <= 0) return double.infinity;
  return better.dollarsPerDay / worse.dollarsPerDay;
}
