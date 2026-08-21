import 'dart:convert';

/// Un virement de Tibo, signe par son emetteur.
///
/// Le modele est volontairement plus simple que celui de Bitcoin : des soldes
/// plutot que des entrees et sorties. C'est le fonctionnement d'Ethereum, et
/// il se raconte en une phrase - « de A vers B, tel montant » - la ou les UTXO
/// demandent un chapitre entier.
class TiboTx {
  const TiboTx({
    required this.from,
    required this.to,
    required this.amount,
    required this.sequence,
    required this.publicKey,
    required this.signature,
    this.note = '',
  });

  final String from;
  final String to;
  final double amount;

  /// Numero d'ordre de l'emetteur, croissant.
  ///
  /// Sans lui, quiconque interceptant un virement pourrait le renvoyer dix
  /// fois : la signature resterait valable. C'est la meme protection que le
  /// nonce d'un compte Ethereum.
  final int sequence;

  final String publicKey;
  final String signature;
  final String note;

  /// Le texte exactement signe. Toute divergence, ne serait-ce qu'un espace,
  /// invalide la signature - c'est pourquoi il est construit ici et nulle
  /// part ailleurs.
  static String message({
    required String from,
    required String to,
    required double amount,
    required int sequence,
    required String note,
  }) =>
      'TIBO|$from|$to|${amount.toStringAsFixed(8)}|$sequence|$note';

  String get signedMessage => message(
        from: from,
        to: to,
        amount: amount,
        sequence: sequence,
        note: note,
      );

  /// Identifiant du virement : le hash de son contenu signe.
  String get id {
    final octets = utf8.encode('$signedMessage|$signature');
    var somme = 0;
    final tampon = StringBuffer();
    for (final octet in octets) {
      somme = (somme * 31 + octet) & 0xFFFFFFFF;
    }
    tampon.write(somme.toRadixString(16).padLeft(8, '0'));
    return tampon.toString();
  }

  Map<String, dynamic> toJson() => {
        'f': from,
        't': to,
        'a': amount,
        's': sequence,
        'p': publicKey,
        'g': signature,
        'n': note,
      };

  factory TiboTx.fromJson(Map<String, dynamic> j) => TiboTx(
        from: j['f'] as String,
        to: j['t'] as String,
        amount: (j['a'] as num).toDouble(),
        sequence: (j['s'] as num).toInt(),
        publicKey: j['p'] as String,
        signature: j['g'] as String,
        note: j['n'] as String? ?? '',
      );
}

/// Etat des comptes, reconstruit en rejouant la chaine.
///
/// Rien n'est stocke : les soldes se calculent depuis les blocs, exactement
/// comme le fait un noeud Bitcoin au demarrage. C'est plus lent, mais c'est
/// la seule facon d'etre sur que le solde affiche decoule des blocs et non
/// d'un compteur qu'on aurait pu oublier de mettre a jour.
class TiboState {
  final Map<String, double> balances = <String, double>{};
  final Map<String, int> sequences = <String, int>{};

  double balanceOf(String address) => balances[address] ?? 0;
  int nextSequence(String address) => (sequences[address] ?? 0) + 1;

  void credit(String address, double amount) {
    if (address.isEmpty) return;
    balances[address] = balanceOf(address) + amount;
  }

  /// Applique un virement. Renvoie une raison de refus, ou une chaine vide.
  String apply(TiboTx tx) {
    if (tx.amount <= 0) return 'montant nul ou negatif';
    if (tx.from == tx.to) return 'emetteur et destinataire identiques';
    if (balanceOf(tx.from) < tx.amount) return 'solde insuffisant';
    if (tx.sequence != nextSequence(tx.from)) {
      return 'numero d\'ordre attendu ${nextSequence(tx.from)}';
    }
    balances[tx.from] = balanceOf(tx.from) - tx.amount;
    credit(tx.to, tx.amount);
    sequences[tx.from] = tx.sequence;
    return '';
  }
}
