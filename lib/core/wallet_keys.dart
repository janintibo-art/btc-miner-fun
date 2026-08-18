import 'dart:math';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart';

/// Materiel public derive d'une phrase BIP39.
///
/// La phrase n'est jamais exposee dans [toString] afin d'eviter qu'un journal
/// de debug ne la publie par accident.
class GeneratedBitcoinWallet {
  const GeneratedBitcoinWallet({
    required this.mnemonic,
    required this.address,
  });

  final String mnemonic;
  final String address;

  @override
  String toString() => 'GeneratedBitcoinWallet(address: $address)';
}

/// Primitives de creation/restauration du portefeuille local.
///
/// Aucune implementation cryptographique n'est ecrite dans l'application :
/// BIP39, BIP32 et BIP84 sont delegues a `blockchain_utils`.
class WalletKeys {
  WalletKeys._();

  static const String derivationPath = "m/84'/0'/0'/0/0";

  /// L'application cree volontairement 12 mots (128 bits d'entropie BIP39).
  ///
  /// L'entropie est fournie explicitement par [Random.secure], qui s'appuie sur
  /// le generateur cryptographique du systeme (`/dev/urandom` sur Android,
  /// `BCryptGenRandom` sur Windows). C'est le seul point de toute la chaine qui
  /// determine la solidite du portefeuille : on ne le delegue donc pas au
  /// choix par defaut d'une bibliotheque, il est explicite et verifiable ici.
  static GeneratedBitcoinWallet generate() {
    final entropy = secureEntropy(16); // 128 bits
    try {
      final mnemonic = Bip39MnemonicGenerator()
          .fromEntropy(entropy)
          .toStr();
      return fromMnemonic(mnemonic);
    } finally {
      for (var i = 0; i < entropy.length; i++) {
        entropy[i] = 0;
      }
    }
  }

  /// Octets aleatoires issus du generateur cryptographique du systeme.
  static Uint8List secureEntropy(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Accepte toute phrase BIP39 anglaise valide (12/15/18/21/24 mots), puis
  /// derive la premiere adresse de reception Native SegWit du compte Bitcoin.
  static GeneratedBitcoinWallet fromMnemonic(String phrase) {
    final normalized = normalizeMnemonic(phrase);
    if (!isValidMnemonic(normalized)) {
      throw const FormatException('Phrase de recuperation BIP39 invalide.');
    }

    final mnemonic = Mnemonic.fromString(normalized);
    final seed = Bip39SeedGenerator(mnemonic).generate();
    try {
      final bip84 = Bip84.fromSeed(seed, Bip84Coins.bitcoin).deriveDefaultPath;
      final address = bip84.publicKey.toAddress;
      if (!address.startsWith('bc1q')) {
        throw StateError('Adresse BIP84 inattendue.');
      }
      return GeneratedBitcoinWallet(
        mnemonic: normalized,
        address: address,
      );
    } finally {
      // Une String Dart ne peut pas etre effacee de facon garantie, mais le
      // buffer de seed mutable peut au moins etre nettoye apres derivation.
      try {
        for (var i = 0; i < seed.length; i++) {
          seed[i] = 0;
        }
      } catch (_) {
        // Certaines implementations peuvent retourner une vue non modifiable.
      }
    }
  }

  static String normalizeMnemonic(String phrase) => phrase
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .join(' ');

  static bool isValidMnemonic(String phrase) {
    final normalized = normalizeMnemonic(phrase);
    if (normalized.isEmpty) return false;
    try {
      return Bip39MnemonicValidator(Bip39Languages.english)
          .isValid(normalized);
    } catch (_) {
      return false;
    }
  }
}
