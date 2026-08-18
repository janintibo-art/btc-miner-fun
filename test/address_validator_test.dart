import 'package:btc_miner_fun/core/address_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vecteurs issus des specifications BIP 173 et BIP 350, plus des adresses
/// historiques connues. Une adresse fausse acceptee, ce sont des gains perdus.
void main() {
  group('Adresses valides du reseau Bitcoin', () {
    const valides = <String, String>{
      // Adresse du bloc de genese.
      '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa': 'Historique (P2PKH)',
      '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy': 'Script (P2SH)',
      'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4': 'SegWit natif (P2WPKH)',
      'bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0':
          'Taproot (P2TR)',
    };

    valides.forEach((adresse, type) {
      test('$type est reconnu', () {
        final r = checkBitcoinAddress(adresse);
        expect(r.valid, isTrue, reason: r.message);
        expect(r.type, type);
      });
    });

    test('les espaces autour de l adresse sont tolerés', () {
      expect(
        checkBitcoinAddress('  1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa  ').valid,
        isTrue,
      );
    });
  });

  group('Fautes de frappe', () {
    test('un caractere change casse le checksum base58', () {
      final r = checkBitcoinAddress('1A1zP1eP5QGefi2DMPTfTL5SLmv7Divfaa');
      expect(r.valid, isFalse);
      expect(r.message, contains('controle'));
    });

    test('un caractere change casse le checksum bech32', () {
      final r =
          checkBitcoinAddress('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5');
      expect(r.valid, isFalse);
    });

    test('les caracteres ambigus sont refusés avec une explication', () {
      final r = checkBitcoinAddress('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNO');
      expect(r.valid, isFalse);
    });
  });

  group('Reseaux et formats a refuser', () {
    test('une adresse de test est refusee', () {
      final r =
          checkBitcoinAddress('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx');
      expect(r.valid, isFalse);
      expect(r.message, contains('test'));
    });

    test('une adresse d une autre chaine est refusee', () {
      final r =
          checkBitcoinAddress('0x71C7656EC7ab88b098defB751B7401B5f6d8976F');
      expect(r.valid, isFalse);
    });

    test('un texte quelconque est refuse', () {
      expect(checkBitcoinAddress('bonjour').valid, isFalse);
      expect(checkBitcoinAddress('bc1').valid, isFalse);
    });

    test('le melange de casse en bech32 est refuse', () {
      final r =
          checkBitcoinAddress('BC1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4');
      expect(r.valid, isFalse);
      expect(r.message, contains('majuscules'));
    });

    test('une adresse vide ne declenche pas d erreur', () {
      final r = checkBitcoinAddress('');
      expect(r.valid, isFalse);
      expect(r.message, contains('Saisis'));
    });
  });
}
