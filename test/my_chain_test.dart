import 'package:btc_miner_fun/core/bitcoin_utils.dart';
import 'package:btc_miner_fun/core/my_chain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Format compact de la difficulte', () {
    test('les bits de Bitcoin donnent la cible de difficulte 1', () {
      final target = targetFromBits(0x1d00ffff);
      expect(
        bytesToHex(bigIntTo32Bytes(target)),
        '00000000ffff0000000000000000000000000000000000000000000000000000',
      );
    });

    test('l encodage inverse redonne les memes bits', () {
      expect(bitsFromTarget(targetFromBits(0x1d00ffff)), 0x1d00ffff);
      expect(bitsFromTarget(targetFromBits(0x1a44b9f2)), 0x1a44b9f2);
      expect(bitsFromTarget(targetFromBits(0x1f00ffff)), 0x1f00ffff);
    });

    test('une cible plus petite donne une difficulte plus grande', () {
      final facile = difficultyFromBits(0x1f00ffff, 0x1f00ffff);
      final dur = difficultyFromBits(0x1e00ffff, 0x1f00ffff);
      expect(facile, closeTo(1, 0.001));
      expect(dur, greaterThan(facile));
    });
  });

  group('Chaine personnelle', () {
    ChainRules rules() => const ChainRules(
          name: 'Test',
          symbol: 'TST',
          targetSeconds: 10,
          retargetInterval: 4,
          initialReward: 50,
          halvingInterval: 8,
        );

    test('la genese ne succede a rien et sa chaine est valide', () {
      final chain = MyChain(rules: rules());
      chain.blocks.add(chain.createGenesis(DateTime(2026)));
      expect(chain.height, 1);
      expect(chain.tip!.previousHash, '0' * 64);
      expect(chain.verify().valid, isTrue);
    });

    test('un message de genese different donne une chaine differente', () {
      final a = MyChain(rules: const ChainRules(genesisMessage: 'un'));
      final b = MyChain(rules: const ChainRules(genesisMessage: 'deux'));
      final ga = a.createGenesis(DateTime(2026));
      final gb = b.createGenesis(DateTime(2026));
      expect(ga.merkleRoot, isNot(gb.merkleRoot));
    });

    test('la recompense est divisee par deux a intervalle regulier', () {
      final r = rules();
      expect(r.rewardAt(0), 50);
      expect(r.rewardAt(7), 50);
      expect(r.rewardAt(8), 25);
      expect(r.rewardAt(16), 12.5);
    });

    test('l en-tete fait toujours 80 octets', () {
      final chain = MyChain(rules: rules());
      final genesis = chain.createGenesis(DateTime(2026));
      expect(genesis.header().length, 80);
      expect(genesis.hash.length, 64);
    });

    test('un bloc sans preuve de travail est rejete', () {
      final chain = MyChain(rules: rules());
      chain.blocks.add(chain.createGenesis(DateTime(2026)));
      final faux = chain.prepareNext(DateTime(2026, 1, 1, 0, 1), 'triche');
      chain.blocks.add(faux); // nonce nul, donc quasiment jamais valable
      final verdict = chain.verify();
      expect(verdict.valid, isFalse);
      expect(verdict.problem, contains('difficulte'));
    });

    test('un bloc qui ne suit pas le precedent est rejete', () {
      final chain = MyChain(rules: rules());
      chain.blocks.add(chain.createGenesis(DateTime(2026)));
      chain.blocks.add(MyBlock(
        height: 1,
        version: 1,
        previousHash: 'ff' * 32,
        merkleRoot: '00' * 32,
        time: chain.tip!.time + 10,
        bits: 0x1f00ffff,
        nonce: 0,
        message: 'orphelin',
        reward: 50,
        hashesTried: 0,
      ));
      expect(chain.verify().valid, isFalse);
    });

    test('la sauvegarde conserve la chaine a l identique', () {
      final chain = MyChain(rules: rules());
      chain.blocks.add(chain.createGenesis(DateTime(2026)));
      final relu = MyChain.tryDecode(chain.encode());
      expect(relu, isNotNull);
      expect(relu!.height, 1);
      expect(relu.tip!.hash, chain.tip!.hash);
      expect(relu.rules.symbol, 'TST');
    });

    test('le solde est la somme des recompenses', () {
      final chain = MyChain(rules: rules());
      chain.blocks.add(chain.createGenesis(DateTime(2026)));
      expect(chain.balance, 50);
    });
  });
}
