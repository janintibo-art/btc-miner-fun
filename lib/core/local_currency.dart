import 'dart:convert';

/// Un compte dans une monnaie locale.
///
/// Il n'y a ici ni cle privee, ni adresse, ni phrase de recuperation : juste
/// un nom et un solde. C'est tout l'interet du modele - et ce qui le rend
/// utilisable par une boulangere de soixante-dix ans.
class LocalAccount {
  const LocalAccount({
    required this.id,
    required this.name,
    required this.balance,
    this.kind = AccountKind.person,
  });

  final String id;
  final String name;
  final double balance;
  final AccountKind kind;

  LocalAccount copyWith({double? balance, String? name}) => LocalAccount(
        id: id,
        name: name ?? this.name,
        balance: balance ?? this.balance,
        kind: kind,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'n': name, 'b': balance, 'k': kind.index};

  factory LocalAccount.fromJson(Map<String, dynamic> j) => LocalAccount(
        id: j['id'] as String,
        name: j['n'] as String,
        balance: (j['b'] as num).toDouble(),
        kind: AccountKind.values[(j['k'] as int?) ?? 0],
      );
}

enum AccountKind {
  person('Habitant'),
  business('Commerce'),
  authority('Collectivite');

  const AccountKind(this.label);
  final String label;
}

/// Un mouvement inscrit au registre.
class LocalTransfer {
  const LocalTransfer({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.label,
    required this.at,
    this.cancelled = false,
  });

  /// Vide pour une emission : la collectivite cree les unites.
  final String from;
  final String to;
  final String id;
  final double amount;
  final String label;
  final DateTime at;

  /// Un registre tenu par une autorite peut corriger une erreur. Une chaine
  /// de blocs, non. C'est la difference la plus concrete entre les deux.
  final bool cancelled;

  bool get isIssuance => from.isEmpty;

  LocalTransfer cancel() => LocalTransfer(
        id: id,
        from: from,
        to: to,
        amount: amount,
        label: label,
        at: at,
        cancelled: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'f': from,
        't': to,
        'a': amount,
        'l': label,
        'd': at.millisecondsSinceEpoch,
        'c': cancelled,
      };

  factory LocalTransfer.fromJson(Map<String, dynamic> j) => LocalTransfer(
        id: j['id'] as String,
        from: j['f'] as String,
        to: j['t'] as String,
        amount: (j['a'] as num).toDouble(),
        label: j['l'] as String? ?? '',
        at: DateTime.fromMillisecondsSinceEpoch(j['d'] as int),
        cancelled: j['c'] as bool? ?? false,
      );
}

/// Le registre complet : des comptes, des mouvements, une autorite.
///
/// C'est le modele des monnaies locales existantes, et il tient en deux
/// cents lignes la ou une chaine de blocs en demande dix fois plus. La
/// difference n'est pas technique : une monnaie locale a une collectivite qui
/// en repond, et n'a donc aucun besoin de s'en passer.
class LocalLedger {
  LocalLedger({
    this.name = 'Monnaie locale',
    this.symbol = 'MLC',
    List<LocalAccount>? accounts,
    List<LocalTransfer>? transfers,
  })  : accounts = accounts ?? <LocalAccount>[],
        transfers = transfers ?? <LocalTransfer>[];

  String name;
  String symbol;
  final List<LocalAccount> accounts;
  final List<LocalTransfer> transfers;

  double get inCirculation =>
      accounts.fold(0.0, (sum, compte) => sum + compte.balance);

  LocalAccount? byId(String id) {
    for (final compte in accounts) {
      if (compte.id == id) return compte;
    }
    return null;
  }

  void _setBalance(String id, double delta) {
    for (var i = 0; i < accounts.length; i++) {
      if (accounts[i].id == id) {
        accounts[i] = accounts[i].copyWith(balance: accounts[i].balance + delta);
        return;
      }
    }
  }

  /// Emission par la collectivite : c'est le seul endroit ou des unites
  /// apparaissent. L'equivalent du minage, en une ligne.
  String issue(String toId, double amount, String label) {
    if (amount <= 0) return 'Le montant doit etre positif.';
    if (byId(toId) == null) return 'Compte inconnu.';
    _setBalance(toId, amount);
    transfers.insert(
      0,
      LocalTransfer(
        id: _nextId(),
        from: '',
        to: toId,
        amount: amount,
        label: label.isEmpty ? 'Emission' : label,
        at: DateTime.now(),
      ),
    );
    return '';
  }

  /// Un paiement. Instantane, sans frais, et annulable.
  String transfer(String fromId, String toId, double amount, String label) {
    if (amount <= 0) return 'Le montant doit etre positif.';
    if (fromId == toId) return 'Emetteur et destinataire identiques.';
    final source = byId(fromId);
    if (source == null || byId(toId) == null) return 'Compte inconnu.';
    if (source.balance < amount) {
      return 'Solde insuffisant : ${source.name} n\'a que '
          '${source.balance.toStringAsFixed(2)} $symbol.';
    }
    _setBalance(fromId, -amount);
    _setBalance(toId, amount);
    transfers.insert(
      0,
      LocalTransfer(
        id: _nextId(),
        from: fromId,
        to: toId,
        amount: amount,
        label: label,
        at: DateTime.now(),
      ),
    );
    return '';
  }

  /// Annulation : impossible sur une chaine de blocs, banale ici.
  String cancel(String transferId) {
    for (var i = 0; i < transfers.length; i++) {
      final mouvement = transfers[i];
      if (mouvement.id != transferId) continue;
      if (mouvement.cancelled) return 'Deja annule.';
      if (mouvement.isIssuance) {
        final beneficiaire = byId(mouvement.to);
        if (beneficiaire == null) return 'Compte introuvable.';
        if (beneficiaire.balance < mouvement.amount) {
          return 'Les unites emises ont deja circule : annulation impossible.';
        }
        _setBalance(mouvement.to, -mouvement.amount);
      } else {
        final destinataire = byId(mouvement.to);
        if (destinataire == null) return 'Compte introuvable.';
        if (destinataire.balance < mouvement.amount) {
          return 'Le destinataire a deja depense la somme.';
        }
        _setBalance(mouvement.to, -mouvement.amount);
        _setBalance(mouvement.from, mouvement.amount);
      }
      transfers[i] = mouvement.cancel();
      return '';
    }
    return 'Mouvement introuvable.';
  }

  String addAccount(String name, AccountKind kind) {
    if (name.trim().isEmpty) return 'Le nom ne peut pas etre vide.';
    accounts.add(LocalAccount(
      id: _nextId(),
      name: name.trim(),
      balance: 0,
      kind: kind,
    ));
    return '';
  }

  int _compteur = 0;
  String _nextId() =>
      '${DateTime.now().millisecondsSinceEpoch}-${_compteur++}';

  String encode() => jsonEncode({
        'name': name,
        'symbol': symbol,
        'accounts': accounts.map((c) => c.toJson()).toList(),
        'transfers': transfers.map((t) => t.toJson()).toList(),
      });

  static LocalLedger? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return LocalLedger(
        name: data['name'] as String? ?? 'Monnaie locale',
        symbol: data['symbol'] as String? ?? 'MLC',
        accounts: (data['accounts'] as List)
            .map((c) => LocalAccount.fromJson(c as Map<String, dynamic>))
            .toList(),
        transfers: (data['transfers'] as List)
            .map((t) => LocalTransfer.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Un registre de demonstration, pour voir le mecanisme sans rien saisir.
  factory LocalLedger.demonstration() {
    final registre = LocalLedger(name: 'Monnaie du village', symbol: 'MLV');
    registre.accounts.addAll(const [
      LocalAccount(
          id: 'mairie', name: 'Mairie', balance: 0, kind: AccountKind.authority),
      LocalAccount(id: 'boulangerie', name: 'Boulangerie', balance: 0,
          kind: AccountKind.business),
      LocalAccount(id: 'ferme', name: 'Ferme du coteau', balance: 0,
          kind: AccountKind.business),
      LocalAccount(id: 'habitant1', name: 'Toi', balance: 0),
      LocalAccount(id: 'habitant2', name: 'Ta voisine', balance: 0),
    ]);
    registre.issue('habitant1', 50, 'Dotation de lancement');
    registre.issue('habitant2', 50, 'Dotation de lancement');
    registre.transfer('habitant1', 'boulangerie', 4.5, 'Deux baguettes');
    registre.transfer('habitant2', 'ferme', 12, 'Panier de legumes');
    return registre;
  }
}
