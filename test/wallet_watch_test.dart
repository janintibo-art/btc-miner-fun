import 'package:btc_miner_fun/core/wallet_watch.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'explorateur ne renvoie pas un solde tout fait : il faut soustraire les
/// sorties depensees des sorties recues. Une erreur ici afficherait un solde
/// faux, donc ces tests couvrent tous les cas de figure.
void main() {
  group('Lecture du solde', () {
    test('une adresse ayant recu puis rien depense', () {
      final b = parseAddressStats('bc1test', {
        'chain_stats': {
          'funded_txo_sum': 312500000,
          'spent_txo_sum': 0,
          'tx_count': 1,
        },
        'mempool_stats': {
          'funded_txo_sum': 0,
          'spent_txo_sum': 0,
          'tx_count': 0,
        },
      });
      expect(b.confirmedSats, 312500000);
      expect(b.totalBtc, 3.125);
      expect(b.transactionCount, 1);
      expect(b.isEmpty, isFalse);
    });

    test('les depenses sont bien soustraites', () {
      final b = parseAddressStats('bc1test', {
        'chain_stats': {
          'funded_txo_sum': 100000,
          'spent_txo_sum': 40000,
          'tx_count': 2,
        },
      });
      expect(b.confirmedSats, 60000);
    });

    test('les transactions en attente sont comptees a part', () {
      final b = parseAddressStats('bc1test', {
        'chain_stats': {
          'funded_txo_sum': 50000,
          'spent_txo_sum': 0,
          'tx_count': 1,
        },
        'mempool_stats': {
          'funded_txo_sum': 25000,
          'spent_txo_sum': 0,
          'tx_count': 1,
        },
      });
      expect(b.confirmedSats, 50000);
      expect(b.pendingSats, 25000);
      expect(b.totalSats, 75000);
      expect(b.transactionCount, 2);
    });

    test('une adresse jamais utilisee donne un solde vide', () {
      final b = parseAddressStats('bc1test', {
        'chain_stats': {
          'funded_txo_sum': 0,
          'spent_txo_sum': 0,
          'tx_count': 0,
        },
      });
      expect(b.isEmpty, isTrue);
      expect(b.totalSats, 0);
    });

    test('une reponse incomplete ne fait pas planter', () {
      final b = parseAddressStats('bc1test', {'chain_stats': 'inattendu'});
      expect(b.totalSats, 0);
      expect(b.isEmpty, isTrue);
    });
  });

  group('Conservation hors ligne', () {
    test('encodage et decodage conservent les valeurs', () {
      final b = WalletBalance(
        address: 'bc1test',
        confirmedSats: 12345,
        pendingSats: 678,
        transactionCount: 3,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final back = WalletBalance.tryDecode(b.encode());
      expect(back, isNotNull);
      expect(back!.confirmedSats, 12345);
      expect(back.pendingSats, 678);
      expect(back.address, 'bc1test');
    });

    test('un contenu invalide est ignore', () {
      expect(WalletBalance.tryDecode('n importe quoi'), isNull);
      expect(WalletBalance.tryDecode(null), isNull);
    });
  });
}
