import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/session.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/benchmark_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();
    final total = m.lifetime;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const SectionLabel('Comparer les moteurs'),
        const BenchmarkCard(),
        const SizedBox(height: 20),
        const SectionLabel('Depuis le debut'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatCount(total.hashes),
                  style: mono(size: 30, weight: FontWeight.w700, spacing: -1)),
              Text('hachages calcules au total',
                  style: mono(size: 12, color: AppColors.muted)),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Mini(
                      title: 'Temps de minage',
                      value: formatDuration(Duration(seconds: total.seconds))),
                  _Mini(
                      title: 'Parts acceptees',
                      value: total.accepted.toString()),
                  _Mini(
                    title: 'Record',
                    value: total.best == 0
                        ? '-'
                        : total.best.toStringAsFixed(1),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: SectionLabel('Sessions (${m.sessions.length})')),
            if (m.sessions.isNotEmpty)
              TextButton(
                onPressed: () => _confirmClear(context, m),
                child: const Text('Effacer',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
          ],
        ),
        if (m.sessions.isEmpty)
          AppCard(
            child: Text(
              'Aucune session enregistree. Toute session de plus de dix '
              'secondes est ajoutee ici a l\'arret du minage.',
              style: mono(size: 12, color: AppColors.muted),
            ),
          )
        else
          ...m.sessions.map((s) => _SessionTile(session: s)),
      ],
    );
  }

  void _confirmClear(BuildContext context, MinerController m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Effacer l\'historique ?'),
        content: const Text(
            'Les sessions enregistrees sur cet appareil seront supprimees. '
            'Cette action est definitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              m.clearSessions();
              Navigator.pop(ctx);
            },
            child: const Text('Effacer',
                style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: label()),
          const SizedBox(height: 6),
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final MiningSession session;

  @override
  Widget build(BuildContext context) {
    final d = session.startedAt;
    final date = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')} a '
        '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(date,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                Text(formatDuration(Duration(seconds: session.seconds)),
                    style: mono(size: 12.5, color: AppColors.amber)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${formatHashrate(session.averageHashrate)} en moyenne sur '
              '${session.threads} coeur(s)',
              style: mono(size: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatCount(session.hashes)} hachages - '
              '${session.accepted} accepte(s), ${session.rejected} refusee(s)'
              '${session.bestDifficulty == 0 ? '' : ' - record ${session.bestDifficulty.toStringAsFixed(2)}'}',
              style: mono(size: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(session.pool, style: mono(size: 11, color: AppColors.line)),
          ],
        ),
      ),
    );
  }
}
