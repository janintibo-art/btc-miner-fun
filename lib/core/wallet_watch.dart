import 'dart:convert';

import 'price_service.dart';

/// Le solde d'une adresse, en lecture seule.
///
/// L'application n'a aucune cle privee : elle demande simplement a un
/// explorateur public ce que la chaine dit de ton adresse. C'est de la
/// consultation, comme regarder un relevé sans pouvoir signer de cheque.
class WalletBalance {
  const WalletBalance({
    required this.address,
    required this.confirmedSats,
    required this.pendingSats,
    required this.transactionCount,
    required this.fetchedAt,
  });

  final String address;

  /// Solde inscrit dans des blocs, en satoshis.
  final int confirmedSats;

  /// Mouvements vus par le reseau mais pas encore inscrits dans un bloc.
  final int pendingSats;

  final int transactionCount;
  final DateTime fetchedAt;

  int get totalSats => confirmedSats + pendingSats;
  double get totalBtc => totalSats / 100000000;
  double get confirmedBtc => confirmedSats / 100000000;
  bool get isEmpty => totalSats == 0 && transactionCount == 0;

  Map<String, dynamic> toJson() => {
        'a': address,
        'c': confirmedSats,
        'p': pendingSats,
        'n': transactionCount,
        't': fetchedAt.millisecondsSinceEpoch,
      };

  factory WalletBalance.fromJson(Map<String, dynamic> j) => WalletBalance(
        address: j['a'] as String,
        confirmedSats: j['c'] as int,
        pendingSats: j['p'] as int,
        transactionCount: j['n'] as int,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
      );

  String encode() => jsonEncode(toJson());

  static WalletBalance? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return WalletBalance.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Transforme la reponse de l'explorateur en solde exploitable.
///
/// L'API ne renvoie pas un solde tout fait : elle donne le total recu et le
/// total depense, aussi bien pour les blocs que pour les transactions encore
/// en attente. Le solde est la difference des deux.
WalletBalance parseAddressStats(String address, Map<String, dynamic> json) {
  int sum(String section, String field) {
    final part = json[section];
    if (part is! Map) return 0;
    final value = part[field];
    return value is num ? value.toInt() : 0;
  }

  final confirmed =
      sum('chain_stats', 'funded_txo_sum') - sum('chain_stats', 'spent_txo_sum');
  final pending = sum('mempool_stats', 'funded_txo_sum') -
      sum('mempool_stats', 'spent_txo_sum');
  final count =
      sum('chain_stats', 'tx_count') + sum('mempool_stats', 'tx_count');

  return WalletBalance(
    address: address,
    confirmedSats: confirmed,
    pendingSats: pending,
    transactionCount: count,
    fetchedAt: DateTime.now(),
  );
}

class WalletWatch {
  /// Interroge un explorateur public. Aucune donnee n'est envoyee : l'adresse
  /// fait partie de l'URL, et elle est deja publique par nature.
  static Future<WalletBalance> fetch(String address) async {
    final json = await fetchJson('https://mempool.space/api/address/$address');
    if (json is! Map<String, dynamic>) {
      throw const FormatException('reponse inattendue de l\'explorateur');
    }
    return parseAddressStats(address, json);
  }
}
