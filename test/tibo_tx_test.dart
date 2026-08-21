import 'package:btc_miner_fun/core/tibo_keys.dart';
import 'package:btc_miner_fun/core/tibo_tx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Message signe', () {
    test('le format est fige au caractere pres', () {
      // Le serveur reconstruit ce texte de son cote : la moindre difference
      // invaliderait toutes les signatures.
      final message = TiboTx.message(
        from: 'TAAA',
        to: 'TBBB',
        amount: 12.5,
        sequence: 3,
        note: 'cadeau',
      );
      expect(message, 'TIBO|TAAA|TBBB|12.50000000|3|cadeau');
    });

    test('le montant garde toujours huit decimales', () {
      final message = TiboTx.message(
          from: 'A', to: 'B', amount: 1, sequence: 1, note: '');
      expect(message, contains('1.00000000'));
    });
  });

  group('Adresses', () {
    // Adresse produite par la meme derivation, verifiee independamment.
    const valide = 'TAESZhcd1sZag2KF83aNDoz2Z46dgSWLKq';

    test('une adresse bien formee est acceptee', () {
      expect(TiboIdentity.isValidAddress(valide), isTrue);
    });

    test('un caractere modifie casse le code de controle', () {
      final faux = valide.substring(0, valide.length - 1) +
          (valide.endsWith('a') ? 'b' : 'a');
      expect(TiboIdentity.isValidAddress(faux), isFalse);
    });

    test('une adresse Bitcoin est refusee', () {
      expect(
          TiboIdentity.isValidAddress('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'),
          isFalse);
      expect(
          TiboIdentity.isValidAddress(
              'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'),
          isFalse);
    });

    test('le vide et le charabia sont refuses', () {
      expect(TiboIdentity.isValidAddress(''), isFalse);
      expect(TiboIdentity.isValidAddress('n importe quoi'), isFalse);
    });
  });

  group('Etat des comptes', () {
    TiboTx virement(String de, String vers, double montant, int ordre) => TiboTx(
          from: de,
          to: vers,
          amount: montant,
          sequence: ordre,
          publicKey: '00' * 33,
          signature: '00' * 64,
        );

    test('un virement deplace la somme sans en creer', () {
      final etat = TiboState()..credit('A', 100);
      expect(etat.apply(virement('A', 'B', 30, 1)), '');
      expect(etat.balanceOf('A'), 70);
      expect(etat.balanceOf('B'), 30);
    });

    test('le rejeu du meme virement est refuse', () {
      final etat = TiboState()..credit('A', 100);
      final tx = virement('A', 'B', 30, 1);
      expect(etat.apply(tx), '');
      expect(etat.apply(tx), contains('ordre'));
      expect(etat.balanceOf('B'), 30);
    });

    test('on ne peut pas depenser plus qu on ne possede', () {
      final etat = TiboState()..credit('A', 10);
      expect(etat.apply(virement('A', 'B', 50, 1)), contains('insuffisant'));
      expect(etat.balanceOf('A'), 10);
    });

    test('les montants nuls ou negatifs sont refuses', () {
      final etat = TiboState()..credit('A', 10);
      expect(etat.apply(virement('A', 'B', 0, 1)), isNotEmpty);
      expect(etat.apply(virement('A', 'B', -5, 1)), isNotEmpty);
    });

    test('s envoyer a soi-meme est refuse', () {
      final etat = TiboState()..credit('A', 10);
      expect(etat.apply(virement('A', 'A', 5, 1)), contains('identiques'));
    });

    test('les numeros d ordre doivent se suivre', () {
      final etat = TiboState()..credit('A', 100);
      expect(etat.apply(virement('A', 'B', 10, 2)), contains('1'));
      expect(etat.apply(virement('A', 'B', 10, 1)), '');
      expect(etat.apply(virement('A', 'B', 10, 2)), '');
    });
  });
}
