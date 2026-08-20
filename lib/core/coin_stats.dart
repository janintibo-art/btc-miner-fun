import 'dart:math';

import 'coins.dart';
import 'price_service.dart';

/// Statistiques publiques d'une chaine.
class CoinStats {
  const CoinStats({
    required this.symbol,
    required this.difficulty,
    required this.hashrate,
    required this.blocks,
    required this.priceUsd,
    required this.fetchedAt,
  });

  final String symbol;

  /// Difficulte du reseau : combien de fois il est plus dur de trouver un bloc
  /// que de resoudre le probleme de reference.
  final double difficulty;

  /// Puissance de calcul de l'ensemble du reseau, en hachages par seconde.
  final double hashrate;

  final int blocks;
  final double priceUsd;
  final DateTime fetchedAt;

  /// Combien de fois cette chaine est plus difficile qu'une autre.
  double relativeTo(CoinStats other) =>
      other.difficulty <= 0 ? 0 : difficulty / other.difficulty;

  /// Duree moyenne avant un bloc, pour une puissance donnee.
  double daysPerBlock(double hashrateOfMiner, double blockMinutes) {
    if (hashrateOfMiner <= 0 || hashrate <= 0) return double.infinity;
    final blocksPerDay = 1440 / blockMinutes;
    return hashrate / hashrateOfMiner / blocksPerDay;
  }
}

/// Interroge un explorateur public pour les chaines qu'il couvre.
///
/// Une seule source pour toutes les monnaies : les chiffres sont donc
/// comparables entre eux, ce qui est tout l'interet de l'exercice.
class CoinStatsService {
  static Future<CoinStats?> fetch(Coin coin) async {
    final slug = coin.blockchairSlug;
    if (slug == null) return null;
    try {
      final response = await fetchJson('https://api.blockchair.com/$slug/stats');
      if (response is! Map<String, dynamic>) return null;
      final data = response['data'];
      if (data is! Map<String, dynamic>) return null;

      return CoinStats(
        symbol: coin.symbol,
        difficulty: _toDouble(data['difficulty']),
        hashrate: _toDouble(data['hashrate_24h']),
        blocks: _toInt(data['blocks']),
        priceUsd: _toDouble(data['market_price_usd']),
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Recupere plusieurs chaines a la suite, sans saturer l'explorateur.
  static Future<Map<String, CoinStats>> fetchAll(List<Coin> coins) async {
    final results = <String, CoinStats>{};
    for (final coin in coins) {
      if (coin.blockchairSlug == null) continue;
      final stats = await fetch(coin);
      if (stats != null) results[coin.symbol] = stats;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return results;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Mise en forme d'un grand nombre : 4 512 000 000 000 devient "4,51 T".
String formatBigNumber(double value) {
  if (value <= 0 || value.isNaN || value.isInfinite) return '-';
  const suffixes = <String>['', 'k', 'M', 'G', 'T', 'P', 'E', 'Z'];
  var v = value;
  var index = 0;
  while (v >= 1000 && index < suffixes.length - 1) {
    v /= 1000;
    index++;
  }
  final texte = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  return '${texte.replaceAll('.', ',')} ${suffixes[index]}'.trim();
}

/// La meme valeur en toutes lettres, pour les ordres de grandeur qui ne
/// parlent a personne sous forme de puissance de dix.
String describeMagnitude(double value) {
  if (value <= 0) return 'inconnue';
  if (value < 1000) return value.toStringAsFixed(0);
  if (value < 1e6) return '${(value / 1e3).toStringAsFixed(1)} milliers';
  if (value < 1e9) return '${(value / 1e6).toStringAsFixed(1)} millions';
  if (value < 1e12) return '${(value / 1e9).toStringAsFixed(1)} milliards';
  if (value < 1e15) {
    return '${(value / 1e12).toStringAsFixed(1)} milliers de milliards';
  }
  if (value < 1e18) {
    return '${(value / 1e15).toStringAsFixed(1)} millions de milliards';
  }
  return '${(value / 1e18).toStringAsFixed(1)} milliards de milliards';
}

/// Echelle logarithmique, pour comparer sur un meme graphique des difficultes
/// qui vont de quelques milliers a cent mille milliards.
double logScale(double value) => value <= 1 ? 0 : log(value) / ln10;
