import 'dart:convert';

/// Le bilan d'une session de minage, conserve sur l'appareil.
class MiningSession {
  MiningSession({
    required this.startedAt,
    required this.seconds,
    required this.hashes,
    required this.averageHashrate,
    required this.bestDifficulty,
    required this.accepted,
    required this.rejected,
    required this.pool,
    required this.threads,
  });

  final DateTime startedAt;
  final int seconds;
  final int hashes;
  final double averageHashrate;
  final double bestDifficulty;
  final int accepted;
  final int rejected;
  final String pool;
  final int threads;

  Map<String, dynamic> toJson() => {
        's': startedAt.millisecondsSinceEpoch,
        'd': seconds,
        'h': hashes,
        'r': averageHashrate,
        'b': bestDifficulty,
        'a': accepted,
        'x': rejected,
        'p': pool,
        't': threads,
      };

  factory MiningSession.fromJson(Map<String, dynamic> j) => MiningSession(
        startedAt: DateTime.fromMillisecondsSinceEpoch(j['s'] as int),
        seconds: j['d'] as int,
        hashes: j['h'] as int,
        averageHashrate: (j['r'] as num).toDouble(),
        bestDifficulty: (j['b'] as num).toDouble(),
        accepted: j['a'] as int,
        rejected: j['x'] as int,
        pool: j['p'] as String? ?? '',
        threads: j['t'] as int? ?? 1,
      );

  static String encodeList(List<MiningSession> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<MiningSession> decodeList(String raw) {
    try {
      final data = jsonDecode(raw) as List;
      return data
          .map((e) => MiningSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <MiningSession>[];
    }
  }
}
