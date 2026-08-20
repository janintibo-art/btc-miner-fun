import 'package:btc_miner_fun/core/thermal_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final guard = ThermalGuard();

  group('Limiteur thermique', () {
    test('en dessous du seuil, le reglage de l utilisateur est intact', () {
      expect(guard.intensityFor(25, 100), 100);
      expect(guard.intensityFor(38.9, 80), 80);
    });

    test('au dela du seuil chaud, on descend au plancher', () {
      expect(guard.intensityFor(45, 100), 25);
      expect(guard.intensityFor(43, 100), 25);
    });

    test('entre les deux seuils, la baisse est progressive', () {
      final milieu = guard.intensityFor(41, 100);
      expect(milieu, lessThan(100));
      expect(milieu, greaterThan(25));
      // Plus il fait chaud, plus l'intensite baisse : jamais l'inverse.
      expect(guard.intensityFor(42, 100), lessThan(guard.intensityFor(40, 100)));
    });

    test('le limiteur ne remonte jamais au dessus du choix utilisateur', () {
      for (var t = 20.0; t < 50; t += 0.5) {
        expect(guard.intensityFor(t, 50), lessThanOrEqualTo(50));
      }
    });

    test('l etat est decrit clairement', () {
      expect(guard.describe(null), contains('indisponible'));
      expect(guard.describe(30), contains('normal'));
      expect(guard.describe(41), contains('ralentissement'));
      expect(guard.describe(46), contains('minimale'));
      expect(guard.isThrottling(30), isFalse);
      expect(guard.isThrottling(41), isTrue);
    });
  });
}
