import 'package:btc_miner_fun/core/local_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Registre d une monnaie locale', () {
    test('la demonstration part avec des comptes coherents', () {
      final r = LocalLedger.demonstration();
      expect(r.accounts, hasLength(5));
      // 100 unites emises, rien n'a disparu en circulant.
      expect(r.inCirculation, closeTo(100, 0.001));
      expect(r.byId('boulangerie')!.balance, closeTo(4.5, 0.001));
      expect(r.byId('habitant1')!.balance, closeTo(45.5, 0.001));
    });

    test('un paiement deplace la somme sans en creer', () {
      final r = LocalLedger.demonstration();
      final avant = r.inCirculation;
      expect(r.transfer('habitant1', 'ferme', 10, 'Oeufs'), '');
      expect(r.inCirculation, closeTo(avant, 0.001));
      expect(r.byId('ferme')!.balance, closeTo(22, 0.001));
    });

    test('un solde insuffisant est refuse avec une explication', () {
      final r = LocalLedger.demonstration();
      final message = r.transfer('habitant1', 'ferme', 10000, 'Trop');
      expect(message, contains('insuffisant'));
      expect(r.byId('ferme')!.balance, closeTo(12, 0.001));
    });

    test('seule l emission cree des unites', () {
      final r = LocalLedger.demonstration();
      final avant = r.inCirculation;
      expect(r.issue('habitant1', 25, 'Subvention'), '');
      expect(r.inCirculation, closeTo(avant + 25, 0.001));
    });

    test('un mouvement peut etre annule, contrairement a une chaine', () {
      final r = LocalLedger.demonstration();
      final dernier = r.transfers.first;
      final soldeAvant = r.byId('habitant2')!.balance;
      expect(r.cancel(dernier.id), '');
      expect(r.byId('habitant2')!.balance, closeTo(soldeAvant + 12, 0.001));
      expect(r.transfers.first.cancelled, isTrue);
    });

    test('on ne peut pas annuler deux fois', () {
      final r = LocalLedger.demonstration();
      final id = r.transfers.first.id;
      r.cancel(id);
      expect(r.cancel(id), contains('Deja'));
    });

    test('annuler devient impossible si la somme a deja circule', () {
      final r = LocalLedger.demonstration();
      final paiement = r.transfers.first; // 12 vers la ferme
      r.transfer('ferme', 'boulangerie', 12, 'Farine');
      expect(r.cancel(paiement.id), contains('deja depense'));
    });

    test('les montants nuls ou negatifs sont refuses', () {
      final r = LocalLedger.demonstration();
      expect(r.transfer('habitant1', 'ferme', 0, ''), contains('positif'));
      expect(r.transfer('habitant1', 'ferme', -5, ''), contains('positif'));
    });

    test('la sauvegarde conserve tout a l identique', () {
      final r = LocalLedger.demonstration();
      final relu = LocalLedger.tryDecode(r.encode());
      expect(relu, isNotNull);
      expect(relu!.accounts.length, r.accounts.length);
      expect(relu.inCirculation, closeTo(r.inCirculation, 0.001));
      expect(relu.transfers.length, r.transfers.length);
    });

    test('un contenu invalide est ignore', () {
      expect(LocalLedger.tryDecode('pas du json'), isNull);
      expect(LocalLedger.tryDecode(null), isNull);
    });
  });
}
