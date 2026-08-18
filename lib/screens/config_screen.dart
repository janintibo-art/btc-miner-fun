import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/address_validator.dart';
import '../core/hash_mode.dart';
import '../core/platform_profile.dart';
import '../core/nonce_walker.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';
import 'wallet_screen.dart';

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
  final _signature = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _wallet.dispose();
    _worker.dispose();
    _host.dispose();
    _port.dispose();
    _password.dispose();
    _signature.dispose();
    super.dispose();
  }

  void _sync(MinerController m) {
    if (_loaded) return;
    _wallet.text = m.wallet;
    _worker.text = m.workerName;
    _host.text = m.poolHost;
    _port.text = m.poolPort.toString();
    _password.text = m.poolPassword;
    _signature.text = m.signaturePhrase;
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
    m.signaturePhrase = _signature.text.trim();
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
              );
              if (!mounted) return;
              // L'assistant peut avoir change l'adresse directement dans le
              // modele. Resynchroniser ce champ evite qu'un ancien texte ne
              // l'ecrase au prochain appui sur "Enregistrer".
              setState(() => _wallet.text = m.wallet);
            },
            leading: const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.amber),
            title: const Text('Portefeuille Bitcoin',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            subtitle: Text(
              m.wallet.trim().isEmpty
                  ? 'Cree un coffre local ou utilise une adresse externe.'
                  : (m.walletCheck.valid
                      ? m.walletCheck.type
                      : 'Adresse a verifier'),
              style: TextStyle(
                fontSize: 12,
                color: m.wallet.trim().isEmpty || m.walletCheck.valid
                    ? AppColors.muted
                    : AppColors.coral,
              ),
            ),
            trailing:
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 12),
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
              if (_wallet.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final check = checkBitcoinAddress(_wallet.text);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        check.valid
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        size: 15,
                        color: check.valid ? AppColors.mint : AppColors.coral,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          check.valid ? check.type : check.message,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color:
                                check.valid ? AppColors.mint : AppColors.coral,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
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
              Text(
                PlatformProfile.isDesktop
                    ? 'Cette machine est ventilee et branchee : la valeur '
                        'conseillee utilise tous les coeurs sauf un, garde pour '
                        'le systeme et l\'interface. Descends si tu veux '
                        'continuer a travailler pendant le minage.'
                    : 'Plus de coeurs, plus de hachages, mais aussi plus de '
                        'chaleur et de batterie consommee. La valeur conseillee '
                        'est la moitie des coeurs. Si le telephone chauffe, '
                        'redescends.',
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.muted),
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
        const SectionLabel('Exploration des nonces'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final strategy in NonceStrategy.values) ...[
                InkWell(
                  onTap: locked ? null : () => m.setNonceStrategy(strategy),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        m.nonceStrategy == strategy
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 21,
                        color: m.nonceStrategy == strategy
                            ? AppColors.amber
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(strategy.label,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: m.nonceStrategy == strategy
                                      ? AppColors.ink
                                      : AppColors.muted,
                                )),
                            const SizedBox(height: 4),
                            Text(strategy.description,
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
                if (strategy != NonceStrategy.values.last)
                  const Divider(height: 24),
              ],
              if (m.nonceStrategy == NonceStrategy.signature) ...[
                const Divider(height: 24),
                TextField(
                  controller: _signature,
                  enabled: !locked,
                  style: mono(size: 13),
                  onChanged: (v) => m.setSignaturePhrase(v),
                  decoration: const InputDecoration(
                    labelText: 'Ta phrase signature',
                    helperText: 'Laisse vide pour une phrase derivee de ton '
                        'adresse et du nom du worker.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.panelHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EMPREINTE DE TA MARCHE', style: label()),
                      const SizedBox(height: 8),
                      Text(m.signature.fingerprint,
                          style: mono(
                              size: 16,
                              weight: FontWeight.w700,
                              color: AppColors.amber)),
                      const SizedBox(height: 8),
                      Text(describeSignature(m.signature),
                          style: mono(size: 11, color: AppColors.muted)),
                      const SizedBox(height: 10),
                      const Text(
                        'Ces deux constantes definissent l\'ordre dans lequel '
                        'ton appareil visitera les nonces. Elles ne changent '
                        'pas tes chances : elles rendent ton chemin unique et '
                        'garantissent qu\'aucun nonce n\'est teste deux fois.',
                        style: TextStyle(
                            fontSize: 11.5, height: 1.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Sur ordinateur, ni l'ecran ni le service Android n'ont de sens :
        // le bloc entier disparait plutot que d'afficher un reglage inerte.
        if (PlatformProfile.canKeepScreenOn) ...[
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
                  'Sur Android, un service de premier plan prend le relais des '
                  'que le minage demarre : le calcul continue ecran eteint, et '
                  'une notification permanente affiche la puissance et les '
                  'parts. Fermer l\'application depuis la liste des taches '
                  'arrete tout.',
                  style:
                      TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
        if (PlatformProfile.isDesktop) ...[
          const SectionLabel('Raccourcis clavier'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Shortcut('F5', 'Demarrer ou arreter le minage'),
                _Shortcut('F11', 'Mode veille plein ecran'),
                _Shortcut('Ctrl + 1 a 6', 'Changer d\'onglet'),
              ],
            ),
          ),
        ],
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

/// Une ligne de raccourci clavier, affichee uniquement sur ordinateur.
class _Shortcut extends StatelessWidget {
  const _Shortcut(this.keys, this.description);

  final String keys;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.panelHigh,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(keys, style: mono(size: 11.5, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(description,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}
