import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:pointycastle/export.dart';

import 'bitcoin_utils.dart';

/// Identite sur la chaine Tibo : une adresse, une cle publique, une cle privee.
///
/// Aucune cryptographie n'est ecrite ici. La phrase de recuperation est
/// transformee en graine par la meme bibliotheque que le portefeuille Bitcoin,
/// et la signature est faite par pointycastle, sur la courbe secp256k1 - la
/// meme que Bitcoin.
///
/// La derivation est volontairement simple et documentee : la cle privee est
/// le SHA-256 de la graine BIP39 prefixee d'une etiquette. Ce n'est pas un
/// chemin BIP32 standard, et c'est assume : une chaine qui ne vaut rien n'a
/// pas besoin d'etre compatible avec les portefeuilles du marche. En revanche
/// elle est parfaitement reproductible - la meme phrase redonne toujours la
/// meme adresse, sur n'importe quel appareil.
class TiboIdentity {
  TiboIdentity._({
    required this.address,
    required this.publicKeyHex,
    required ECPrivateKey privateKey,
  }) : _privateKey = privateKey;

  final String address;
  final String publicKeyHex;
  final ECPrivateKey _privateKey;

  static final ECDomainParameters _courbe = ECDomainParameters('secp256k1');

  /// Etiquette de derivation. La changer donnerait des adresses differentes
  /// pour la meme phrase : elle est donc figee.
  static const String _etiquette = 'TIBO-v1';

  /// Octet de version des adresses Tibo. Choisi pour que les adresses
  /// commencent par un T, et different de toutes les chaines du catalogue :
  /// une adresse Tibo ne peut pas etre confondue avec une adresse Bitcoin.
  static const int versionByte = 0x41;

  /// Reconstruit l'identite depuis une phrase de recuperation.
  static TiboIdentity fromMnemonic(String phrase) {
    final normalisee = _normaliser(phrase);
    final mnemonic = Mnemonic.fromString(normalisee);
    final graine = Bip39SeedGenerator(mnemonic).generate();

    try {
      // Uint8List.fromList explicite : selon la version du SDK, utf8.encode
      // peut renvoyer un List<int>, que pointycastle refuse.
      final source = Uint8List.fromList(
          <int>[...utf8.encode(_etiquette), ...graine]);
      final secret = SHA256Digest().process(source);
      return fromPrivateKeyBytes(secret);
    } finally {
      for (var i = 0; i < graine.length; i++) {
        graine[i] = 0;
      }
    }
  }

  /// Construit l'identite depuis 32 octets de cle privee.
  static TiboIdentity fromPrivateKeyBytes(Uint8List secret) {
    var d = BigInt.parse(bytesToHex(secret), radix: 16);
    final n = _courbe.n;
    // Une cle valide est comprise entre 1 et n-1. La probabilite de sortir de
    // cet intervalle est infime, mais le cas est traite plutot qu'ignore.
    d = d % n;
    if (d == BigInt.zero) d = BigInt.one;

    final prive = ECPrivateKey(d, _courbe);
    final point = _courbe.G * d;
    final publique = point!.getEncoded(true); // forme compressee, 33 octets

    return TiboIdentity._(
      address: addressFromPublicKey(publique),
      publicKeyHex: bytesToHex(publique),
      privateKey: prive,
    );
  }

  /// Adresse a partir de la cle publique : hash160, octet de version, et code
  /// de controle. Exactement le schema de Bitcoin, avec une autre version.
  static String addressFromPublicKey(Uint8List publicKey) {
    final sha = SHA256Digest().process(publicKey);
    final hash160 = RIPEMD160Digest().process(sha);

    final corps = Uint8List.fromList(<int>[versionByte, ...hash160]);
    final controle = SHA256Digest().process(SHA256Digest().process(corps));
    final complet =
        Uint8List.fromList(<int>[...corps, ...controle.sublist(0, 4)]);
    return _base58(complet);
  }

  /// Signe un message et renvoie 64 octets : r suivi de s.
  ///
  /// La signature est deterministe (RFC 6979) : signer deux fois le meme
  /// message donne le meme resultat, ce qui rend les tests reproductibles.
  String sign(String message) {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter<ECPrivateKey>(_privateKey));
    final signature = signer.generateSignature(
        Uint8List.fromList(utf8.encode(message))) as ECSignature;

    final r = _trente_deux(signature.r);
    final s = _trente_deux(signature.s);
    return bytesToHex(Uint8List.fromList(<int>[...r, ...s]));
  }

  static Uint8List _trente_deux(BigInt valeur) {
    var hex = valeur.toRadixString(16);
    if (hex.length > 64) hex = hex.substring(hex.length - 64);
    return hexToBytes(hex.padLeft(64, '0'));
  }

  static String _normaliser(String phrase) => phrase
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((mot) => mot.isNotEmpty)
      .join(' ');

  static const String _alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static String _base58(Uint8List bytes) {
    var valeur = BigInt.zero;
    for (final octet in bytes) {
      valeur = valeur * BigInt.from(256) + BigInt.from(octet);
    }
    final tampon = StringBuffer();
    final base = BigInt.from(58);
    while (valeur > BigInt.zero) {
      final reste = (valeur % base).toInt();
      tampon.write(_alphabet[reste]);
      valeur = valeur ~/ base;
    }
    final resultat = tampon.toString().split('').reversed.join();
    // Chaque octet nul de tete devient un '1', comme dans Bitcoin.
    var zeros = 0;
    while (zeros < bytes.length && bytes[zeros] == 0) {
      zeros++;
    }
    return '1' * zeros + resultat;
  }

  /// Verifie la forme et le code de controle d'une adresse Tibo.
  static bool isValidAddress(String address) {
    try {
      var valeur = BigInt.zero;
      for (final caractere in address.split('')) {
        final index = _alphabet.indexOf(caractere);
        if (index < 0) return false;
        valeur = valeur * BigInt.from(58) + BigInt.from(index);
      }
      var hex = valeur.toRadixString(16);
      if (hex.length % 2 != 0) hex = '0$hex';
      final octets = hexToBytes(hex.padLeft(50, '0'));
      if (octets.length != 25) return false;
      if (octets[0] != versionByte) return false;

      final corps = Uint8List.fromList(octets.sublist(0, 21));
      final attendu = SHA256Digest().process(SHA256Digest().process(corps));
      for (var i = 0; i < 4; i++) {
        if (octets[21 + i] != attendu[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
