import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Le cours du bitcoin et l'etat du reseau, recuperes sur des API publiques.
///
/// Aucune cle d'API ni information secrete n'est envoyee. Comme pour toute
/// requete Internet, le fournisseur voit toutefois l'adresse IP du client.
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

const Duration kHttpTimeout = Duration(seconds: 12);

/// Petit client JSON partage : lecture seule, sans cle d'API.
Future<dynamic> fetchJson(String url) async {
  final client = HttpClient()..connectionTimeout = kHttpTimeout;
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(kHttpTimeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'btc-miner-fun/0.11');
    final response = await request.close().timeout(kHttpTimeout);
    if (response.statusCode != 200) {
      throw HttpException('reponse ${response.statusCode}');
    }
    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body);
  } finally {
    client.close(force: true);
  }
}

class PriceService {
  static Future<MarketData> fetch() async {
    final price = _asMap(await fetchJson(
      'https://api.coingecko.com/api/v3/simple/price'
      '?ids=bitcoin&vs_currencies=eur,usd',
    ));
    final bitcoin = _asMap(price['bitcoin']);
    final eur = (bitcoin['eur'] as num).toDouble();
    final usd = (bitcoin['usd'] as num?)?.toDouble() ?? 0;

    // L'etat du reseau est un bonus : son absence ne doit pas faire echouer
    // la recuperation du cours.
    double? hashrate;
    double? difficulty;
    try {
      final mining = _asMap(await fetchJson(
        'https://mempool.space/api/v1/mining/hashrate/3d',
      ));
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
}

Map<String, dynamic> _asMap(dynamic value) => value as Map<String, dynamic>;

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
