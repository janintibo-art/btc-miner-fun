import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../state/miner_controller.dart';

/// Mode veille : l'application en plein ecran, a poser sur le bureau pendant
/// que la machine calcule. Rien de simule, tout vient du moteur.
class ScreensaverScreen extends StatefulWidget {
  const ScreensaverScreen({super.key});

  @override
  State<ScreensaverScreen> createState() => _ScreensaverScreenState();
}

class _ScreensaverScreenState extends State<ScreensaverScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    // Le nonce change des milliers de fois par seconde : on le regarde a
    // intervalle fixe plutot que de reconstruire l'ecran sans arret.
    _refresh = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _sweep.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();

    return Scaffold(
      backgroundColor: AppColors.abyss,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('BTC // REACTOR CORE',
                        style: mono(size: 11, color: AppColors.cyan, spacing: 2)),
                    const Spacer(),
                    Text(m.isActive ? 'EN MARCHE' : 'A L\'ARRET',
                        style: mono(
                          size: 11,
                          color: m.isActive ? AppColors.mint : AppColors.dim,
                          spacing: 2,
                        )),
                  ],
                ),
                const Spacer(),
                Text(formatHashrate(m.hashrate),
                    style: mono(
                        size: 52, weight: FontWeight.w700, spacing: -2)),
                const SizedBox(height: 6),
                Text('${formatCount(m.totalHashes)} hachages',
                    style: mono(size: 13, color: AppColors.muted)),
                const SizedBox(height: 28),
                _NonceLine(nonce: m.currentNonce, sweep: _sweep),
                const SizedBox(height: 28),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: m.sightings.length,
                    itemBuilder: (context, i) {
                      final s = m.sightings[i];
                      final fade = 1 - (i / 14).clamp(0.0, 0.85);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          '${s.nonce.toRadixString(16).padLeft(8, '0')}  '
                          'difficulte ${s.difficulty.toStringAsFixed(1)}',
                          style: mono(
                            size: 12,
                            color: AppColors.mint.withOpacity(fade),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    _Stat('RECORD',
                        m.bestDifficulty == 0
                            ? '-'
                            : m.bestDifficulty.toStringAsFixed(1)),
                    _Stat('PARTS', '${m.accepted}'),
                    _Stat('DUREE', formatDuration(m.uptime)),
                    _Stat('COEURS', '${m.effectiveThreads}'),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text('touche l\'ecran pour revenir',
                      style: mono(size: 10, color: AppColors.dim)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NonceLine extends StatelessWidget {
  const _NonceLine({required this.nonce, required this.sweep});
  final int nonce;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final hex = nonce.toRadixString(16).padLeft(8, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NONCE EN COURS', style: label()),
        const SizedBox(height: 6),
        Text(hex,
            style: mono(
                size: 30, weight: FontWeight.w700, color: AppColors.amber)),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: sweep,
          builder: (context, _) => LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(height: 2, color: AppColors.line),
                Positioned(
                  left: c.maxWidth * sweep.value,
                  child: Container(
                    height: 2,
                    width: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.cyan.withOpacity(0),
                        AppColors.cyan,
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
          Text(title, style: label()),
          const SizedBox(height: 4),
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
