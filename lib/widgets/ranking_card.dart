import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/mining_ranking.dart';
import '../state/miner_controller.dart';
import 'app_card.dart';

/// Classement des chaines minables par esperance de gain, a la puissance
/// reellement mesuree sur cette machine.
class RankingCard extends StatelessWidget {
  const RankingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();
    final ranking = m.ranking;

    return AppCard(
      accent: AppColors.mint.withOpacity(.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OU MINER, A TA PUISSANCE', style: label()),
          const SizedBox(height: 10),
          if (m.referenceHashrate <= 0)
            Text(
              'Lance une session : le classement utilisera ta puissance reelle '
              'plutot qu\'une valeur theorique.',
              style: mono(size: 11.5, color: AppColors.dim),
            )
          else if (ranking.isEmpty)
            Text(
              'Actualise les statistiques des chaines pour construire le '
              'classement.',
              style: mono(size: 11.5, color: AppColors.dim),
            )
          else ...[
            Text(
              'A ${formatHashrate(m.referenceHashrate)}, voici ce que chaque '
              'chaine rapporterait en moyenne. Le calcul tient compte de la '
              'difficulte, du rythme des blocs, de la recompense et du cours.',
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            ...ranking.take(8).toList().asMap().entries.map(
                  (entry) => _RankRow(
                    position: entry.key + 1,
                    ranked: entry.value,
                    best: ranking.first,
                  ),
                ),
            const SizedBox(height: 6),
            Text(
              'Une difficulte basse ne suffit pas : encore faut-il que la '
              'recompense vaille quelque chose. C\'est pour cela que le premier '
              'du classement n\'est presque jamais la chaine la plus facile.',
              style: mono(size: 10.5, color: AppColors.dim),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.position,
    required this.ranked,
    required this.best,
  });

  final int position;
  final RankedCoin ranked;
  final RankedCoin best;

  @override
  Widget build(BuildContext context) {
    final fraction = best.dollarsPerDay <= 0
        ? 0.0
        : (ranked.dollarsPerDay / best.dollarsPerDay).clamp(0.01, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('$position',
                    style: mono(
                        size: 12,
                        weight: FontWeight.w700,
                        color: position == 1 ? AppColors.amber : AppColors.dim)),
              ),
              Expanded(
                child: Text(
                  '${ranked.coin.name} (${ranked.coin.symbol})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: position == 1 ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Text(_perDay(ranked.dollarsPerDay),
                  style: mono(size: 11.5, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const SizedBox(width: 22),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.panelHigh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Container(
                        height: 6,
                        width: c.maxWidth * fraction,
                        decoration: BoxDecoration(
                          color: position == 1
                              ? AppColors.amber
                              : AppColors.mint.withOpacity(.6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              'un bloc tous les ${formatLongDuration(ranked.daysPerBlock)} - '
              'bloc a ${_dollars(ranked.rewardValue)}',
              style: mono(size: 10, color: AppColors.dim),
            ),
          ),
        ],
      ),
    );
  }

  static String _perDay(double dollars) {
    if (dollars <= 0) return '0';
    if (dollars < 0.000001) return '${(dollars * 1e6).toStringAsFixed(2)} µ\$/j';
    if (dollars < 0.01) return '${(dollars * 1000).toStringAsFixed(2)} m\$/j';
    return '${dollars.toStringAsFixed(2)} \$/j';
  }

  static String _dollars(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} k\$';
    if (value >= 1) return '${value.toStringAsFixed(0)} \$';
    return '${value.toStringAsFixed(4)} \$';
  }
}
