import 'package:btc_miner_fun/core/nonce_walker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Signature derivee d une phrase', () {
    test('les conditions de Hull-Dobell sont respectees', () {
      for (final phrase in [
        'bc1qexemple/telephone',
        'ma phrase a moi',
        '',
        'a',
        'Les carottes sont cuites 42',
      ]) {
        final s = NonceSignature.fromPhrase(phrase);
        expect(signatureCoversWholeSpace(s), isTrue,
            reason: 'phrase "$phrase" : a=${s.multiplier} c=${s.increment}');
      }
    });

    test('deux phrases differentes donnent des marches differentes', () {
      final a = NonceSignature.fromPhrase('phrase une');
      final b = NonceSignature.fromPhrase('phrase deux');
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('la meme phrase redonne toujours la meme marche', () {
      expect(
        NonceSignature.fromPhrase('stable').fingerprint,
        NonceSignature.fromPhrase('stable').fingerprint,
      );
    });
  });

  group('Marche signature', () {
    final signature = NonceSignature.fromPhrase('test de marche');

    test('aucune repetition sur cent mille nonces', () {
      final walker = NonceWalker.create(
        strategy: NonceStrategy.signature,
        signature: signature,
        startNonce: 0,
        offset: 0,
        stride: 1,
      );
      final seen = <int>{};
      for (var i = 0; i < 100000; i++) {
        expect(seen.add(walker.next()), isTrue,
            reason: 'nonce repete a la tentative $i');
      }
    });

    test('tous les nonces restent dans 32 bits', () {
      final walker = NonceWalker.create(
        strategy: NonceStrategy.signature,
        signature: signature,
        startNonce: 0,
        offset: 0,
        stride: 4,
      );
      for (var i = 0; i < 5000; i++) {
        final n = walker.next();
        expect(n, greaterThanOrEqualTo(0));
        expect(n, lessThanOrEqualTo(0xFFFFFFFF));
      }
    });

    test('quatre coeurs ne se marchent jamais dessus', () {
      final sets = <Set<int>>[];
      for (var core = 0; core < 4; core++) {
        final walker = NonceWalker.create(
          strategy: NonceStrategy.signature,
          signature: signature,
          startNonce: 0,
          offset: core,
          stride: 4,
        );
        sets.add({for (var i = 0; i < 3000; i++) walker.next()});
      }
      for (var a = 0; a < 4; a++) {
        for (var b = a + 1; b < 4; b++) {
          expect(sets[a].intersection(sets[b]), isEmpty,
              reason: 'chevauchement entre les coeurs $a et $b');
        }
      }
    });
  });

  group('Autres strategies', () {
    test('la sequentielle avance du pas du coeur', () {
      final walker = NonceWalker.create(
        strategy: NonceStrategy.sequentielle,
        signature: NonceSignature.fromPhrase('x'),
        startNonce: 1000,
        offset: 2,
        stride: 4,
      );
      expect(walker.next(), 1002);
      expect(walker.next(), 1006);
      expect(walker.next(), 1010);
    });

    test('l aleatoire reste dans 32 bits', () {
      final walker = NonceWalker.create(
        strategy: NonceStrategy.aleatoire,
        signature: NonceSignature.fromPhrase('x'),
        startNonce: 5,
        offset: 0,
        stride: 1,
      );
      for (var i = 0; i < 1000; i++) {
        final n = walker.next();
        expect(n, inInclusiveRange(0, 0xFFFFFFFF));
      }
    });
  });
}
