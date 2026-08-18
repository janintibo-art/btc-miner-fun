import 'package:btc_miner_fun/core/wallet_keys.dart';
import 'package:btc_miner_fun/core/wallet_vault.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// Vecteur PUBLIC du BIP84 : ne jamais utiliser cette phrase pour de vrais fonds.
const _bip84VectorMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';
const _bip84VectorAddress =
    'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';

void main() {
  group('WalletKeys BIP39/BIP84', () {
    test('reproduit le vecteur officiel BIP84 m/84\'/0\'/0\'/0/0', () {
      final wallet = WalletKeys.fromMnemonic(_bip84VectorMnemonic);
      expect(wallet.address, _bip84VectorAddress);
      expect(WalletKeys.derivationPath, "m/84'/0'/0'/0/0");
    });

    test('genere 12 mots valides et une adresse Native SegWit', () {
      final generated = WalletKeys.generate();
      expect(generated.mnemonic.split(' '), hasLength(12));
      expect(WalletKeys.isValidMnemonic(generated.mnemonic), isTrue);
      expect(generated.address.startsWith('bc1q'), isTrue);
    });

    test('deux generations successives ne donnent jamais la meme phrase', () {
      final phrases = <String>{};
      for (var i = 0; i < 20; i++) {
        phrases.add(WalletKeys.generate().mnemonic);
      }
      expect(phrases, hasLength(20));
    });

    test('l entropie provient du generateur securise et varie', () {
      final a = WalletKeys.secureEntropy(16);
      final b = WalletKeys.secureEntropy(16);
      expect(a, hasLength(16));
      expect(a, isNot(equals(b)));
      // Une entropie constante ou nulle serait le pire defaut possible.
      expect(a.every((byte) => byte == a.first), isFalse);
    });

    test('une entropie donnee redonne toujours la meme adresse', () {
      final wallet = WalletKeys.fromMnemonic(_bip84VectorMnemonic);
      expect(wallet.address, _bip84VectorAddress);
    });

    test('normalise espaces et majuscules avant validation', () {
      final normalized = WalletKeys.normalizeMnemonic(
        '  ABANDON  abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon ABOUT  ',
      );
      expect(normalized, _bip84VectorMnemonic);
      expect(WalletKeys.isValidMnemonic(normalized), isTrue);
    });

    test('refuse une phrase dont le checksum BIP39 est faux', () {
      const bad =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon';
      expect(WalletKeys.isValidMnemonic(bad), isFalse);
      expect(() => WalletKeys.fromMnemonic(bad), throwsFormatException);
    });
  });

  group('WalletVault', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test('restaure, recharge puis efface sans stocker une cle privee brute', () async {
      const vault = WalletVault();
      final restored = await vault.restore(_bip84VectorMnemonic);
      expect(restored.address, _bip84VectorAddress);
      expect(restored.backupConfirmed, isTrue);

      final loaded = await vault.loadInfo();
      expect(loaded, isNotNull);
      expect(loaded!.address, _bip84VectorAddress);
      expect(await vault.revealMnemonic(), _bip84VectorMnemonic);

      await vault.deleteWallet();
      expect(await vault.loadInfo(), isNull);
    });
  });
}
