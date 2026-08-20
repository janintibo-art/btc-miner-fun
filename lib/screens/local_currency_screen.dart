import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/local_currency.dart';
import '../state/local_currency_controller.dart';
import '../widgets/app_card.dart';

/// L'autre modele : une monnaie locale tenue par une collectivite.
///
/// Cet ecran n'est pas un hors-sujet dans une application de minage. C'est le
/// contrepoint : il montre, en fonctionnant, ce qu'une chaine de blocs apporte
/// et ce qu'elle coute. Pour une monnaie de village, elle coute plus qu'elle
/// n'apporte.
class LocalCurrencyScreen extends StatefulWidget {
  const LocalCurrencyScreen({super.key});

  @override
  State<LocalCurrencyScreen> createState() => _LocalCurrencyScreenState();
}

class _LocalCurrencyScreenState extends State<LocalCurrencyScreen> {
  final _montant = TextEditingController();
  final _motif = TextEditingController();
  final _nouveauCompte = TextEditingController();
  String? _source;
  String? _destination;
  AccountKind _typeCompte = AccountKind.person;

  @override
  void dispose() {
    _montant.dispose();
    _motif.dispose();
    _nouveauCompte.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LocalCurrencyController>();

    return Scaffold(
      backgroundColor: AppColors.abyss,
      appBar: AppBar(
        backgroundColor: AppColors.abyss,
        elevation: 0,
        title: Text(c.exists ? c.ledger!.name : 'Monnaie locale',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: c.exists ? _registre(c) : _presentation(c),
      ),
    );
  }

  // -------------------------------------------------------------------------

  Widget _presentation(LocalCurrencyController c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        AppCard(
          accent: AppColors.mint.withOpacity(.4),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('L\'outil le plus adapte n\'est pas toujours le plus recent',
                  style:
                      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text(
                'Une chaine de blocs sert a se passer d\'un tiers de confiance. '
                'C\'est sa seule raison d\'etre, et c\'est ce qui justifie son '
                'cout : le minage, les cles privees, l\'irreversibilite.\n\n'
                'Dans une monnaie locale, la collectivite est ce tiers de '
                'confiance, et personne ne souhaite s\'en passer. Utiliser une '
                'chaine reviendrait a payer tres cher une propriete dont on ne '
                'veut pas - tout en heritant de ses inconvenients : une phrase '
                'de recuperation perdue, et l\'argent l\'est aussi.\n\n'
                'Ce registre fonctionne pour de vrai. Compare-le a ta chaine : '
                'meme usage, dix fois moins de code, et utilisable par '
                'n\'importe qui.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.55, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Ce qui existe deja'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Plus de quatre-vingts monnaies locales circulent en France, '
                'encadrees par la loi de 2014 sur l\'economie sociale et '
                'solidaire. Beaucoup ont une version numerique, et des '
                'communes y participent - certaines versent une part de leurs '
                'subventions dans la monnaie du territoire.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Text(
                'Avant d\'en construire une, regarde celles qui tournent depuis '
                'dix ans : elles ont deja rencontre les problemes que tu n\'as '
                'pas encore imagines.',
                style: mono(size: 11, color: AppColors.amber),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Les deux modeles, cote a cote'),
        const _Comparaison(),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: c.createDemonstration,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.mint,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.store_rounded),
          label: const Text('Ouvrir un registre de demonstration',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------

  Widget _registre(LocalCurrencyController c) {
    final registre = c.ledger!;
    _source ??= registre.accounts.first.id;
    _destination ??= registre.accounts.length > 1
        ? registre.accounts[1].id
        : registre.accounts.first.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        AppCard(
          accent: AppColors.mint.withOpacity(.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EN CIRCULATION', style: label()),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(registre.inCirculation.toStringAsFixed(2),
                      style: mono(
                          size: 32, weight: FontWeight.w800, spacing: -1)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(registre.symbol,
                        style: mono(size: 15, color: AppColors.mint)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Aucun minage : les unites sont emises par la collectivite, et '
                'circulent ensuite sans jamais se creer ni disparaitre.',
                style: mono(size: 10.5, color: AppColors.dim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Les comptes'),
        ...registre.accounts.map((compte) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                child: Row(
                  children: [
                    Icon(
                      switch (compte.kind) {
                        AccountKind.authority => Icons.account_balance_rounded,
                        AccountKind.business => Icons.storefront_rounded,
                        AccountKind.person => Icons.person_rounded,
                      },
                      size: 19,
                      color: compte.kind == AccountKind.authority
                          ? AppColors.amber
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(compte.name,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700)),
                          Text(compte.kind.label,
                              style: mono(size: 10, color: AppColors.dim)),
                        ],
                      ),
                    ),
                    Text(
                        '${compte.balance.toStringAsFixed(2)} '
                        '${registre.symbol}',
                        style: mono(size: 12.5, weight: FontWeight.w700)),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 8),
        const SectionLabel('Payer'),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Selecteur(
                      titre: 'De',
                      valeur: _source,
                      comptes: registre.accounts,
                      onChange: (v) => setState(() => _source = v),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 18, color: AppColors.muted),
                  ),
                  Expanded(
                    child: _Selecteur(
                      titre: 'Vers',
                      valeur: _destination,
                      comptes: registre.accounts,
                      onChange: (v) => setState(() => _destination = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _montant,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: mono(size: 14),
                      decoration: InputDecoration(
                          labelText: 'Montant', suffixText: registre.symbol),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _motif,
                      decoration: const InputDecoration(labelText: 'Motif'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final montant = double.tryParse(
                                _montant.text.replaceAll(',', '.')) ??
                            0;
                        c.transfer(_source!, _destination!, montant,
                            _motif.text.trim());
                        _montant.clear();
                        _motif.clear();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mint,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Payer',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final montant = double.tryParse(
                                _montant.text.replaceAll(',', '.')) ??
                            0;
                        c.issue(_destination!, montant, _motif.text.trim());
                        _montant.clear();
                        _motif.clear();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.amber,
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Emettre'),
                    ),
                  ),
                ],
              ),
              if (c.lastMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(c.lastMessage,
                    style: mono(size: 11.5, color: AppColors.coral)),
              ],
              const SizedBox(height: 10),
              Text(
                'Un paiement prend une milliseconde et ne coute rien. Aucune '
                'confirmation a attendre, aucun frais de reseau.',
                style: mono(size: 10, color: AppColors.dim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Ajouter un compte'),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nouveauCompte,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<AccountKind>(
                value: _typeCompte,
                dropdownColor: AppColors.panelHigh,
                underline: const SizedBox.shrink(),
                items: AccountKind.values
                    .map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(k.label,
                              style: const TextStyle(fontSize: 12.5)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _typeCompte = v!),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  c.addAccount(_nouveauCompte.text, _typeCompte);
                  _nouveauCompte.clear();
                },
                icon: const Icon(Icons.add_circle_rounded,
                    color: AppColors.mint),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionLabel('Le registre (${registre.transfers.length})'),
        ...registre.transfers.take(20).map((mouvement) {
          final de = mouvement.isIssuance
              ? 'Emission'
              : registre.byId(mouvement.from)?.name ?? '?';
          final vers = registre.byId(mouvement.to)?.name ?? '?';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$de  →  $vers',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              decoration: mouvement.cancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: mouvement.cancelled
                                  ? AppColors.dim
                                  : AppColors.ink,
                            )),
                        const SizedBox(height: 3),
                        Text(
                          mouvement.label.isEmpty
                              ? 'sans motif'
                              : mouvement.label,
                          style: mono(size: 10, color: AppColors.dim),
                        ),
                      ],
                    ),
                  ),
                  Text('${mouvement.amount.toStringAsFixed(2)}',
                      style: mono(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: mouvement.cancelled
                            ? AppColors.dim
                            : AppColors.mint,
                      )),
                  if (!mouvement.cancelled)
                    IconButton(
                      onPressed: () => c.cancel(mouvement.id),
                      icon: const Icon(Icons.undo_rounded,
                          size: 17, color: AppColors.muted),
                      tooltip: 'Annuler',
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        Text(
          'Le bouton d\'annulation est la difference la plus concrete avec ta '
          'chaine : ici, une erreur se corrige. Sur une chaine de blocs, jamais.',
          style: mono(size: 10.5, color: AppColors.amber),
        ),
        const SizedBox(height: 20),
        const _Comparaison(),
        const SizedBox(height: 16),
        TextButton(
          onPressed: c.destroy,
          child: const Text('Effacer ce registre',
              style: TextStyle(color: AppColors.coral, fontSize: 12)),
        ),
      ],
    );
  }
}

class _Selecteur extends StatelessWidget {
  const _Selecteur({
    required this.titre,
    required this.valeur,
    required this.comptes,
    required this.onChange,
  });

  final String titre;
  final String? valeur;
  final List<LocalAccount> comptes;
  final ValueChanged<String?> onChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre.toUpperCase(), style: label()),
        DropdownButton<String>(
          value: valeur,
          isExpanded: true,
          dropdownColor: AppColors.panelHigh,
          underline: Container(height: 1, color: AppColors.line),
          items: comptes
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name,
                        style: const TextStyle(fontSize: 12.5),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChange,
        ),
      ],
    );
  }
}

class _Comparaison extends StatelessWidget {
  const _Comparaison();

  static const _lignes = <(String, String, String)>[
    ('Qui garantit', 'Le calcul de milliers d\'inconnus', 'La collectivite'),
    ('Perdre son acces', 'Fonds perdus, sans recours', 'Mot de passe reinitialise'),
    ('Erreur de paiement', 'Definitive', 'Annulable'),
    ('Delai', 'Minutes a heures', 'Immediat'),
    ('Cout par paiement', 'Frais de reseau', 'Aucun'),
    ('Energie', 'Considerable', 'Celle d\'un site web'),
    ('Pour l\'utiliser', 'Comprendre les cles privees', 'Scanner un QR code'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox.shrink()),
              Expanded(
                flex: 4,
                child: Text('CHAINE DE BLOCS',
                    style: label(), textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 4,
                child: Text('REGISTRE LOCAL',
                    style: label(), textAlign: TextAlign.center),
              ),
            ],
          ),
          const Divider(height: 18),
          ..._lignes.map((ligne) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(ligne.$1,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(ligne.$2,
                          textAlign: TextAlign.center,
                          style: mono(size: 10, color: AppColors.amber)),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(ligne.$3,
                          textAlign: TextAlign.center,
                          style: mono(size: 10, color: AppColors.mint)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 6),
          const Text(
            'Aucune colonne n\'est meilleure : elles repondent a des questions '
            'differentes. Bitcoin existe pour envoyer de l\'argent a un inconnu '
            'a l\'autre bout du monde sans autorisation. Une monnaie locale '
            'existe pour que la boulangerie du village garde la valeur sur '
            'place.',
            style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
