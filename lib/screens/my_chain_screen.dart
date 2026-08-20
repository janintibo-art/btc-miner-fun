import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/my_chain.dart';
import '../state/chain_controller.dart';
import '../widgets/app_card.dart';

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
  int _difficultyLevel = 2;

  @override
  void dispose() {
    _name.dispose();
    _symbol.dispose();
    _genesis.dispose();
    _message.dispose();
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
                decoration: const InputDecoration(
                  labelText: 'Message du bloc de genese',
                  helperText: 'Grave a jamais dans le premier bloc. Celui de '
                      'Bitcoin citait un titre de journal du 3 janvier 2009.',
                  helperMaxLines: 3,
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
                      '${formatBtc(chain.rules.rewardAt(chain.height))}'),
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
        const SizedBox(height: 20),
        SectionLabel('Les blocs (${chain.height})'),
        ...chain.blocks.reversed.take(30).map((block) => _BlockTile(
              block: block,
              rules: chain.rules,
            )),
        const SizedBox(height: 16),
        TextButton(
          onPressed: c.mining ? null : () => _confirmDestroy(c),
          child: const Text('Supprimer cette chaine',
              style: TextStyle(color: AppColors.coral, fontSize: 12)),
        ),
      ],
    );
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
  const _BlockTile({required this.block, required this.rules});

  final MyBlock block;
  final ChainRules rules;

  @override
  Widget build(BuildContext context) {
    final d = block.dateTime;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            Text(
              'nonce ${block.nonce} - ${formatCount(block.hashesTried)} '
              'tentatives - ${formatBtc(block.reward)} ${rules.symbol}',
              style: mono(size: 10, color: AppColors.dim),
            ),
          ],
        ),
      ),
    );
  }
}
