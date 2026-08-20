import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/coin_stats.dart';
import '../core/coins.dart';
import '../core/mining_algorithm.dart';
import '../core/my_chain.dart';
import '../state/chain_controller.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/ranking_card.dart';
import 'local_currency_screen.dart';
import 'my_chain_screen.dart';

/// Le catalogue des monnaies : algorithme, difficulte reelle, et ce que cette
/// application peut ou ne peut pas en faire.
class CoinsScreen extends StatefulWidget {
  const CoinsScreen({super.key});

  @override
  State<CoinsScreen> createState() => _CoinsScreenState();
}

class _CoinsScreenState extends State<CoinsScreen> {
  String? _expanded;
  int _filter = 0; // 0 toutes, 1 minables ici, 2 autres algorithmes

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();
    final c = context.watch<ChainController>();

    // La chaine personnelle prend sa place parmi les autres, avec ses vrais
    // chiffres : ceux de l'appareil, pas d'un explorateur.
    final chaine = c.chain;
    final mienne = chaine == null || chaine.blocks.isEmpty
        ? null
        : personalCoin(
            name: chaine.rules.name,
            symbol: chaine.rules.symbol,
            blockMinutes: chaine.rules.targetSeconds / 60,
            reward: chaine.rules.rewardAt(chaine.height),
          );

    final coins = <Coin>[
      if (mienne != null && _filter != 2 && _filter != 3) mienne,
      ...kCoins.where((coin) {
        if (_filter == 1) return coin.isMinableHere;
        if (_filter == 2) return !coin.isMinableHere;
        if (_filter == 3) return coin.obscure;
        return true;
      }),
    ];

    // La reference de comparaison : la chaine la plus difficile du catalogue.
    var maxDifficulty = 0.0;
    for (final stats in m.coinStats.values) {
      if (stats.difficulty > maxDifficulty) maxDifficulty = stats.difficulty;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const RankingCard(),
        const SizedBox(height: 20),
        _DifficultyPrimer(m: m),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: SectionLabel('Catalogue (${coins.length})')),
            IconButton(
              onPressed: m.coinStatsLoading ? null : m.refreshCoinStats,
              icon: m.coinStatsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.cyan),
                    )
                  : const Icon(Icons.refresh_rounded,
                      size: 19, color: AppColors.cyan),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < 4; i++)
              ChoiceChip(
                selected: _filter == i,
                onSelected: (_) => setState(() => _filter = i),
                backgroundColor: AppColors.panelHigh,
                selectedColor: AppColors.amber,
                side: const BorderSide(color: AppColors.line),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _filter == i ? Colors.black : AppColors.muted,
                ),
                label: Text(
                    ['Toutes', 'Minables ici', 'Autres', 'Confidentielles'][i]),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const _MonnaieLocale(),
        const SizedBox(height: 10),
        if (mienne == null && _filter != 2 && _filter != 3) ...[
          const _CreerMaMonnaie(),
          const SizedBox(height: 10),
        ],
        ...coins.map((coin) => _CoinTile(
              coin: coin,
              stats: coin.personal && chaine != null
                  ? CoinStats(
                      symbol: coin.symbol,
                      difficulty: difficultyFromBits(
                          chaine.tip!.bits, chaine.rules.genesisBits),
                      hashrate: c.hashrate,
                      blocks: chaine.height,
                      priceUsd: 0,
                      fetchedAt: DateTime.now(),
                    )
                  : m.coinStats[coin.symbol],
              maxDifficulty: maxDifficulty,
              minerHashrate: m.referenceHashrate,
              expanded: _expanded == coin.symbol,
              onTap: () => setState(
                  () => _expanded = _expanded == coin.symbol ? null : coin.symbol),
            )),
      ],
    );
  }
}

class _DifficultyPrimer extends StatelessWidget {
  const _DifficultyPrimer({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.amber.withOpacity(.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LA DIFFICULTE, EN CLAIR', style: label()),
          const SizedBox(height: 10),
          const Text(
            'La difficulte repond a une seule question : combien de fois est-il '
            'plus dur de trouver un bloc ici que de resoudre le probleme de '
            'reference d\'origine ?\n\n'
            'Une difficulte de 1000 signifie qu\'il faut, en moyenne, mille '
            'fois plus de hachages. Elle se reajuste automatiquement : plus il '
            'y a de puissance sur une chaine, plus elle monte, pour que '
            'l\'intervalle entre deux blocs reste constant.\n\n'
            'Elle ne se compare donc pas d\'une monnaie a l\'autre comme une '
            'note de qualite : elle mesure la concurrence. Une chaine facile '
            'n\'est pas une chaine mal concue, c\'est une chaine ou peu de '
            'monde calcule.',
            style: TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _CoinTile extends StatelessWidget {
  const _CoinTile({
    required this.coin,
    required this.stats,
    required this.maxDifficulty,
    required this.minerHashrate,
    required this.expanded,
    required this.onTap,
  });

  final Coin coin;
  final CoinStats? stats;
  final double maxDifficulty;
  final double minerHashrate;
  final bool expanded;
  final VoidCallback onTap;

  Color get _supportColor => coin.personal
      ? AppColors.violet
      : switch (coin.support) {
        MiningSupport.supported => AppColors.mint,
        MiningSupport.wrongAlgorithm => AppColors.violet,
        MiningSupport.notMinable => AppColors.dim,
      };

  @override
  Widget build(BuildContext context) {
    final difficulty = stats?.difficulty ?? 0;
    final fraction = maxDifficulty <= 0 || difficulty <= 0
        ? 0.0
        : (logScale(difficulty) / logScale(maxDifficulty)).clamp(0.02, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        accent: expanded ? _supportColor.withOpacity(.45) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _supportColor.withOpacity(.14),
                          borderRadius: BorderRadius.circular(7),
                          border:
                              Border.all(color: _supportColor.withOpacity(.45)),
                        ),
                        child: Text(coin.symbol,
                            style: mono(
                                size: 11,
                                weight: FontWeight.w700,
                                color: _supportColor)),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(coin.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      if (coin.personal)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: Text('LA TIENNE',
                              style: mono(
                                  size: 9,
                                  weight: FontWeight.w800,
                                  color: AppColors.violet,
                                  spacing: 1)),
                        ),
                      if (coin.obscure)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: Icon(Icons.visibility_off_outlined,
                              size: 13, color: AppColors.dim),
                        ),
                      Text(coin.algorithm.label,
                          style: mono(size: 10.5, color: AppColors.muted)),
                      const SizedBox(width: 8),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (difficulty > 0) ...[
                    Row(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, c) => Stack(
                              children: [
                                Container(
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: AppColors.panelHigh,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Container(
                                  height: 7,
                                  width: c.maxWidth * fraction,
                                  decoration: BoxDecoration(
                                    color: _supportColor.withOpacity(.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(formatBigNumber(difficulty),
                            style: mono(size: 11.5, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text('echelle logarithmique : chaque cran vaut dix fois plus',
                        style: mono(size: 9.5, color: AppColors.dim)),
                  ] else
                    Text(
                      'Difficulte non publiee par l\'explorateur pour cette '
                      'chaine.',
                      style: mono(size: 10.5, color: AppColors.dim),
                    ),
                ],
              ),
            ),
            if (expanded) ...[
              const Divider(height: 24),
              Text(coin.summary,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.55, color: AppColors.ink)),
              const SizedBox(height: 14),
              _Fact('Algorithme', coin.algorithm.label),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(coin.algorithm.explanation,
                    style: const TextStyle(
                        fontSize: 11.5, height: 1.5, color: AppColors.muted)),
              ),
              _Fact('Intervalle entre blocs',
                  '${_formatMinutes(coin.blockMinutes)}'),
              if (coin.blockReward > 0)
                _Fact('Recompense', '${_formatReward(coin.blockReward)} '
                    '${coin.symbol}'),
              if (stats != null) ...[
                _Fact('Difficulte', describeMagnitude(stats!.difficulty)),
                _Fact('Puissance du reseau',
                    '${formatBigNumber(stats!.hashrate)}H/s'),
                if (stats!.priceUsd > 0)
                  _Fact('Cours', '${stats!.priceUsd.toStringAsFixed(
                      stats!.priceUsd >= 1 ? 2 : 6)} dollars'),
                if (minerHashrate > 0)
                  _Fact(
                    'Un bloc, a ta puissance',
                    formatLongDuration(stats!
                        .daysPerBlock(minerHashrate, coin.blockMinutes)),
                    highlight: true,
                  ),
              ],
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.panelHigh,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _supportColor.withOpacity(.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coin.support.label,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _supportColor)),
                    const SizedBox(height: 5),
                    Text(coin.support.explanation,
                        style: const TextStyle(
                            fontSize: 11.5, height: 1.5, color: AppColors.muted)),
                    if (coin.mergeMined) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Minage conjoint : cette chaine accepte le travail deja '
                        'realise pour Bitcoin. Le meme hachage compte deux fois.',
                        style: mono(size: 10.5, color: AppColors.cyan),
                      ),
                    ],
                    if (coin.obscure) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Chaine confidentielle : difficulte tres basse, donc '
                        'des blocs a portee. Mais aussi peu de pools, peu '
                        'd\'echanges possibles, et un avenir incertain. '
                        'L\'interet est d\'y voir enfin des parts acceptees, '
                        'pas d\'y placer des espoirs.',
                        style: mono(size: 10.5, color: AppColors.dim),
                      ),
                    ],
                    if (coin.poolNote != null) ...[
                      const SizedBox(height: 8),
                      Text(coin.poolNote!,
                          style: mono(size: 10.5, color: AppColors.amber)),
                    ],
                    if (coin.addressRules?.note != null) ...[
                      const SizedBox(height: 8),
                      Text(coin.addressRules!.note!,
                          style: mono(size: 10.5, color: AppColors.amber)),
                    ],
                  ],
                ),
              ),
              if (coin.personal) ...[
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final c = context.watch<ChainController>();
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const MyChainScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.violet,
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                      label: Text(c.mining
                          ? 'Minage en cours - ouvrir'
                          : 'Ouvrir ma chaine'),
                    ),
                  );
                }),
              ] else if (coin.isMinableHere && coin.pool != null) ...[
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final m = context.watch<MinerController>();
                  final active = m.activeCoinSymbol == coin.symbol;
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: active || m.isActive
                          ? null
                          : () => m.setActiveCoin(coin),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.mint,
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(
                          active
                              ? Icons.check_circle_rounded
                              : Icons.swap_horiz_rounded,
                          size: 17),
                      label: Text(active
                          ? 'Chaine active'
                          : 'Miner cette chaine (${MiningAlgorithm.forCoin(coin.symbol).label})'),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Le pool et l\'algorithme sont configures automatiquement. '
                    'Pense a renseigner une adresse de cette chaine dans les '
                    'reglages : une adresse Bitcoin ne fonctionnera pas '
                    'ailleurs.',
                    style: mono(size: 10, color: AppColors.dim),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _formatMinutes(double minutes) {
    if (minutes < 1) return '${(minutes * 60).toStringAsFixed(0)} secondes';
    if (minutes == minutes.roundToDouble()) {
      return '${minutes.toStringAsFixed(0)} minutes';
    }
    return '${minutes.toStringAsFixed(2)} minutes';
  }

  static String _formatReward(double reward) {
    if (reward >= 1000) return formatCount(reward.round());
    return reward.toString();
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.title, this.value, {this.highlight = false});
  final String title;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: mono(
                  size: 12,
                  weight: FontWeight.w700,
                  color: highlight ? AppColors.amber : AppColors.ink,
                )),
          ),
        ],
      ),
    );
  }
}

/// Porte d'entree vers la chaine personnelle, tant qu'elle n'existe pas.
///
/// Elle avait ete retiree en version 36 comme faisant doublon avec la fiche du
/// catalogue - sauf que cette fiche n'apparait qu'une fois la chaine creee.
/// Sans chaine, il n'y avait donc plus aucun acces a l'ecran de creation.
class _CreerMaMonnaie extends StatelessWidget {
  const _CreerMaMonnaie();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.violet.withOpacity(.45),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MyChainScreen()),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.violet.withOpacity(.14),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.violet.withOpacity(.45)),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 21, color: AppColors.violet),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Creer ou rejoindre ta monnaie',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Une vraie chaine, de vrais blocs, une valeur de zero. '
                    'Rejoins celle d\'un serveur, ou fabrique la tienne.',
                    style: mono(size: 10.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Acces au registre de monnaie locale.
///
/// Sa place ici est volontaire : le catalogue compare des chaines entre elles,
/// et celle-ci n'en est pas une. C'est justement ce qu'il faut voir.
class _MonnaieLocale extends StatelessWidget {
  const _MonnaieLocale();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LocalCurrencyController>();

    return AppCard(
      accent: AppColors.mint.withOpacity(.4),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LocalCurrencyScreen()),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.mint.withOpacity(.13),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.mint.withOpacity(.45)),
              ),
              child: const Icon(Icons.storefront_rounded,
                  size: 21, color: AppColors.mint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monnaie locale',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    c.exists
                        ? '${c.ledger!.accounts.length} comptes - '
                            '${c.ledger!.inCirculation.toStringAsFixed(0)} '
                            '${c.ledger!.symbol} en circulation'
                        : 'Sans chaine, sans minage, sans cle privee - '
                            'et ca marche',
                    style: mono(size: 10.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
