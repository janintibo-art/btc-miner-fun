import 'coinbase_decoder.dart';
import 'bitcoin_utils.dart';
import 'price_service.dart';

/// Un bloc recemment trouve quelque part dans le monde.
class MinedBlock {
  const MinedBlock({
    required this.height,
    required this.timestamp,
    required this.poolName,
    required this.transactions,
    required this.rewardSats,
    required this.messages,
  });

  final int height;
  final DateTime timestamp;

  /// Le pool qui a trouve le bloc, quand il se declare.
  final String poolName;

  final int transactions;
  final int rewardSats;

  /// Le texte laisse dans la coinbase par celui qui a trouve le bloc.
  final List<String> messages;

  double get rewardBtc => rewardSats / kSatoshisPerBtc;
  Duration get age => DateTime.now().difference(timestamp);
}

/// Recupere les derniers blocs de la chaine Bitcoin.
///
/// C'est le meme travail que celui de l'application, vu de l'autre cote : ces
/// blocs ont ete trouves par quelqu'un, il y a quelques minutes.
class BlockFeed {
  static Future<List<MinedBlock>> fetchRecent() async {
    final response = await fetchJson('https://mempool.space/api/v1/blocks');
    if (response is! List) return const <MinedBlock>[];

    final blocks = <MinedBlock>[];
    for (final entry in response) {
      if (entry is! Map) continue;
      try {
        final extras = entry['extras'];
        final pool = extras is Map ? extras['pool'] : null;
        final coinbaseRaw = extras is Map ? extras['coinbaseRaw'] : null;

        blocks.add(MinedBlock(
          height: _toInt(entry['height']),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
              _toInt(entry['timestamp']) * 1000),
          poolName: pool is Map ? (pool['name']?.toString() ?? 'inconnu') : 'inconnu',
          transactions: _toInt(entry['tx_count']),
          rewardSats: extras is Map ? _toInt(extras['reward']) : 0,
          messages: coinbaseRaw is String && coinbaseRaw.isNotEmpty
              ? _readCoinbaseText(coinbaseRaw)
              : const <String>[],
        ));
      } catch (_) {
        // Un bloc mal forme ne doit pas priver des autres.
      }
    }
    return blocks;
  }

  /// Extrait le texte lisible de la coinbase, avec le meme code que le labo.
  static List<String> _readCoinbaseText(String hex) {
    try {
      return extractReadableText(hexToBytes(hex), minLength: 4);
    } catch (_) {
      return const <String>[];
    }
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
