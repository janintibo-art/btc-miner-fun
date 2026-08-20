import 'package:btc_miner_fun/core/session.dart';
import 'package:btc_miner_fun/core/session_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sessions = <MiningSession>[
    MiningSession(
      startedAt: DateTime(2026, 8, 19, 9, 5),
      seconds: 3600,
      hashes: 1800000,
      averageHashrate: 500.5,
      bestDifficulty: 1234.567,
      accepted: 2,
      rejected: 1,
      pool: 'public-pool.io',
      threads: 4,
    ),
  ];

  test('l en-tete decrit toutes les colonnes', () {
    final csv = SessionExport.toCsv(sessions);
    final entete = csv.split('\n').first.split(';');
    expect(entete, hasLength(9));
    expect(entete.first, 'date');
    expect(entete.last, 'pool');
  });

  test('une session donne une ligne complete', () {
    final ligne = SessionExport.toCsv(sessions).split('\n')[1].split(';');
    expect(ligne, hasLength(9));
    expect(ligne[0], '2026-08-19 09:05');
    expect(ligne[1], '3600');
    expect(ligne[2], '1800000');
    expect(ligne[8], 'public-pool.io');
  });

  test('les decimales utilisent la virgule, pas le point', () {
    final csv = SessionExport.toCsv(sessions);
    expect(csv, contains('500,5'));
    expect(csv, contains('1234,567'));
    expect(csv.split('\n')[1], isNot(contains('500.5')));
  });

  test('une liste vide ne produit que l en-tete', () {
    final csv = SessionExport.toCsv(const <MiningSession>[]);
    expect(csv.trim().split('\n'), hasLength(1));
  });
}
