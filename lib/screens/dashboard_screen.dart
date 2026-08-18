import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/job_inspector.dart';
import '../widgets/log_console.dart';
import '../widgets/sparkline.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _StatusLine(m: m),
        const SizedBox(height: 14),
        _HashrateCard(m: m),
        const SizedBox(height: 14),
        _StartButton(m: m),
        const SizedBox(height: 22),
        const SectionLabel('Compteurs'),
        _StatsGrid(m: m),
        const SizedBox(height: 22),
        const SectionLabel('Le bloc sur lequel tu travailles'),
        JobInspector(job: m.job),
        const SizedBox(height: 22),
        const SectionLabel('Journal'),
        LogConsole(lines: m.logs),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    final color = switch (m.status) {
      MinerStatus.mining => AppColors.mint,
      MinerStatus.connecting || MinerStatus.waitingJob => AppColors.amber,
      MinerStatus.error => AppColors.coral,
      MinerStatus.stopped => AppColors.muted,
    };
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(m.statusMessage, style: mono(size: 13, color: color)),
        ),
      ],
    );
  }
}

class _HashrateCard extends StatelessWidget {
  const _HashrateCard({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      accent: m.isBusy ? AppColors.amber.withOpacity(0.45) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PUISSANCE DE CALCUL', style: label()),
          const SizedBox(height: 10),
          Text(
            formatHashrate(m.hashrate),
            style: mono(size: 40, weight: FontWeight.w700, spacing: -1),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatCount(m.totalHashes)} hachages depuis le demarrage',
            style: mono(size: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Sparkline(values: m.history),
          const SizedBox(height: 6),
          Text('60 dernieres secondes', style: label()),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    final running = m.isActive;
    return SizedBox(
      height: 62,
      child: FilledButton.icon(
        onPressed: () => m.toggle(),
        style: FilledButton.styleFrom(
          backgroundColor: running ? AppColors.panelHigh : AppColors.amber,
          foregroundColor: running ? AppColors.ink : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: running ? AppColors.line : Colors.transparent),
          ),
        ),
        icon: Icon(running ? Icons.stop_rounded : Icons.bolt_rounded, size: 26),
        label: Text(
          running ? 'Arreter le minage' : 'Lancer le minage',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    final items = <List<String>>[
      ['Parts acceptees', m.accepted.toString()],
      ['Parts refusees', m.rejected.toString()],
      ['Duree', formatDuration(m.uptime)],
      [
        'Meilleure difficulte',
        m.bestDifficulty == 0 ? '-' : m.bestDifficulty.toStringAsFixed(3)
      ],
      ['Difficulte du pool', m.poolDifficulty == 0 ? '-' : m.poolDifficulty.toStringAsFixed(3)],
      ['Travaux recus', m.jobsReceived.toString()],
      ['Coeurs actifs', '${m.effectiveThreads} / ${m.availableCores}'],
      ['Parts en attente', m.pendingShares.toString()],
      ['Intensite', '${m.intensity} %'],
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.1,
      ),
      itemBuilder: (context, i) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(items[i][0].toUpperCase(), style: label()),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(items[i][1],
                  style: mono(size: 20, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
