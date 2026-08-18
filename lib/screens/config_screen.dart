import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/hash_mode.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _wallet = TextEditingController();
  final _worker = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _password = TextEditingController();
  bool _loaded = false;

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

  void _applyPreset(PoolPreset p) {
    setState(() {
      _host.text = p.host;
      _port.text = p.port.toString();
    });
  }

  void _save(MinerController m) {
    m.wallet = _wallet.text.trim();
    m.workerName =
        _worker.text.trim().isEmpty ? 'telephone' : _worker.text.trim();
    m.poolHost = _host.text.trim();
    m.poolPort = int.tryParse(_port.text.trim()) ?? m.poolPort;
    m.poolPassword =
        _password.text.trim().isEmpty ? 'x' : _password.text.trim();
    m.saveSettings();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m.walletLooksValid
            ? 'Reglages enregistres'
            : 'Enregistre, mais l\'adresse ne ressemble pas a une adresse Bitcoin'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();
    _sync(m);
    final locked = m.isActive;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const SectionLabel('Ou vont les gains'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _wallet,
                enabled: !locked,
                style: mono(size: 13),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Adresse Bitcoin',
                  helperText: 'Adresse publique uniquement. Jamais de cle privee '
                      'ni de phrase de recuperation.',
                  helperMaxLines: 3,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _worker,
                enabled: !locked,
                decoration: const InputDecoration(
                  labelText: 'Nom du worker',
                  helperText: 'Sert a reconnaitre cet appareil sur le tableau '
                      'de bord du pool.',
                  helperMaxLines: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Pool'),
        ...kPoolPresets.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              accent: _host.text == p.host
                  ? AppColors.amber.withOpacity(0.5)
                  : null,
              child: InkWell(
                onTap: locked ? null : () => _applyPreset(p),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _host.text == p.host
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 21,
                      color: _host.text == p.host
                          ? AppColors.amber
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('${p.host}:${p.port}',
                              style: mono(size: 11.5, color: AppColors.amber)),
                          const SizedBox(height: 6),
                          Text(p.note,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SectionLabel('Serveur (modifiable)'),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _host,
                      enabled: !locked,
                      style: mono(size: 13),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Serveur'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _port,
                      enabled: !locked,
                      style: mono(size: 13),
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
                decoration: const InputDecoration(
                  labelText: 'Mot de passe du pool',
                  helperText: 'La plupart des pools acceptent simplement x.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Puissance'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${m.effectiveThreads}',
                      style: mono(size: 30, weight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      m.effectiveThreads > 1 ? 'coeurs utilises' : 'coeur utilise',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('${m.availableCores} coeurs disponibles sur cet appareil',
                  style: mono(size: 11.5, color: AppColors.muted)),
              Slider(
                value: m.effectiveThreads.toDouble(),
                min: 1,
                max: m.availableCores.toDouble(),
                divisions: m.availableCores > 1 ? m.availableCores - 1 : null,
                activeColor: AppColors.amber,
                label: '${m.effectiveThreads}',
                onChanged: locked ? null : (v) => m.setThreads(v.round()),
              ),
              const Text(
                'Plus de coeurs, plus de hachages, mais aussi plus de chaleur et '
                'de batterie consommee. La valeur conseillee est la moitie des '
                'coeurs. Si le telephone chauffe, redescends.',
                style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
              ),
              const Divider(height: 30),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${m.intensity} %',
                      style: mono(size: 26, weight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('d\'intensite',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              Slider(
                value: m.intensity.toDouble(),
                min: 10,
                max: 100,
                divisions: 9,
                activeColor: AppColors.amber,
                label: '${m.intensity} %',
                onChanged: (v) => m.setIntensity(v.round()),
              ),
              const Text(
                'A 100 %, les coeurs tournent en continu. En dessous, le moteur '
                'marque une pause apres chaque lot de calculs : la puissance '
                'baisse d\'autant, la temperature aussi. Ce reglage s\'applique '
                'immediatement, meme pendant le minage.',
                style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Arret automatique'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [0, 15, 30, 60, 120].map((minutes) {
                  final selected = m.autoStopMinutes == minutes;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: locked ? null : (_) => m.setAutoStopMinutes(minutes),
                    backgroundColor: AppColors.panelHigh,
                    selectedColor: AppColors.amber,
                    side: const BorderSide(color: AppColors.line),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.black : AppColors.muted,
                    ),
                    label: Text(minutes == 0 ? 'Jamais' : '$minutes min'),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Le minage s\'arrete tout seul apres ce delai. Pratique pour '
                'laisser tourner sans vider la batterie ni chauffer la nuit.',
                style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Moteur de hachage'),
        AppCard(
          child: Column(
            children: [
              for (final mode in HashMode.values) ...[
                InkWell(
                  onTap: locked ? null : () => m.setHashMode(mode),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        m.hashMode == mode
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 21,
                        color: m.hashMode == mode
                            ? AppColors.amber
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mode.label,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: m.hashMode == mode
                                      ? AppColors.ink
                                      : AppColors.muted,
                                )),
                            const SizedBox(height: 4),
                            Text(mode.description,
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (mode != HashMode.values.last) const Divider(height: 24),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Les trois donnent le meme resultat : mesure-les dans l\'onglet '
          'Sessions pour voir l\'ecart sur ton appareil.',
          style: mono(size: 11.5, color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Ecran et arriere-plan'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: m.keepScreenOn,
                activeColor: AppColors.amber,
                onChanged: m.setKeepScreenOn,
                title: const Text('Garder l\'ecran allume',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'Utile pour surveiller les compteurs, mais l\'ecran consomme '
                  'souvent plus que le minage lui-meme.',
                  style: TextStyle(
                      fontSize: 12, height: 1.45, color: AppColors.muted),
                ),
              ),
              const Divider(height: 24),
              const Text(
                'Sur Android, un service de premier plan prend le relais des que '
                'le minage demarre : le calcul continue ecran eteint, et une '
                'notification permanente affiche la puissance et les parts. '
                'Fermer l\'application depuis la liste des taches arrete tout.',
                style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: locked ? null : () => _save(m),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.amber,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Enregistrer les reglages',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Arrete le minage pour modifier les reglages.',
                style: mono(size: 12, color: AppColors.muted)),
          ),
      ],
    );
  }
}
