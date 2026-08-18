import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'wallet_keys.dart';

class LocalWalletInfo {
  const LocalWalletInfo({
    required this.address,
    required this.backupConfirmed,
  });

  final String address;
  final bool backupConfirmed;

  String get derivationPath => WalletKeys.derivationPath;
}

class LocalWalletCreation extends LocalWalletInfo {
  const LocalWalletCreation({
    required super.address,
    required super.backupConfirmed,
    required this.mnemonic,
  });

  final String mnemonic;
}

/// Coffre local du portefeuille.
///
/// Seule la phrase BIP39 est un secret. Elle est conservee avec le stockage
/// securise natif de la plateforme, jamais avec SharedPreferences.
class WalletVault {
  const WalletVault({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        migrateWithBackup: true,
        storageNamespace: 'btc_miner_fun_wallet_v1',
      ),
    ),
  }) : _storage = storage;

  static const _mnemonicKey = 'bip39_mnemonic';
  static const _addressKey = 'bip84_address_0';
  static const _backupKey = 'recovery_backup_confirmed';
  static const _versionKey = 'wallet_format_version';

  final FlutterSecureStorage _storage;

  Future<bool> get hasWallet async {
    final phrase = await _storage.read(key: _mnemonicKey);
    return phrase != null && phrase.trim().isNotEmpty;
  }

  /// Recharge le coffre et rederive l'adresse depuis la phrase. L'adresse
  /// stockee n'est donc jamais consideree comme une source de verite.
  Future<LocalWalletInfo?> loadInfo() async {
    final phrase = await _storage.read(key: _mnemonicKey);
    if (phrase == null || phrase.trim().isEmpty) return null;

    final wallet = WalletKeys.fromMnemonic(phrase);
    final savedAddress = await _storage.read(key: _addressKey);
    if (savedAddress != wallet.address) {
      await _storage.write(key: _addressKey, value: wallet.address);
    }
    final backup = await _storage.read(key: _backupKey) == '1';
    return LocalWalletInfo(
      address: wallet.address,
      backupConfirmed: backup,
    );
  }

  Future<LocalWalletCreation> create() async {
    if (await hasWallet) {
      throw StateError('Un portefeuille local existe deja.');
    }
    final generated = WalletKeys.generate();
    await _store(generated, backupConfirmed: false);
    return LocalWalletCreation(
      address: generated.address,
      mnemonic: generated.mnemonic,
      backupConfirmed: false,
    );
  }

  /// Restaure une phrase BIP39 et remplace le contenu du coffre.
  /// L'ecran d'appel doit demander une confirmation explicite avant ecrasement.
  Future<LocalWalletCreation> restore(String phrase) async {
    final restored = WalletKeys.fromMnemonic(phrase);
    await _store(restored, backupConfirmed: true);
    return LocalWalletCreation(
      address: restored.address,
      mnemonic: restored.mnemonic,
      backupConfirmed: true,
    );
  }

  Future<void> _store(
    GeneratedBitcoinWallet wallet, {
    required bool backupConfirmed,
  }) async {
    // La phrase est ecrite en dernier et sert de marqueur de commit. Si une
    // ecriture de metadonnees echoue avant, hasWallet reste faux.
    await _storage.write(key: _addressKey, value: wallet.address);
    await _storage.write(key: _backupKey, value: backupConfirmed ? '1' : '0');
    await _storage.write(key: _versionKey, value: '1');
    await _storage.write(key: _mnemonicKey, value: wallet.mnemonic);
  }

  Future<String?> revealMnemonic() async {
    final phrase = await _storage.read(key: _mnemonicKey);
    if (phrase == null || phrase.trim().isEmpty) return null;
    final normalized = WalletKeys.normalizeMnemonic(phrase);
    if (!WalletKeys.isValidMnemonic(normalized)) {
      throw StateError('Le coffre contient une phrase invalide.');
    }
    return normalized;
  }

  Future<void> markBackupConfirmed() =>
      _storage.write(key: _backupKey, value: '1');

  Future<void> deleteWallet() async {
    await _storage.delete(key: _mnemonicKey);
    await _storage.delete(key: _addressKey);
    await _storage.delete(key: _backupKey);
    await _storage.delete(key: _versionKey);
  }
}
