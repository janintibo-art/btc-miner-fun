import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_theme.dart';
import '../core/address_validator.dart';
import '../core/bitcoin_utils.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';

/// Assistant portefeuille : le guide de creation, puis la verification reelle
/// de l'adresse saisie.
///
/// Cette application ne genere jamais de cles. Un bug dans un generateur de
/// portefeuille ne coute pas des parts de minage : il coute la totalite des
/// fonds, definitivement. Ce travail revient a des logiciels dedies et audites.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _controller = TextEditingController();
  AddressCheck _check = AddressCheck.empty;

  @override
  void initState() {
    super.initState();
    final m = context.read<MinerController>();
    _controller.text = m.wallet;
    _check = checkBitcoinAddress(m.wallet);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify(String value) {
    setState(() => _check = checkBitcoinAddress(value));
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.night,
        elevation: 0,
        title: const Text('Assistant portefeuille',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppCard(
              accent: AppColors.amber.withOpacity(0.4),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cette application ne cree pas de portefeuille, et c\'est '
                    'volontaire.',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, height: 1.5),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Un defaut dans le minage coute quelques parts. Un defaut '
                    'dans la generation de cles coute tout ce que le '
                    'portefeuille contient, sans retour possible. Ce travail '
                    'revient a des logiciels specialises, dont le code est '
                    'relu par des milliers de personnes.',
                    style: TextStyle(
                        fontSize: 13, height: 1.55, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionLabel('Creer ton portefeuille'),
            ..._steps.map((s) => _Step(step: s)),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CHOISIR SANS SE FAIRE PIEGER', style: label()),
                  const SizedBox(height: 10),
                  const Text(
                    'Les classements "top 10 des meilleurs wallets" sont le plus '
                    'souvent remuneres par les applications qu\'ils citent. '
                    'Le comparateur de bitcoin.org est neutre et indique, pour '
                    'chaque portefeuille, qui controle reellement les fonds et '
                    'si le code est ouvert.\n\n'
                    'Sur Android, les references etablies de longue date sont '
                    'BlueWallet, Blockstream Green et Electrum. Toutes sont '
                    'gratuites et open source.',
                    style: TextStyle(
                        fontSize: 13, height: 1.55, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Verifier ton adresse'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    style: mono(size: 13),
                    maxLines: 2,
                    minLines: 1,
                    onChanged: _verify,
                    decoration: const InputDecoration(
                      labelText: 'Colle ton adresse de reception',
                      helperText: 'Le code de controle est recalcule : une '
                          'seule lettre fausse sera detectee.',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Verdict(check: _check),
                  if (_check.valid) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: _controller.text.trim(),
                          size: 190,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Scanne ce code depuis un autre appareil',
                        style: mono(size: 11, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _controller.text.trim()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Adresse copiee')),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(color: AppColors.line),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copier'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: m.isActive
                                ? null
                                : () {
                                    m.wallet = _controller.text.trim();
                                    m.saveSettings();
                                    Navigator.pop(context);
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Utiliser'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SUIVRE CETTE ADRESSE', style: label()),
                  const SizedBox(height: 10),
                  const Text(
                    'L\'onglet Convertir affiche le solde de ton adresse en '
                    'consultant la chaine publique. Aucune cle n\'est stockee '
                    'ici : l\'application peut regarder, jamais depenser.',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: m.balanceLoading ? null : m.refreshBalance,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.amber,
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.travel_explore_rounded, size: 18),
                      label: Text(m.balanceLoading
                          ? 'Consultation...'
                          : 'Consulter le solde'),
                    ),
                  ),
                  if (m.balance != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      m.balance!.isEmpty
                          ? 'Aucun mouvement sur cette adresse.'
                          : 'Solde : ${formatBtc(m.balance!.totalBtc)} bitcoin',
                      style: mono(size: 12, color: AppColors.mint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              accent: AppColors.coral.withOpacity(0.35),
              child: const Text(
                'Regle absolue : ta phrase de recuperation ne se saisit jamais '
                'ailleurs que dans ton portefeuille. Ni ici, ni sur un site, ni '
                'a une personne qui propose de t\'aider. Cette application ne '
                'demande que ton adresse publique, celle qui sert a recevoir.',
                style: TextStyle(fontSize: 12.5, height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepData {
  const _StepData(this.number, this.title, this.body);
  final String number;
  final String title;
  final String body;
}

const _steps = <_StepData>[
  _StepData(
    '01',
    'Installer un portefeuille reconnu',
    'Telecharge-le depuis le magasin officiel ou le site du projet, jamais '
        'depuis un lien recu par message. Les fausses applications de '
        'portefeuille sont la premiere cause de vol.',
  ),
  _StepData(
    '02',
    'Noter la phrase de recuperation',
    'Douze ou vingt-quatre mots, dans l\'ordre, sur du papier. Pas de photo, '
        'pas de capture d\'ecran, pas de note dans le telephone : tout ce qui '
        'est numerique peut etre lu par une autre application.',
  ),
  _StepData(
    '03',
    'Verifier la sauvegarde',
    'Le portefeuille te demandera de ressaisir quelques mots. Fais-le '
        'serieusement : c\'est le seul moment ou tu decouvres une erreur de '
        'copie sans consequence.',
  ),
  _StepData(
    '04',
    'Recuperer une adresse de reception',
    'Cherche "Recevoir". Prends une adresse commencant par bc1 : les frais '
        'seront plus faibles le jour ou tu deplaceras des fonds.',
  ),
  _StepData(
    '05',
    'Eviter les adresses de plateforme',
    'Une adresse de site d\'echange ne t\'appartient pas vraiment, et '
        'certaines plateformes refusent les versements venant d\'un pool de '
        'minage. Utilise une adresse dont tu possedes la phrase.',
  ),
];

class _Step extends StatelessWidget {
  const _Step({required this.step});
  final _StepData step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(step.number,
                style: mono(
                    size: 15, weight: FontWeight.w700, color: AppColors.amber)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(step.body,
                      style: const TextStyle(
                          fontSize: 12.5, height: 1.5, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.check});
  final AddressCheck check;

  @override
  Widget build(BuildContext context) {
    final color = check.valid ? AppColors.mint : AppColors.coral;
    final neutral = check.message == AddressCheck.empty.message;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panelHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: neutral ? AppColors.line : color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                neutral
                    ? Icons.help_outline_rounded
                    : (check.valid
                        ? Icons.verified_rounded
                        : Icons.error_outline_rounded),
                size: 18,
                color: neutral ? AppColors.muted : color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  check.valid && check.type.isNotEmpty
                      ? check.type
                      : check.message,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: neutral ? AppColors.muted : color,
                  ),
                ),
              ),
            ],
          ),
          if (check.valid && check.detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(check.detail,
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}
