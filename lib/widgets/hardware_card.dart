import 'package:flutter/material.dart';

import '../app_theme.dart';
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
            Text(
              'Une carte graphique exploitable a ete trouvee. Elle ne calcule '
              'encore rien : cette etape verifiait uniquement que le pont vers '
              'le pilote fonctionne. Le noyau de hachage viendra ensuite, avec '
              'un auto-test obligatoire contre le processeur avant toute '
              'soumission au pool.',
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: AppColors.muted),
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
