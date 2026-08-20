import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../state/miner_controller.dart';
import 'app_card.dart';

/// Les derniers blocs trouves dans le monde, avec le message que leur
/// decouvreur y a laisse.
class BlockFeedCard extends StatelessWidget {
  const BlockFeedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('LES DERNIERS BLOCS DU MONDE', style: label())),
              IconButton(
                onPressed: m.blocksLoading ? null : m.refreshBlocks,
                icon: m.blocksLoading
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
          const SizedBox(height: 8),
          const Text(
            'Chacun de ces blocs a ete trouve il y a quelques minutes par '
            'quelqu\'un, quelque part. C\'est exactement le travail que fait ta '
            'machine, vu de l\'autre cote.',
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          if (m.recentBlocks.isEmpty)
            Text('Touche la fleche pour charger le fil.',
                style: mono(size: 11.5, color: AppColors.dim))
          else
            ...m.recentBlocks.take(10).map((block) {
              final message = block.messages
                  .where((text) => text.trim().length >= 4)
                  .take(2)
                  .join('  ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('#${formatCount(block.height)}',
                            style: mono(
                                size: 12,
                                weight: FontWeight.w700,
                                color: AppColors.amber)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(block.poolName,
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ),
                        Text(_age(block.age),
                            style: mono(size: 10.5, color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatCount(block.transactions)} transactions - '
                      '${formatBtc(block.rewardBtc)} ₿ de recompense',
                      style: mono(size: 10.5, color: AppColors.muted),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('« $message »',
                          style: mono(size: 10.5, color: AppColors.mint)),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  static String _age(Duration age) {
    if (age.inMinutes < 1) return 'a l\'instant';
    if (age.inMinutes < 60) return 'il y a ${age.inMinutes} min';
    return 'il y a ${age.inHours} h';
  }
}
