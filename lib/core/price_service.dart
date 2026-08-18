import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Le cours du bitcoin et l'etat du reseau, recuperes sur des API publiques.
///
/// Aucune cle d'API, aucune inscription, aucune donnee personnelle envoyee :
/// ce sont de simples requetes de lecture.
class MarketData {
  const MarketData({
    required this.eurPerBtc,
    required this.usdPerBtc,
    required this.fetchedAt,
    this.networkHashrate,
    this.difficulty,
    this.manual = false,
  });

  final double eurPerBtc;
  final double usdPerBtc;
  final DateTime fetchedAt;

  /// Puissance de calcul de l'ensemble du reseau, en hachages par seconde.
  final double? networkHashrate;
  final double? difficulty;

  /// Vrai si le cours a ete saisi a la main faute de connexion.
  final bool manual;

  Map<String, dynamic> toJson() => {
        'eur': eurPerBtc,
        'usd': usdPerBtc,
        'at': fetchedAt.millisecondsSinceEpoch,
        'net': networkHashrate,
        'diff': difficulty,
        'manual': manual,
      };

  factory MarketData.fromJson(Map<String, dynamic> j) => MarketData(
        eurPerBtc: (j['eur'] as num).toDouble(),
        usdPerBtc: (j['usd'] as num?)?.toDouble() ?? 0,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        networkHashrate: (j['net'] as num?)?.toDouble(),
        difficulty: (j['diff'] as num?)?.toDouble(),
        manual: j['manual'] as bool? ?? false,
      );

  static MarketData? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return MarketData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

class PriceService {
  static const Duration _timeout = Duration(seconds: 12);

  static Future<MarketData> fetch() async {
    final price = await _getJson(
      'https://api.coingecko.com/api/v3/simple/price'
      '?ids=bitcoin&vs_currencies=eur,usd',
    );
    final bitcoin = price['bitcoin'] as Map<String, dynamic>;
    final eur = (bitcoin['eur'] as num).toDouble();
    final usd = (bitcoin['usd'] as num?)?.toDouble() ?? 0;

    // L'etat du reseau est un bonus : son absence ne doit pas faire echouer
    // la recuperation du cours.
    double? hashrate;
    double? difficulty;
    try {
      final mining = await _getJson(
        'https://mempool.space/api/v1/mining/hashrate/3d',
      );
      hashrate = (mining['currentHashrate'] as num?)?.toDouble();
      difficulty = (mining['currentDifficulty'] as num?)?.toDouble();
    } catch (_) {
      // Sans consequence : on affichera seulement le cours.
    }

    return MarketData(
      eurPerBtc: eur,
      usdPerBtc: usd,
      fetchedAt: DateTime.now(),
      networkHashrate: hashrate,
      difficulty: difficulty,
    );
  }

  static Future<Map<String, dynamic>> _getJson(String url) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'btc-miner-fun/0.8');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200) {
        throw HttpException('reponse ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}

/// La recompense actuelle d'un bloc, hors frais de transaction.
/// Elle est divisee par deux tous les 210 000 blocs.
const double kBlockSubsidy = 3.125;

/// Nombre de blocs produits par jour en moyenne (un toutes les dix minutes).
const double kBlocksPerDay = 144;

/// Esperance de gain quotidien, en bitcoins, pour une puissance donnee.
///
/// C'est une esperance mathematique, pas une prevision : en solo, le resultat
/// reel est presque toujours zero, et tres rarement un bloc entier.
double expectedBtcPerDay(double hashrate, double networkHashrate) {
  if (networkHashrate <= 0 || hashrate <= 0) return 0;
  return hashrate / networkHashrate * kBlocksPerDay * kBlockSubsidy;
}
