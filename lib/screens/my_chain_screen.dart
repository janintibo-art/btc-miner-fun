import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/miner_ranking.dart';
import '../core/my_chain.dart';
import '../core/session_export.dart';
import '../core/wallet_vault.dart';
import '../state/chain_controller.dart';
import '../widgets/app_card.dart';
import 'certificate_screen.dart';

/// Ta monnaie : une chaine complete, avec de vrais blocs et de vraies preuves
/// de travail. Tout est reel sauf le reseau.
class MyChainScreen extends StatefulWidget {
  const MyChainScreen({super.key});

  @override
  State<MyChainScreen> createState() => _MyChainScreenState();
}

class _MyChainScreenState extends State<MyChainScreen> {
  final _name = TextEditingController(text: 'Tibo');
  final _symbol = TextEditingController(text: 'TIBO');
  final _genesis = TextEditingController(text: 'Le premier bloc de ma monnaie');
  final _message = TextEditingController(text: 'Mine par moi');
  final _serveur = TextEditingController();
  final _destinataire = TextEditingController();
  final _montant = TextEditingController();
  final _noteVirement = TextEditingController();
  bool _serveurCharge = false;
  String _messageVirement = '';
  int _difficultyLevel = 2;

  @override
  void dispose() {
    _name.dispose();
    _symbol.dispose();
    _genesis.dispose();
    _message.dispose();
    _serveur.dispose();
    _destinataire.dispose();
    _montant.dispose();
    _noteVirement.dispose();
    super.dispose();
  }

  /// Trois niveaux, du plus facile au plus lent. Les valeurs correspondent a
  /// l'exposant du format compact : chaque cran divise la cible par 256.
  static const _levels = <({String label, int bits, String note})>[
    (label: 'Immediat', bits: 0x2000ffff, note: 'quelques milliers de tentatives'),
    (label: 'Rapide', bits: 0x1f00ffff, note: 'quelques centaines de milliers'),
    (label: 'Serieux', bits: 0x1e00ffff, note: 'quelques dizaines de millions'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ChainController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.abyss,
        elevation: 0,
        title: Text(c.exists ? c.chain!.rules.name : 'Creer ma monnaie',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: c.exists ? _chainView(c) : _creationView(c),
      ),
    );
  }

  // -------------------------------------------------------------------------

  Widget _creationView(ChainController c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        AppCard(
          accent: AppColors.violet.withOpacity(.4),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Une vraie chaine, sans le reseau',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text(
                'En-tetes de 80 octets au format exact de Bitcoin, preuve de '
                'travail en double SHA-256, difficulte encodee en format '
                'compact et reajustee automatiquement, chainage verifie bloc '
                'par bloc. Le mecanisme est identique a la lettre.\n\n'
                'Ce qui manque, c\'est tout le reste : personne d\'autre ne '
                'valide tes blocs, personne ne les echange, personne ne les '
                'accepte en paiement. C\'est precisement ce qui donne sa valeur '
                'a une monnaie, et c\'est pour cela que la tienne en aura '
                'exactement zero. Ce n\'est pas une limite technique : c\'est la '
                'lecon.',
                style: TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Rejoindre une chaine existante'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Si une chaine tourne deja sur un serveur - la tienne apres une '
                'reinstallation, ou celle de quelqu\'un d\'autre - rejoins-la '
                'plutot que d\'en creer une nouvelle. La genese doit etre '
                'commune : deux chaines nees separement ne peuvent pas '
                'fusionner, et le serveur refusera les blocs de l\'intruse.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.5, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _serveur,
                style: mono(size: 12),
                decoration: const InputDecoration(
                  labelText: 'Adresse du serveur',
                  hintText: 'https://mon-serveur.onrender.com',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: c.syncing
                      ? null
                      : () async {
                          final ok = await c.joinFromServer(_serveur.text);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Chaine rejointe.'
                                  : 'Aucune chaine trouvee sur ce serveur.'),
                            ),
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: c.syncing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Rejoindre cette chaine',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Ou en creer une nouvelle'),
        const SizedBox(height: 4),
        const SectionLabel('Identite'),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _symbol,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Symbole'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _genesis,
                maxLines: 6,
                minLines: 2,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Message du bloc de genese',
                  helperText: 'Grave a jamais dans le premier bloc, et engage '
                      'dans sa preuve de travail. Celui de Bitcoin citait un '
                      'titre de journal du 3 janvier 2009. Plusieurs milliers '
                      'de caracteres sont acceptes, toutes ecritures '
                      'comprises.',
                  helperMaxLines: 5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Difficulte de depart'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _levels.length; i++)
                InkWell(
                  onTap: () => setState(() => _difficultyLevel = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(
                          _difficultyLevel == i
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 20,
                          color: _difficultyLevel == i
                              ? AppColors.amber
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_levels[i].label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _difficultyLevel == i
                                    ? AppColors.ink
                                    : AppColors.muted,
                              )),
                        ),
                        Text(_levels[i].note,
                            style: mono(size: 10.5, color: AppColors.dim)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'La difficulte se reajuste ensuite toute seule, tous les dix '
                'blocs, pour viser un bloc toutes les trente secondes. '
                'Exactement le mecanisme de Bitcoin, avec des reglages a '
                'l\'echelle d\'un telephone.',
                style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => c.create(ChainRules(
            name: _name.text.trim().isEmpty ? 'Tibo' : _name.text.trim(),
            symbol: _symbol.text.trim().isEmpty
                ? 'TIBO'
                : _symbol.text.trim().toUpperCase(),
            genesisMessage: _genesis.text.trim().isEmpty
                ? 'Le premier bloc de ma monnaie'
                : _genesis.text.trim(),
            genesisBits: _levels[_difficultyLevel].bits,
          )),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.amber,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Creer le bloc de genese',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------

  Widget _chainView(ChainController c) {
    if (!_serveurCharge) {
      _serveur.text = c.serverUrl;
      _serveurCharge = true;
    }
    final chain = c.chain!;
    final tip = chain.tip!;
    final difficulty = difficultyFromBits(tip.bits, chain.rules.genesisBits);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        AppCard(
          accent: AppColors.amber.withOpacity(.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TON SOLDE', style: label()),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatBtc(chain.balance),
                      style: mono(size: 34, weight: FontWeight.w800, spacing: -1)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(chain.rules.symbol,
                        style: mono(size: 15, color: AppColors.amber)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('soit 0,00 € - et ce sera toujours le cas',
                  style: mono(size: 11, color: AppColors.dim)),
              const Divider(height: 26),
              Row(
                children: [
                  _Stat('Blocs', '${chain.height}'),
                  _Stat('Difficulte', difficulty.toStringAsFixed(2)),
                  _Stat('Recompense',
                      formatBtc(chain.rules.rewardAt(chain.height))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _message,
                enabled: !c.mining,
                style: mono(size: 13),
                decoration: const InputDecoration(
                  labelText: 'Message a inscrire dans les blocs',
                ),
              ),
              const SizedBox(height: 14),
              if (c.mining) ...[
                Text('${formatHashrate(c.hashrate)} - '
                    '${formatCount(c.hashesOnCurrentBlock)} tentatives sur le '
                    'bloc ${chain.height}',
                    style: mono(size: 12, color: AppColors.mint)),
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: AppColors.panelHigh,
                  valueColor: AlwaysStoppedAnimation(AppColors.amber),
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      c.mining ? c.stop() : c.mine(_message.text.trim()),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        c.mining ? AppColors.panelHigh : AppColors.amber,
                    foregroundColor: c.mining ? AppColors.ink : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: Icon(c.mining
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded),
                  label: Text(c.mining ? 'Arreter' : 'Miner ma monnaie',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14.5)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('VERIFICATION', style: label())),
                  TextButton(
                    onPressed: c.mining ? null : c.verify,
                    child: const Text('Verifier',
                        style: TextStyle(color: AppColors.cyan, fontSize: 12)),
                  ),
                ],
              ),
              Text(
                c.lastVerdict == null
                    ? 'Chaque bloc peut etre reverifie : chainage, horodatage, '
                        'et preuve de travail reelle.'
                    : (c.lastVerdict!.valid
                        ? '${c.lastVerdict!.checked} blocs conformes.'
                        : 'Invalide : ${c.lastVerdict!.problem}'),
                style: mono(
                  size: 11.5,
                  color: c.lastVerdict == null
                      ? AppColors.muted
                      : (c.lastVerdict!.valid ? AppColors.mint : AppColors.coral),
                ),
              ),
            ],
          ),
        ),
        if (c.log.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JOURNAL', style: label()),
                const SizedBox(height: 8),
                ...c.log.take(6).map((ligne) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(ligne,
                          style: mono(size: 10.5, color: AppColors.muted)),
                    )),
              ],
            ),
          ),
        ],
        if (chain.height > 1) ...[
          const SizedBox(height: 20),
          const SectionLabel('Championnat des mineurs'),
          _Championnat(chain: chain),
        ],
        const SizedBox(height: 20),
        SectionLabel('Les blocs (${chain.height})'),
        ...chain.blocks.reversed.take(30).map((block) => _BlockTile(
              block: block,
              rules: chain.rules,
              onTap: block.height == 0
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CertificateScreen(
                            block: block,
                            rules: chain.rules,
                          ),
                        ),
                      ),
            )),
        const SizedBox(height: 16),
        _CarteVirements(
          destinataire: _destinataire,
          montant: _montant,
          note: _noteVirement,
          message: _messageVirement,
          onEnvoyer: (message) => setState(() => _messageVirement = message),
        ),
        const SizedBox(height: 16),
        AppCard(
          accent: c.isShared ? AppColors.mint.withOpacity(.35) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CHAINE PARTAGEE', style: label()),
              const SizedBox(height: 8),
              const Text(
                'Avec un serveur, plusieurs personnes minent la meme chaine et '
                'se disputent chaque bloc. Le serveur ne mine pas : il verifie '
                'la preuve de travail, impose la difficulte et la recompense, '
                'et garde la chaine qui totalise le plus de travail.',
                style: TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _serveur,
                enabled: !c.mining,
                style: mono(size: 12),
                decoration: const InputDecoration(
                  labelText: 'Adresse du serveur',
                  hintText: 'https://mon-serveur.onrender.com',
                  helperText: 'Laisse vide pour garder la chaine sur cet '
                      'appareil uniquement.',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: c.mining
                          ? null
                          : () => c.setServerUrl(_serveur.text),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Enregistrer'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: !c.isShared || c.mining || c.syncing
                          ? null
                          : c.synchronise,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mint,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: c.syncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.sync_rounded, size: 17),
                      label: const Text('Synchroniser'),
                    ),
                  ),
                ],
              ),
              if (c.remoteHead != null) ...[
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  // Le texte est compose ici plutot que dans une interpolation
                  // imbriquee : plus lisible, et sans piege de guillemets.
                  final tete = c.remoteHead!.tip;
                  final resume = tete == null
                      ? 'chaine vide'
                      : 'tete ${tete.substring(0, 16)}...';
                  return Text(
                    'Serveur : ${c.remoteHead!.height} bloc(s) - $resume',
                    style: mono(size: 11, color: AppColors.mint),
                  );
                }),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SAUVEGARDE', style: label()),
              const SizedBox(height: 8),
              Text(
                c.isShared
                    ? 'La page web lit desormais le serveur en direct : tu n\'as '
                        'plus rien a publier. Cet export ne sert qu\'a garder '
                        'une copie de secours de la chaine.'
                    : 'Exporte la chaine pour en garder une copie, ou pour la '
                        'deposer dans le dossier site du depot sous le nom '
                        'chain.json si tu n\'utilises pas de serveur.',
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: c.mining ? null : () => _exportChain(c),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyan,
                    side: const BorderSide(color: AppColors.line),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 17),
                  label: const Text('Exporter une copie'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: c.mining ? null : () => _confirmDestroy(c),
          child: const Text('Supprimer cette chaine',
              style: TextStyle(color: AppColors.coral, fontSize: 12)),
        ),
      ],
    );
  }

  /// Le fichier attendu par la page web est exactement celui que la chaine
  /// sait deja produire : aucun format intermediaire a maintenir.
  Future<void> _exportChain(ChainController c) async {
    final chain = c.chain;
    if (chain == null) return;

    // Le hash de chaque bloc est ajoute au passage : la page l'affiche sans
    // avoir a reimplementer le double SHA-256 en JavaScript.
    final avecHash = _withHashes(chain);

    final chemin = await SessionExport.writeToDisk(avecHash);
    if (!mounted) return;
    if (chemin != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fichier ecrit : $chemin')),
      );
    } else {
      await Clipboard.setData(ClipboardData(text: avecHash));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('chain.json copie : colle-le dans site/chain.json')),
      );
    }
  }

  String _withHashes(MyChain chain) {
    final blocs = chain.blocks
        .map((b) => {...b.toJson(), 'hash': b.hash})
        .toList();
    return const JsonEncoder.withIndent('  ').convert({
      'rules': chain.rules.toJson(),
      'blocks': blocs,
    });
  }

  void _confirmDestroy(ChainController c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Supprimer la chaine ?'),
        content: const Text(
            'Tous les blocs mines seront perdus. Contrairement a une vraie '
            'chaine, celle-ci n\'existe nulle part ailleurs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              c.destroy();
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer',
                style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.title, this.value);
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: label()),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: mono(size: 15, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.block, required this.rules, this.onTap});

  final MyBlock block;
  final ChainRules rules;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = block.dateTime;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: InkWell(
          onTap: onTap,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${block.height}',
                    style: mono(
                        size: 12.5,
                        weight: FontWeight.w800,
                        color: block.height == 0
                            ? AppColors.violet
                            : AppColors.amber)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    block.height == 0 ? 'Bloc de genese' : block.message,
                    style: const TextStyle(fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                    '${d.hour.toString().padLeft(2, '0')}:'
                    '${d.minute.toString().padLeft(2, '0')}:'
                    '${d.second.toString().padLeft(2, '0')}',
                    style: mono(size: 10.5, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 7),
            Text(block.hash,
                style: mono(size: 9.5, color: AppColors.mint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'nonce ${block.nonce} - '
                    '${formatCount(block.hashesTried)} tentatives - '
                    '${formatBtc(block.reward)} ${rules.symbol}',
                    style: mono(size: 10, color: AppColors.dim),
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.workspace_premium_outlined,
                      size: 15, color: AppColors.amber),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// Le palmares de la chaine : qui a trouve le plus de blocs, et qui a eu le
/// plus de chance.
class _Championnat extends StatelessWidget {
  const _Championnat({required this.chain});

  final MyChain chain;

  @override
  Widget build(BuildContext context) {
    final scores = rankMiners(chain);
    final chanceux = luckiestBlock(chain);
    if (scores.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Le nom du mineur est le message qu\'il grave dans ses blocs. '
            'C\'est le seul champ que la preuve de travail engage, donc le seul '
            'qui ne puisse pas etre change apres coup.',
            style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          ...scores.take(8).toList().asMap().entries.map((entree) {
            final rang = entree.key + 1;
            final score = entree.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('$rang',
                        style: mono(
                          size: 13,
                          weight: FontWeight.w800,
                          color: rang == 1 ? AppColors.amber : AppColors.dim,
                        )),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(score.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  rang == 1 ? FontWeight.w800 : FontWeight.w600,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          '${formatCount(score.averageAttempts.round())} '
                          'tentatives en moyenne - meilleur coup au bloc '
                          '${score.bestBlock} en '
                          '${formatCount(score.bestAttempts)}',
                          style: mono(size: 10, color: AppColors.dim),
                        ),
                      ],
                    ),
                  ),
                  Text('${score.blocks} bloc(s)',
                      style: mono(size: 11.5, weight: FontWeight.w700)),
                ],
              ),
            );
          }),
          if (chanceux != null) ...[
            const Divider(height: 22),
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: AppColors.mint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Coup de chance de la chaine : bloc ${chanceux.height}, '
                    'trouve en ${formatCount(chanceux.hashesTried)} tentatives.',
                    style: mono(size: 11, color: AppColors.mint),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Envoyer et recevoir des Tibo.
///
/// L'adresse est derivee de la phrase du portefeuille : la meme phrase
/// redonne toujours la meme adresse, sur n'importe quel appareil. Il n'y a
/// donc rien de plus a sauvegarder que ce qui l'est deja.
class _CarteVirements extends StatefulWidget {
  const _CarteVirements({
    required this.destinataire,
    required this.montant,
    required this.note,
    required this.message,
    required this.onEnvoyer,
  });

  final TextEditingController destinataire;
  final TextEditingController montant;
  final TextEditingController note;
  final String message;
  final ValueChanged<String> onEnvoyer;

  @override
  State<_CarteVirements> createState() => _CarteVirementsState();
}

class _CarteVirementsState extends State<_CarteVirements> {
  static const _coffre = WalletVault();
  bool _envoi = false;
  bool _derivation = false;

  /// Lit la phrase dans le coffre chiffre, le temps de deriver l'adresse.
  ///
  /// La phrase n'est jamais conservee : elle sert une fois, puis la reference
  /// est abandonnee.
  Future<void> _deriver(ChainController c) async {
    setState(() => _derivation = true);
    final phrase = await _coffre.revealMnemonic();
    if (!mounted) return;
    setState(() => _derivation = false);
    if (phrase == null || phrase.isEmpty) {
      widget.onEnvoyer('Aucun portefeuille : cree-le dans l\'onglet dedie.');
      return;
    }
    c.unlockIdentity(phrase);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ChainController>();
    final identite = c.identity;

    return AppCard(
      accent: AppColors.cyan.withOpacity(.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TES TIBO', style: label()),
          const SizedBox(height: 10),
          if (identite == null) ...[
            const Text(
              'Pour recevoir des Tibo, il faut une adresse. Elle se derive de '
              'la phrase de recuperation de ton portefeuille : la meme phrase '
              'redonne toujours la meme adresse, sur n\'importe quel appareil. '
              'Rien de plus a sauvegarder.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.5, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _derivation ? null : () => _deriver(c),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: _derivation
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.key_rounded, size: 18),
                label: Text(_derivation
                    ? 'Derivation...'
                    : 'Deriver mon adresse Tibo'),
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(c.balanceOf(identite.address).toStringAsFixed(2),
                    style:
                        mono(size: 26, weight: FontWeight.w800, spacing: -1)),
                const SizedBox(width: 7),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('TIBO recus',
                      style: mono(size: 11, color: AppColors.cyan)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('TON ADRESSE', style: label()),
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: identite.address));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Adresse copiee')),
                );
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(identite.address,
                        style: mono(size: 11, color: AppColors.mint)),
                  ),
                  const Icon(Icons.copy_rounded,
                      size: 15, color: AppColors.muted),
                ],
              ),
            ),
            const Divider(height: 26),
            Text('ENVOYER', style: label()),
            const SizedBox(height: 10),
            TextField(
              controller: widget.destinataire,
              style: mono(size: 11.5),
              decoration: const InputDecoration(
                labelText: 'Adresse du destinataire',
                hintText: 'T...',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.montant,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: mono(size: 13),
                    decoration: const InputDecoration(
                        labelText: 'Montant', suffixText: 'TIBO'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: widget.note,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _envoi || c.mining
                    ? null
                    : () async {
                        setState(() => _envoi = true);
                        final montant = double.tryParse(
                                widget.montant.text.replaceAll(',', '.')) ??
                            0;
                        final erreur = await c.send(
                          widget.destinataire.text.trim(),
                          montant,
                          widget.note.text.trim(),
                        );
                        if (!mounted) return;
                        setState(() => _envoi = false);
                        widget.onEnvoyer(erreur.isEmpty
                            ? 'Virement depose : il partira dans le prochain '
                                'bloc mine.'
                            : erreur);
                        if (erreur.isEmpty) {
                          widget.montant.clear();
                          widget.note.clear();
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: _envoi
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.send_rounded, size: 17),
                label: Text(_envoi ? 'Envoi...' : 'Signer et envoyer'),
              ),
            ),
            if (widget.message.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(widget.message,
                  style: mono(
                    size: 11,
                    color: widget.message.startsWith('Virement depose')
                        ? AppColors.mint
                        : AppColors.coral,
                  )),
            ],
            const SizedBox(height: 10),
            Text(
              'Le virement est signe ici avec ta cle privee, qui ne quitte '
              'jamais l\'appareil. Le serveur verifie la signature, puis un '
              'mineur l\'inscrit dans un bloc - c\'est a ce moment qu\'il '
              'devient definitif.',
              style: mono(size: 10, color: AppColors.dim),
            ),
          ],
        ],
      ),
    );
  }
}
