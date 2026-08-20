import 'dart:typed_data';

import 'package:btc_miner_fun/core/bitcoin_utils.dart';
import 'package:btc_miner_fun/core/scrypt.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vecteurs produits avec une implementation de reference de scrypt
/// (parametres N=1024, r=1, p=1, sortie de 32 octets), ceux de Litecoin.
void main() {
  final scrypt = Scrypt();

  test('en-tete de reference', () {
    final header = hexToBytes(
      '01000000'
      '0000000000000000000000000000000000000000000000000000000000000000'
      '1111111111111111111111111111111111111111111111111111111111111111'
      'c7f5d74d'
      'f2b9441a'
      '42a14695',
    );
    expect(header.length, 80);
    expect(
      bytesToHex(scrypt.hash(header)),
      '19bb663c0b7087a012ab972af80f1b4ce47d0fb9e03bcfe46af478f9f9551bef',
    );
  });

  test('en-tete 00 01 02 ... 4f', () {
    final header = Uint8List.fromList(List<int>.generate(80, (i) => i));
    expect(
      bytesToHex(scrypt.hash(header)),
      'bc540a1a801df96e493005c71e010e2d387607fbf0fec416fd3c2645aa1ba9d2',
    );
  });

  test('la meme instance rend le meme resultat plusieurs fois de suite', () {
    final header = Uint8List.fromList(List<int>.generate(80, (i) => 255 - i));
    final first = bytesToHex(scrypt.hash(header));
    final second = bytesToHex(scrypt.hash(header));
    expect(second, first, reason: 'les tampons reutilises doivent etre remis a zero');
  });

  test('changer un seul octet change tout le resultat', () {
    final a = Uint8List.fromList(List<int>.generate(80, (i) => i));
    final b = Uint8List.fromList(List<int>.generate(80, (i) => i));
    b[40] ^= 1;
    expect(bytesToHex(scrypt.hash(a)), isNot(bytesToHex(scrypt.hash(b))));
  });
}
