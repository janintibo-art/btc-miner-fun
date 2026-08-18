import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/gpu_miner.dart';
import '../core/gpu_probe.dart';
import '../core/platform_profile.dart';
import 'app_card.dart';

/// Inventaire du materiel de calcul de la machine.
///
/// Premiere etape du chantier GPU : on ne calcule rien encore, on verifie que
/// le chemin Dart vers le pilote graphique fonctionne de bout en bout.
class HardwareCard extends StatefulWidget {
  const HardwareCard({super.key});

  @override
  State<HardwareCard> createState() => _HardwareCardState();
}

class _HardwareCardState extends State<HardwareCard> {
  GpuProbeResult _result = GpuProbeResult.notProbed;
  bool _probed = false;
  GpuSelfTest _selfTest = GpuSelfTest.notRun;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    if (PlatformProfile.isDesktop) _probe();
  }

  void _probe() {
    setState(() {
      _result = probeGpuDevices();
      _probed = true;
    });
  }

  Future<void> _runSelfTest() async {
    setState(() => _testing = true);
    // La compilation du noyau et les hachages passent par le pilote : on rend
    // la main a l'interface avant de bloquer.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final result = runGpuSelfTest();
    if (!mounted) return;
    setState(() {
      _selfTest = result;
      _testing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('MATERIEL DE CALCUL', style: label())),
              IconButton(
                onPressed: _probe,
                icon: const Icon(Icons.refresh_rounded,
                    size: 19, color: AppColors.cyan),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Device(
            title: 'Processeur',
            subtitle: '${PlatformProfile.availableCores} coeurs disponibles',
            detail: 'Utilise par le moteur actuel',
            color: AppColors.amber,
            icon: Icons.memory_rounded,
          ),
          if (_probed) ...[
            for (final device in _result.devices)
              _Device(
                title: device.name.isEmpty ? device.kindLabel : device.name,
                subtitle: '${device.computeUnits} unites de calcul'
                    '${device.clockMHz > 0 ? ' - ${device.clockMHz} MHz' : ''}'
                    '${device.memoryMiB > 0 ? ' - ${device.memoryMiB} Mio' : ''}',
                detail: '${device.kindLabel} - ${device.vendor}',
                color: device.isGpu ? AppColors.violet : AppColors.dim,
                icon: device.isGpu
                    ? Icons.developer_board_rounded
                    : Icons.memory_outlined,
              ),
            const SizedBox(height: 6),
            Text(_result.message,
                style: mono(
                  size: 10.5,
                  color: _result.available ? AppColors.mint : AppColors.dim,
                )),
          ] else
            Text(
              'La detection materielle n\'est disponible que sur la version '
              'Windows.',
              style: mono(size: 11, color: AppColors.dim),
            ),
          if (_result.available) ...[
            const Divider(height: 26),
            Text('AUTO-TEST DU MOTEUR GPU', style: label()),
            const SizedBox(height: 8),
            const Text(
              'La carte doit reproduire exactement les hachages du processeur : '
              'le bloc reel 125552, puis soixante-quatre en-tetes tires au '
              'hasard. Tant que ce test n\'est pas passe, aucun resultat de la '
              'carte n\'est utilise et rien n\'est envoye au pool.',
              style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            if (_selfTest.trials > 0 || _selfTest.message != GpuSelfTest.notRun.message)
              _SelfTestReport(result: _selfTest),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _runSelfTest,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.violet,
                  side: const BorderSide(color: AppColors.line),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.violet),
                      )
                    : const Icon(Icons.verified_outlined, size: 18),
                label: Text(_testing
                    ? 'Verification en cours...'
                    : 'Compiler le noyau et verifier la carte'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Device extends StatelessWidget {
  const _Device({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(.13),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(.4)),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: mono(size: 11, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(detail, style: mono(size: 10, color: AppColors.dim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Compte rendu de l'auto-test, y compris en cas d'echec : l'en-tete fautif et
/// les deux hachages sont affiches pour pouvoir rejouer le cas.
class _SelfTestReport extends StatelessWidget {
  const _SelfTestReport({required this.result});

  final GpuSelfTest result;

  @override
  Widget build(BuildContext context) {
    final color = result.passed ? AppColors.mint : AppColors.coral;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.panelHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                result.passed
                    ? Icons.verified_rounded
                    : Icons.error_outline_rounded,
                size: 17,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(result.message,
                    style: TextStyle(
                        fontSize: 12.5, height: 1.45, color: color)),
              ),
            ],
          ),
          if (result.passed && result.hashrate != null) ...[
            const SizedBox(height: 12),
            Text('DEBIT MESURE', style: label()),
            const SizedBox(height: 4),
            Text(formatHashrate(result.hashrate!),
                style: mono(size: 22, weight: FontWeight.w700)),
          ],
          if (!result.passed && result.mismatchHeader != null) ...[
            const SizedBox(height: 12),
            Text('EN-TETE FAUTIF', style: label()),
            const SizedBox(height: 4),
            SelectableText(result.mismatchHeader!,
                style: mono(size: 9.5, color: AppColors.muted)),
            const SizedBox(height: 8),
            Text('PROCESSEUR', style: label()),
            SelectableText(result.cpuHash ?? '-',
                style: mono(size: 9.5, color: AppColors.mint)),
            const SizedBox(height: 6),
            Text('CARTE', style: label()),
            SelectableText(result.gpuHash ?? '-',
                style: mono(size: 9.5, color: AppColors.coral)),
          ],
        ],
      ),
    );
  }
}
