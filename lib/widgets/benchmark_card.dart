import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/hash_mode.dart';
import '../state/miner_controller.dart';
import 'app_card.dart';

/// Compare les trois moteurs de hachage sur le materiel de l'utilisateur.
class BenchmarkCard extends StatelessWidget {
  const BenchmarkCard({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();
    final result = m.benchmark;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BANC D\'ESSAI', style: label()),
          const SizedBox(height: 8),
          const Text(
            'Les trois moteurs calculent le meme hash. Seule la vitesse change. '
            'La mesure prend environ huit secondes, sur un seul coeur.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (result != null) ...[
            ...HashMode.values.map((mode) => _Bar(
                  mode: mode,
                  rate: result.rates[mode] ?? 0,
                  best: result.best,
                  gain: result.gainOver(HashMode.compatible, mode),
                  selected: m.hashMode == mode,
                )),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  result.identical ? Icons.verified_rounded : Icons.warning_rounded,
                  size: 16,
                  color: result.identical ? AppColors.mint : AppColors.coral,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.identical
                        ? 'Hash identique pour les trois moteurs : la vitesse ne '
                            'coute aucune justesse.'
                        : 'Les moteurs divergent. Repasse en mode compatibilite.',
                    style: mono(
                      size: 11,
                      color: result.identical ? AppColors.mint : AppColors.coral,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: m.benchmarkRunning || m.isActive ? null : m.runBenchmark,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.amber,
                side: const BorderSide(color: AppColors.line),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: m.benchmarkRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.amber),
                    )
                  : const Icon(Icons.timer_outlined, size: 18),
              label: Text(
                m.benchmarkRunning
                    ? 'Mesure en cours...'
                    : (result == null ? 'Lancer la mesure' : 'Refaire la mesure'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ),
          if (m.isActive)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Arrete le minage pour mesurer : les coeurs doivent etre libres.',
                style: mono(size: 11, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.mode,
    required this.rate,
    required this.best,
    required this.gain,
    required this.selected,
  });

  final HashMode mode;
  final double rate;
  final double best;
  final double gain;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fraction = best <= 0 ? 0.0 : (rate / best).clamp(0.02, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle,
                      size: 14, color: AppColors.amber),
                ),
              Expanded(
                child: Text(mode.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.ink : AppColors.muted,
                    )),
              ),
              Text(formatHashrate(rate), style: mono(size: 12.5)),
              if (mode != HashMode.compatible) ...[
                const SizedBox(width: 8),
                Text('x${gain.toStringAsFixed(2)}',
                    style: mono(size: 12.5, color: AppColors.mint)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.panelHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width: c.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.amber : AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
