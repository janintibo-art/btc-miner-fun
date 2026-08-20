import 'package:btc_miner_fun/core/address_validator.dart';
import 'package:btc_miner_fun/core/coins.dart';
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

  group('Autres chaines', () {
    Coin coin(String symbol) => coinBySymbol(symbol)!;

    // Adresses construites depuis leur octet de version et verifiees : le
    // code de controle est calcule, pas suppose.
    test('une adresse Litecoin est acceptee pour Litecoin', () {
      final r = checkCoinAddress('LKDyUEtTR1HXamkiEphisSiBJu6o3ZPE34', coin('LTC'));
      expect(r.valid, isTrue, reason: r.message);
      expect(r.type, contains('Litecoin'));
    });

    test('une adresse Dogecoin est acceptee pour Dogecoin', () {
      final r = checkCoinAddress('D597kHXGdkwkryF9oGhz9Bp1ypTpD1u99Z', coin('DOGE'));
      expect(r.valid, isTrue, reason: r.message);
    });

    test('une adresse Litecoin est refusee pour Dogecoin', () {
      final r = checkCoinAddress('LKDyUEtTR1HXamkiEphisSiBJu6o3ZPE34', coin('DOGE'));
      expect(r.valid, isFalse);
    });

    test('une adresse Bitcoin est refusee pour Litecoin', () {
      final r = checkCoinAddress(
          '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa', coin('LTC'));
      expect(r.valid, isFalse);
      expect(r.message, contains('Litecoin'));
    });

    test('une faute de frappe reste detectee sur les autres chaines', () {
      final r = checkCoinAddress('LKDyUEtTR1HXamkiEphisSiBJu6o3ZPE3A', coin('LTC'));
      expect(r.valid, isFalse);
      expect(r.message, contains('controle'));
    });

    test('Bitcoin garde son comportement detaille', () {
      final r = checkCoinAddress(
          'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4', coin('BTC'));
      expect(r.valid, isTrue);
      expect(r.type, contains('SegWit'));
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

  group('Cas limites Base58Check et BIP 350', () {
    test('un 1 ajoute devant une adresse Base58 valide est refuse', () {
      final r =
          checkBitcoinAddress('11A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa');
      expect(r.valid, isFalse);
    });

    test('une adresse SegWit v16 Bech32m officielle est acceptee', () {
      final r = checkBitcoinAddress('BC1SW50QGDZ25J');
      expect(r.valid, isTrue, reason: r.message);
      expect(r.type, 'SegWit version 16');
    });

    test('une version SegWit superieure a 16 est refusee', () {
      final r = checkBitcoinAddress(
          'BC130XLXVLHEMJA6C4DQV22UAPCTQUPFHLXM9H8Z3K2E72Q4K9HCZ7VQ7ZWS8R');
      expect(r.valid, isFalse);
      expect(r.message, contains('0 a 16'));
    });

    test('une adresse v1 encodee en Bech32 au lieu de Bech32m est refusee', () {
      final r = checkBitcoinAddress(
          'bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqh2y7hd');
      expect(r.valid, isFalse);
      expect(r.message.toLowerCase(), contains('bech32m'));
    });

    test('une section de donnees vide est refusee sans exception', () {
      final r = checkBitcoinAddress('bc1gmk9yu');
      expect(r.valid, isFalse);
    });
  });

}
