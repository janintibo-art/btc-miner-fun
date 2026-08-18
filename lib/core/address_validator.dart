import 'dart:typed_data';

import 'bitcoin_utils.dart';

/// Le verdict d'une verification d'adresse.
class AddressCheck {
  const AddressCheck({
    required this.valid,
    required this.message,
    this.type = '',
    this.detail = '',
  });

  final bool valid;

  /// Message affichable, ecrit pour etre compris sans connaissance technique.
  final String message;

  /// Type d'adresse reconnu, si valide.
  final String type;

  /// Precision technique complementaire.
  final String detail;

  static const AddressCheck empty = AddressCheck(
    valid: false,
    message: 'Saisis une adresse pour la verifier.',
  );
}

/// Verifie une adresse Bitcoin pour de bon : le checksum est recalcule, pas
/// seulement le prefixe. Une seule lettre changee est detectee.
AddressCheck checkBitcoinAddress(String raw) {
  final address = raw.trim();
  if (address.isEmpty) return AddressCheck.empty;

  if (address.contains(' ')) {
    return const AddressCheck(
      valid: false,
      message: 'L\'adresse ne doit contenir aucun espace.',
    );
  }

  final lower = address.toLowerCase();
  if (lower.startsWith('bc1') ||
      lower.startsWith('tb1') ||
      lower.startsWith('bcrt1')) {
    return _checkBech32(address);
  }
  if (address.startsWith('1') ||
      address.startsWith('3') ||
      address.startsWith('m') ||
      address.startsWith('n') ||
      address.startsWith('2')) {
    return _checkBase58(address);
  }

  return const AddressCheck(
    valid: false,
    message: 'Ce n\'est pas une adresse Bitcoin. Une adresse commence par '
        'bc1, par 1 ou par 3.',
  );
}

// ---------------------------------------------------------------------------
// Bech32 et bech32m (BIP 173 et BIP 350)
// ---------------------------------------------------------------------------

const String _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
const List<int> _generator = [
  0x3b6a57b2,
  0x26508e6d,
  0x1ea119fa,
  0x3d4233dd,
  0x2a1462b3,
];

int _polymod(List<int> values) {
  var chk = 1;
  for (final v in values) {
    final b = chk >> 25;
    chk = ((chk & 0x1ffffff) << 5) ^ v;
    for (var i = 0; i < 5; i++) {
      if (((b >> i) & 1) != 0) chk ^= _generator[i];
    }
  }
  return chk;
}

List<int> _hrpExpand(String hrp) {
  final out = <int>[];
  for (final c in hrp.codeUnits) {
    out.add(c >> 5);
  }
  out.add(0);
  for (final c in hrp.codeUnits) {
    out.add(c & 31);
  }
  return out;
}

AddressCheck _checkBech32(String address) {
  final hasUpper = address != address.toLowerCase();
  final hasLower = address != address.toUpperCase();
  if (hasUpper && hasLower) {
    return const AddressCheck(
      valid: false,
      message: 'Une adresse bc1 ne melange jamais majuscules et minuscules.',
    );
  }

  final value = address.toLowerCase();
  final split = value.lastIndexOf('1');
  if (split < 1 || split + 7 > value.length || value.length > 90) {
    return const AddressCheck(
      valid: false,
      message: 'Adresse incomplete ou de longueur invalide.',
    );
  }

  final hrp = value.substring(0, split);
  final dataPart = value.substring(split + 1);
  final data = <int>[];
  for (final c in dataPart.split('')) {
    final index = _charset.indexOf(c);
    if (index < 0) {
      return AddressCheck(
        valid: false,
        message: 'Le caractere "$c" n\'existe pas dans une adresse bc1. '
            'Attention : les lettres b, i, o et le chiffre 1 sont exclus '
            'justement pour eviter les confusions.',
      );
    }
    data.add(index);
  }

  final checksum = _polymod(_hrpExpand(hrp) + data);
  final isBech32 = checksum == 1;
  final isBech32m = checksum == 0x2bc830a3;
  if (!isBech32 && !isBech32m) {
    return const AddressCheck(
      valid: false,
      message: 'Le code de controle ne correspond pas : il y a une faute de '
          'frappe quelque part dans l\'adresse.',
    );
  }

  if (hrp != 'bc') {
    return AddressCheck(
      valid: false,
      message: hrp == 'tb' || hrp == 'bcrt'
          ? 'Cette adresse appartient au reseau de test, pas au vrai Bitcoin. '
              'Les gains y seraient sans valeur.'
          : 'Cette adresse n\'appartient pas au reseau Bitcoin.',
    );
  }

  // Six symboles sont reserves au checksum. Il faut au minimum le symbole de
  // version avant d'acceder a payload.first.
  if (data.length <= 6) {
    return const AddressCheck(
      valid: false,
      message: 'Le contenu de l\'adresse est vide ou incomplet.',
    );
  }

  final payload = data.sublist(0, data.length - 6);
  if (payload.isEmpty) {
    return const AddressCheck(
      valid: false,
      message: 'Le contenu de l\'adresse est vide ou incomplet.',
    );
  }

  final witnessVersion = payload.first;
  if (witnessVersion < 0 || witnessVersion > 16) {
    return const AddressCheck(
      valid: false,
      message: 'Version SegWit invalide : Bitcoin accepte les versions 0 a 16.',
    );
  }

  final program = _convertBits(payload.sublist(1), 5, 8, false);
  if (program == null || program.length < 2 || program.length > 40) {
    return const AddressCheck(
      valid: false,
      message: 'Le contenu de l\'adresse est mal forme.',
    );
  }

  // BIP 350 : v0 utilise Bech32, toutes les versions 1 a 16 utilisent Bech32m.
  if (witnessVersion == 0 && !isBech32) {
    return const AddressCheck(
      valid: false,
      message: 'Mauvais code de controle pour une adresse SegWit version 0.',
    );
  }
  if (witnessVersion > 0 && !isBech32m) {
    return const AddressCheck(
      valid: false,
      message: 'Mauvais code de controle Bech32m pour cette version SegWit.',
    );
  }

  if (witnessVersion == 0) {
    if (program.length == 20) {
      return const AddressCheck(
        valid: true,
        message: 'Adresse valide.',
        type: 'SegWit natif (P2WPKH)',
        detail: 'Le format recommande aujourd\'hui : frais reduits, accepte '
            'par tous les pools.',
      );
    }
    if (program.length == 32) {
      return const AddressCheck(
        valid: true,
        message: 'Adresse valide.',
        type: 'SegWit natif (P2WSH)',
        detail: 'Adresse de script, typiquement multi-signature.',
      );
    }
    return const AddressCheck(
      valid: false,
      message: 'Longueur inattendue pour une adresse de version 0.',
    );
  }

  if (witnessVersion == 1 && program.length == 32) {
    return const AddressCheck(
      valid: true,
      message: 'Adresse valide.',
      type: 'Taproot (P2TR)',
      detail: 'Adresse SegWit version 1 au format Bech32m.',
    );
  }

  return AddressCheck(
    valid: true,
    message: 'Adresse valide, mais de format inhabituel.',
    type: 'SegWit version $witnessVersion',
    detail: 'Version SegWit valide au sens BIP 350 ; verifie la compatibilite '
        'du pool avant de l\'utiliser.',
  );
}

List<int>? _convertBits(List<int> data, int from, int to, bool pad) {
  var acc = 0;
  var bits = 0;
  final out = <int>[];
  final maxv = (1 << to) - 1;
  for (final value in data) {
    if (value < 0 || (value >> from) != 0) return null;
    acc = (acc << from) | value;
    bits += from;
    while (bits >= to) {
      bits -= to;
      out.add((acc >> bits) & maxv);
    }
  }
  if (pad) {
    if (bits > 0) out.add((acc << (to - bits)) & maxv);
  } else if (bits >= from || ((acc << (to - bits)) & maxv) != 0) {
    return null;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Base58Check (adresses historiques en 1 et en 3)
// ---------------------------------------------------------------------------

const String _b58 =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

AddressCheck _checkBase58(String address) {
  if (address.length < 26 || address.length > 35) {
    return const AddressCheck(
      valid: false,
      message: 'Une adresse de ce type compte entre 26 et 35 caracteres.',
    );
  }

  var number = BigInt.zero;
  var leadingZeroes = 0;
  var stillLeading = true;
  for (final c in address.split('')) {
    final index = _b58.indexOf(c);
    if (index < 0) {
      return AddressCheck(
        valid: false,
        message: 'Le caractere "$c" n\'existe pas dans une adresse Bitcoin. '
            'Le zero, la lettre O, le I majuscule et le l minuscule sont '
            'exclus pour eviter les confusions.',
      );
    }
    if (stillLeading && index == 0) {
      leadingZeroes++;
    } else {
      stillLeading = false;
    }
    number = number * BigInt.from(58) + BigInt.from(index);
  }

  // Un caractere '1' en tete encode explicitement un octet 0x00. L'ancienne
  // implementation convertissait directement le BigInt dans 25 octets et
  // perdait cette information, ce qui rendait certaines adresses non
  // canoniques acceptables (par exemple un '1' ajoute devant une adresse).
  final reversed = <int>[];
  var value = number;
  final mask = BigInt.from(0xff);
  while (value > BigInt.zero) {
    reversed.add((value & mask).toInt());
    value = value >> 8;
  }

  final decoded = Uint8List(leadingZeroes + reversed.length);
  for (var i = 0; i < reversed.length; i++) {
    decoded[decoded.length - 1 - i] = reversed[i];
  }

  // Base58Check P2PKH/P2SH = 1 octet version + 20 octets payload + 4 checksum.
  if (decoded.length != 25) {
    return const AddressCheck(
      valid: false,
      message: 'Adresse Base58 non canonique ou de longueur decodee invalide.',
    );
  }

  final body = decoded.sublist(0, 21);
  final checksum = decoded.sublist(21);
  final expected = sha256d(body).sublist(0, 4);
  for (var i = 0; i < 4; i++) {
    if (checksum[i] != expected[i]) {
      return const AddressCheck(
        valid: false,
        message: 'Le code de controle ne correspond pas : il y a une faute de '
            'frappe quelque part dans l\'adresse.',
      );
    }
  }

  switch (body[0]) {
    case 0x00:
      return const AddressCheck(
        valid: true,
        message: 'Adresse valide.',
        type: 'Historique (P2PKH)',
        detail: 'Fonctionne partout, mais les frais de retrait seront plus '
            'eleves qu\'avec une adresse bc1.',
      );
    case 0x05:
      return const AddressCheck(
        valid: true,
        message: 'Adresse valide.',
        type: 'Script (P2SH)',
        detail: 'Souvent du SegWit imbrique. Accepte par tous les pools.',
      );
    case 0x6f:
    case 0xc4:
      return const AddressCheck(
        valid: false,
        message: 'Cette adresse appartient au reseau de test, pas au vrai '
            'Bitcoin. Les gains y seraient sans valeur.',
      );
    default:
      return const AddressCheck(
        valid: false,
        message: 'Cette adresse n\'appartient pas au reseau Bitcoin.',
      );
  }
}
