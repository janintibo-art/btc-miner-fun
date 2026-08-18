import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/hash_mode.dart';
import '../core/nonce_walker.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';
import 'screensaver_screen.dart';
import '../widgets/job_inspector.dart';
import '../widgets/log_console.dart';
import '../widgets/sparkline.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 34),
      children: [
        _StatusLine(m: m),
        const SizedBox(height: 14),
        _HashrateCard(m: m),
        const SizedBox(height: 14),
        _StartButton(m: m),
        const SizedBox(height: 24),
        const SectionLabel('Telemetrie du reacteur'),
        _StatsGrid(m: m),
        const SizedBox(height: 24),
        const SectionLabel('Records'),
        _RecordsCard(m: m),
        const SizedBox(height: 24),
        const SectionLabel('Bloc actif'),
        JobInspector(job: m.job),
        const SizedBox(height: 24),
        const SectionLabel('Console Stratum'),
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

    final icon = switch (m.status) {
      MinerStatus.mining => Icons.bolt_rounded,
      MinerStatus.connecting => Icons.sync_rounded,
      MinerStatus.waitingJob => Icons.hourglass_top_rounded,
      MinerStatus.error => Icons.warning_amber_rounded,
      MinerStatus.stopped => Icons.power_settings_new_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panel.withOpacity(.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.30)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(.07), blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(.12),
              border: Border.all(color: color.withOpacity(.45)),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SYSTEM STATUS', style: label()),
                const SizedBox(height: 2),
                Text(m.statusMessage, style: mono(size: 12.5, color: color)),
              ],
            ),
          ),
          _StatusDot(color: color, active: m.isActive),
        ],
      ),
    );
  }
}

/// Temoin d'etat. Il ne bat que pendant le minage, et reste fixe si le systeme
/// a demande la reduction des animations.
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.active});
  final Color color;
  final bool active;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.active || reduceMotion) {
      return _dot(1);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _dot(0.55 + _controller.value * 0.45),
    );
  }

  Widget _dot(double intensity) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(.7 * intensity),
              blurRadius: 6 + 8 * intensity,
            ),
          ],
        ),
      );
}

/// Position, sur la fenetre des 60 dernieres secondes, des trouvailles
/// remarquables signalees par le moteur. Reglable via le seuil d'observation
/// du labo : c'est le meme evenement, vu ici comme un impact sur la courbe.
List<double> _recentSightings(MinerController m) {
  final now = DateTime.now();
  final markers = <double>[];
  for (final sighting in m.sightings) {
    final age = now.difference(sighting.at).inMilliseconds / 60000;
    if (age >= 0 && age <= 1) markers.add(1 - age);
  }
  return markers;
}

class _HashrateCard extends StatelessWidget {
  const _HashrateCard({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 16),
      accent: m.isBusy ? AppColors.amber : AppColors.cyan.withOpacity(.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HASH REACTOR // LIVE OUTPUT', style: label()),
                    const SizedBox(height: 7),
                    Text(
                      m.isActive ? 'CORE ENGAGED' : 'CORE STANDBY',
                      style: mono(
                        size: 10.5,
                        weight: FontWeight.w800,
                        color: m.isActive ? AppColors.mint : AppColors.muted,
                        spacing: .7,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (m.isActive ? AppColors.amber : AppColors.cyan).withOpacity(.28),
                      AppColors.panelHigh.withOpacity(.72),
                    ],
                  ),
                  border: Border.all(
                    color: (m.isActive ? AppColors.amber : AppColors.cyan).withOpacity(.55),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (m.isActive ? AppColors.amber : AppColors.cyan).withOpacity(.18),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.memory_rounded,
                  color: m.isActive ? AppColors.amberHot : AppColors.cyan,
                  size: 25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.ink, AppColors.amberHot],
              ).createShader(bounds),
              child: Text(
                formatHashrate(m.hashrate),
                style: mono(
                  size: 43,
                  weight: FontWeight.w900,
                  color: Colors.white,
                  spacing: -1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${formatCount(m.totalHashes)} hachages depuis le demarrage',
            style: mono(size: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 7),
            decoration: BoxDecoration(
              color: AppColors.abyss.withOpacity(.43),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line.withOpacity(.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Sparkline(
                  values: m.history,
                  height: 74,
                  markers: _recentSightings(m),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('T-60 SEC', style: label()),
                    const Spacer(),
                    Text(
                      '${m.effectiveThreads} CORES',
                      style: mono(size: 9.5, color: AppColors.cyan, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TelemetryPill(
                icon: Icons.speed_rounded,
                label: m.hashMode.label,
                color: AppColors.cyan,
              ),
              _TelemetryPill(
                icon: Icons.route_rounded,
                label: m.nonceStrategy.label,
                color: AppColors.violet,
              ),
              _TelemetryPill(
                icon: Icons.cloud_done_rounded,
                label: m.poolDifficulty == 0
                    ? 'POOL --'
                    : 'POOL ${m.poolDifficulty.toStringAsFixed(2)}',
                color: AppColors.mint,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TelemetryPill extends StatelessWidget {
  const _TelemetryPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.23)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: mono(size: 9.2, color: AppColors.ink, weight: FontWeight.w700),
          ),
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
    final accent = running ? AppColors.coral : AppColors.amber;

    return Semantics(
      button: true,
      label: running ? 'Arreter le minage' : 'Lancer le minage',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => m.toggle(),
          borderRadius: BorderRadius.circular(19),
          child: Ink(
            height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              gradient: running
                  ? const LinearGradient(
                      colors: [Color(0xFF251522), Color(0xFF111622)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFC45F), AppColors.amber, Color(0xFFD66C00)],
                    ),
              border: Border.all(
                color: running ? AppColors.coral.withOpacity(.5) : const Color(0xFFFFD28A),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(running ? .12 : .28),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: running ? AppColors.coral.withOpacity(.12) : Colors.black.withOpacity(.12),
                    border: Border.all(
                      color: running ? AppColors.coral.withOpacity(.45) : Colors.black.withOpacity(.16),
                    ),
                  ),
                  child: Icon(
                    running ? Icons.stop_rounded : Icons.bolt_rounded,
                    size: 24,
                    color: running ? AppColors.coral : const Color(0xFF1C1205),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  running ? 'ARRETER LE REACTEUR' : 'ENGAGER LE REACTEUR',
                  style: TextStyle(
                    fontSize: 15,
                    letterSpacing: .6,
                    fontWeight: FontWeight.w900,
                    color: running ? AppColors.ink : const Color(0xFF1C1205),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordsCard extends StatefulWidget {
  const _RecordsCard({required this.m});
  final MinerController m;

  @override
  State<_RecordsCard> createState() => _RecordsCardState();
}

class _RecordsCardState extends State<_RecordsCard> {
  @override
  Widget build(BuildContext context) {
    final m = widget.m;

    final milestone = m.lastMilestone;
    if (milestone != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.mediumImpact();
        m.clearMilestoneFlag();
      });
    }

    return AppCard(
      accent: milestone != null ? AppColors.amber : AppColors.violet.withOpacity(.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.violet.withOpacity(.10),
                  border: Border.all(color: AppColors.violet.withOpacity(.28)),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.violet, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(child: Text('MEILLEURE DIFFICULTE DE TOUJOURS', style: label())),
              if (milestone != null)
                const Icon(Icons.celebration_rounded, color: AppColors.amber, size: 19),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            m.lifetimeBestDifficulty == 0
                ? '-'
                : m.lifetimeBestDifficulty.toStringAsFixed(2),
            style: mono(size: 30, weight: FontWeight.w900, spacing: -1),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final step in MinerController.kMilestones)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: m.milestonesReached.contains(step)
                        ? LinearGradient(colors: [
                            AppColors.amber.withOpacity(.22),
                            AppColors.violet.withOpacity(.12),
                          ])
                        : null,
                    color: m.milestonesReached.contains(step) ? null : AppColors.panelHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: m.milestonesReached.contains(step)
                          ? AppColors.amber.withOpacity(.75)
                          : AppColors.line,
                    ),
                    boxShadow: m.milestonesReached.contains(step)
                        ? [BoxShadow(color: AppColors.amber.withOpacity(.09), blurRadius: 10)]
                        : null,
                  ),
                  child: Text(
                    step >= 1000000
                        ? '${step ~/ 1000000}M'
                        : (step >= 1000 ? '${step ~/ 1000}k' : '$step'),
                    style: mono(
                      size: 11.5,
                      weight: FontWeight.w800,
                      color: m.milestonesReached.contains(step)
                          ? AppColors.amberHot
                          : AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            'Chaque palier est dix fois plus dur que le precedent. Le reseau, '
            'lui, exige des dizaines de milliers de milliards.',
            style: mono(size: 10.5, color: AppColors.dim),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  const _StatData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    final items = <_StatData>[
      _StatData('Parts acceptees', m.accepted.toString(), Icons.check_circle_rounded, AppColors.mint),
      _StatData('Parts refusees', m.rejected.toString(), Icons.cancel_rounded, AppColors.coral),
      _StatData('Duree', formatDuration(m.uptime), Icons.timer_rounded, AppColors.cyan),
      _StatData(
        'Meilleure difficulte',
        m.bestDifficulty == 0 ? '-' : m.bestDifficulty.toStringAsFixed(3),
        Icons.auto_graph_rounded,
        AppColors.violet,
      ),
      _StatData(
        'Difficulte du pool',
        m.poolDifficulty == 0 ? '-' : m.poolDifficulty.toStringAsFixed(3),
        Icons.hub_rounded,
        AppColors.amber,
      ),
      _StatData('Travaux recus', m.jobsReceived.toString(), Icons.inventory_2_rounded, AppColors.cyan),
      _StatData('Coeurs actifs', '${m.effectiveThreads} / ${m.availableCores}', Icons.memory_rounded, AppColors.amber),
      _StatData('Parts en attente', m.pendingShares.toString(), Icons.hourglass_bottom_rounded, AppColors.violet),
      _StatData('Moteur', m.hashMode.label, Icons.speed_rounded, AppColors.cyan),
      _StatData('Marche', m.nonceStrategy.label, Icons.route_rounded, AppColors.mint),
      _StatData(
        'Arriere-plan',
        m.backgroundServiceActive ? 'actif' : (m.isActive ? 'ecran requis' : '-'),
        Icons.layers_rounded,
        AppColors.amber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 11,
            crossAxisSpacing: 11,
            childAspectRatio: columns == 3 ? 2.35 : 1.75,
          ),
          itemBuilder: (context, i) {
            final item = items[i];
            return AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              accent: item.color.withOpacity(.28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 14, color: item.color),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item.label.toUpperCase(),
                          style: label(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.value,
                      style: mono(size: 18.5, weight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
