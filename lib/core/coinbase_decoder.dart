import 'dart:typed_data';

import 'bitcoin_utils.dart';

/// Une sortie de la transaction coinbase.
class CoinbaseOutput {
  const CoinbaseOutput({
    required this.satoshis,
    required this.scriptHex,
    required this.kind,
  });

  final int satoshis;
  final String scriptHex;
  final String kind;

  double get btc => satoshis / kSatoshisPerBtc;
}

/// La transaction coinbase decortiquee.
///
/// C'est la transaction que le pool te fait fabriquer et qui, si tu trouvais un
/// bloc, creerait les bitcoins de la recompense. Elle contient la hauteur du
/// bloc, ton extranonce, et tres souvent un message laisse par le pool.
class DecodedCoinbase {
  const DecodedCoinbase({
    required this.totalBytes,
    required this.version,
    required this.blockHeight,
    required this.scriptSigHex,
    required this.messages,
    required this.outputs,
    required this.lockTime,
    required this.complete,
    this.error,
  });

  final int totalBytes;
  final int version;

  /// Hauteur du bloc, inscrite en tete du scriptSig depuis le BIP 34.
  final int? blockHeight;

  final String scriptSigHex;

  /// Fragments de texte lisible trouves dans le scriptSig : la signature que
  /// les pools laissent dans les blocs qu'ils minent.
  final List<String> messages;

  final List<CoinbaseOutput> outputs;
  final int lockTime;
  final bool complete;
  final String? error;

  int get totalSatoshis =>
      outputs.fold(0, (sum, output) => sum + output.satoshis);

  double get totalBtc => totalSatoshis / kSatoshisPerBtc;

  static const DecodedCoinbase empty = DecodedCoinbase(
    totalBytes: 0,
    version: 0,
    blockHeight: null,
    scriptSigHex: '',
    messages: <String>[],
    outputs: <CoinbaseOutput>[],
    lockTime: 0,
    complete: false,
  );
}

class _Reader {
  _Reader(this.data);
  final Uint8List data;
  int offset = 0;

  bool get done => offset >= data.length;
  int get remaining => data.length - offset;

  int u8() {
    if (remaining < 1) throw const FormatException('donnees tronquees');
    return data[offset++];
  }

  int uint(int bytes) {
    if (remaining < bytes) throw const FormatException('donnees tronquees');
    var value = 0;
    for (var i = 0; i < bytes; i++) {
      value |= data[offset + i] << (8 * i);
    }
    offset += bytes;
    return value;
  }

  /// Entier a taille variable, omnipresent dans le format Bitcoin.
  int varint() {
    final first = u8();
    if (first < 0xfd) return first;
    if (first == 0xfd) return uint(2);
    if (first == 0xfe) return uint(4);
    return uint(8);
  }

  Uint8List take(int length) {
    if (length < 0 || remaining < length) {
      throw const FormatException('longueur invalide');
    }
    final slice = Uint8List.sublistView(data, offset, offset + length);
    offset += length;
    return Uint8List.fromList(slice);
  }
}

/// Reconstruit la coinbase a partir des morceaux fournis par le pool, puis la
/// decode. Un decodage partiel vaut mieux que rien : en cas de champ
/// inattendu, ce qui a ete lu est conserve.
DecodedCoinbase decodeCoinbase({
  required String coinb1,
  required String extranonce1,
  required String extranonce2,
  required String coinb2,
}) {
  final Uint8List raw;
  try {
    raw = hexToBytes(coinb1 + extranonce1 + extranonce2 + coinb2);
  } catch (e) {
    return DecodedCoinbase.empty;
  }

  final reader = _Reader(raw);
  var version = 0;
  int? height;
  var scriptSigHex = '';
  var messages = <String>[];
  final outputs = <CoinbaseOutput>[];
  var lockTime = 0;

  try {
    version = reader.uint(4);

    final inputCount = reader.varint();
    if (inputCount != 1) {
      throw const FormatException('une coinbase n\'a qu\'une seule entree');
    }

    reader.take(32); // hash de la sortie precedente : que des zeros
    reader.uint(4); // index : 0xffffffff
    final script = reader.take(reader.varint());
    scriptSigHex = bytesToHex(script);
    height = _readBip34Height(script);
    messages = extractReadableText(script);
    reader.uint(4); // sequence

    final outputCount = reader.varint();
    for (var i = 0; i < outputCount; i++) {
      final satoshis = reader.uint(8);
      final script = reader.take(reader.varint());
      outputs.add(CoinbaseOutput(
        satoshis: satoshis,
        scriptHex: bytesToHex(script),
        kind: describeScript(script),
      ));
    }

    lockTime = reader.uint(4);

    return DecodedCoinbase(
      totalBytes: raw.length,
      version: version,
      blockHeight: height,
      scriptSigHex: scriptSigHex,
      messages: messages,
      outputs: outputs,
      lockTime: lockTime,
      complete: true,
    );
  } catch (e) {
    return DecodedCoinbase(
      totalBytes: raw.length,
      version: version,
      blockHeight: height,
      scriptSigHex: scriptSigHex,
      messages: messages,
      outputs: outputs,
      lockTime: lockTime,
      complete: false,
      error: e is FormatException ? e.message : e.toString(),
    );
  }
}

/// Depuis le BIP 34, tout bloc commence son scriptSig par la hauteur du bloc,
/// poussee en petit-boutiste.
int? _readBip34Height(Uint8List script) {
  if (script.isEmpty) return null;
  final pushLength = script[0];
  if (pushLength < 1 || pushLength > 5 || script.length < pushLength + 1) {
    return null;
  }
  var height = 0;
  for (var i = 0; i < pushLength; i++) {
    height |= script[1 + i] << (8 * i);
  }
  return height;
}

/// Extrait les suites de caracteres imprimables : c'est la que se cachent les
/// signatures des pools et les messages laisses dans les blocs.
List<String> extractReadableText(Uint8List data, {int minLength = 4}) {
  final found = <String>[];
  final buffer = StringBuffer();

  void flush() {
    if (buffer.length >= minLength) found.add(buffer.toString());
    buffer.clear();
  }

  for (final byte in data) {
    if (byte >= 0x20 && byte <= 0x7e) {
      buffer.writeCharCode(byte);
    } else {
      flush();
    }
  }
  flush();
  return found;
}

/// Reconnait les formes de script les plus courantes dans une coinbase.
String describeScript(Uint8List script) {
  if (script.isEmpty) return 'vide';
  if (script[0] == 0x6a) {
    if (script.length >= 6 &&
        script[2] == 0xaa &&
        script[3] == 0x21 &&
        script[4] == 0xa9 &&
        script[5] == 0xed) {
      return 'engagement SegWit (OP_RETURN)';
    }
    return 'donnees (OP_RETURN)';
  }
  if (script.length == 22 && script[0] == 0x00 && script[1] == 0x14) {
    return 'SegWit natif (P2WPKH)';
  }
  if (script.length == 34 && script[0] == 0x00 && script[1] == 0x20) {
    return 'SegWit natif (P2WSH)';
  }
  if (script.length == 34 && script[0] == 0x51 && script[1] == 0x20) {
    return 'Taproot (P2TR)';
  }
  if (script.length == 25 && script[0] == 0x76 && script[1] == 0xa9) {
    return 'historique (P2PKH)';
  }
  if (script.length == 23 && script[0] == 0xa9) {
    return 'script (P2SH)';
  }
  if (script.length == 67 && script[script.length - 1] == 0xac) {
    return 'cle publique brute (P2PK)';
  }
  return 'script de ${script.length} octets';
}
