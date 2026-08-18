import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late final TextEditingController _wallet;
  late final TextEditingController _worker;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _password;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _wallet = TextEditingController();
    _worker = TextEditingController();
    _host = TextEditingController();
    _port = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _wallet.dispose();
    _worker.dispose();
    _host.dispose();
    _port.dispose();
    _password.dispose();
    super.dispose();
  }

  void _sync(MinerController m) {
    if (_loaded) return;
    _wallet.text = m.wallet;
    _worker.text = m.workerName;
    _host.text = m.poolHost;
    _port.text = m.poolPort.toString();
    _password.text = m.poolPassword;
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();
    _sync(m);
    final locked = m.isBusy;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const SectionLabel('Mode de fonctionnement'),
        AppCard(
          child: Column(
            children: [
              _ModeTile(
                title: 'Demo hors ligne',
                subtitle:
                    'Aucune connexion. L\'application cherche des solutions faciles pour montrer comment fonctionne le minage.',
                selected: m.mode == MinerMode.demo,
                onTap: locked ? null : () => m.setMode(MinerMode.demo),
              ),
              const Divider(height: 24),
              _ModeTile(
                title: 'Pool reel (Stratum)',
                subtitle:
                    'Connexion a un vrai pool Bitcoin avec ton adresse de portefeuille.',
                selected: m.mode == MinerMode.pool,
                onTap: locked ? null : () => m.setMode(MinerMode.pool),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (m.mode == MinerMode.pool) ...[
          const SectionLabel('Pool et portefeuille'),
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _wallet,
                  enabled: !locked,
                  style: mono(size: 13),
                  decoration: const InputDecoration(
                    labelText: 'Adresse Bitcoin (reception des gains)',
                    helperText: 'Uniquement une adresse publique. Jamais de cle privee.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _worker,
                  enabled: !locked,
                  decoration: const InputDecoration(labelText: 'Nom du worker'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _host,
                        enabled: !locked,
                        decoration: const InputDecoration(labelText: 'Serveur du pool'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _port,
                        enabled: !locked,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Port'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  enabled: !locked,
                  decoration: const InputDecoration(labelText: 'Mot de passe du pool'),
                ),
              ],
            ),
          ),
        ] else ...[
          const SectionLabel('Difficulte de la demo'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m.demoZeroBits} bits a zero demandes',
                    style: mono(size: 16, weight: FontWeight.w700)),
                Text(
                  'Environ ${_expectedHashes(m.demoZeroBits)} hachages par solution.',
                  style: mono(size: 12, color: AppColors.muted),
                ),
                Slider(
                  value: m.demoZeroBits.toDouble(),
                  min: 14,
                  max: 30,
                  divisions: 16,
                  activeColor: AppColors.amber,
                  onChanged: locked
                      ? null
                      : (v) => m.setDemoZeroBits(v.round()),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: locked
              ? null
              : () {
                  m.wallet = _wallet.text.trim();
                  m.workerName =
                      _worker.text.trim().isEmpty ? 'telephone' : _worker.text.trim();
                  m.poolHost = _host.text.trim();
                  m.poolPort = int.tryParse(_port.text.trim()) ?? m.poolPort;
                  m.poolPassword =
                      _password.text.trim().isEmpty ? 'x' : _password.text.trim();
                  m.saveSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reglages enregistres')),
                  );
                },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.amber,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Enregistrer les reglages',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Arrete le minage pour modifier les reglages.',
              style: mono(size: 12, color: AppColors.muted),
            ),
          ),
      ],
    );
  }

  String _expectedHashes(int bits) {
    final v = 1 << bits;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} millions de';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)} mille';
    return '$v';
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.amber : AppColors.muted,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: selected ? AppColors.ink : AppColors.muted,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
