import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_theme.dart';
import '../core/address_validator.dart';
import '../core/bitcoin_utils.dart';
import '../core/secret_screen_guard.dart';
import '../core/wallet_keys.dart';
import '../core/wallet_vault.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';

/// Portefeuille Bitcoin local non-custodial + choix d'une adresse externe.
///
/// Le coffre local cree/restaure une phrase BIP39 et derive l'adresse BIP84
/// m/84'/0'/0'/0/0. La phrase n'est jamais enregistree dans SharedPreferences,
/// jamais journalisee et n'est affichee qu'a la demande de l'utilisateur.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _addressController = TextEditingController();
  final _vault = const WalletVault();

  AddressCheck _check = AddressCheck.empty;
  LocalWalletInfo? _localWallet;
  bool _vaultLoading = true;
  bool _vaultBusy = false;
  String? _vaultError;

  @override
  void initState() {
    super.initState();
    final m = context.read<MinerController>();
    _addressController.text = m.wallet;
    _check = checkBitcoinAddress(m.wallet);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocalWallet());
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _verify(String value) {
    setState(() => _check = checkBitcoinAddress(value));
  }

  Future<void> _loadLocalWallet() async {
    if (!mounted) return;
    setState(() {
      _vaultLoading = true;
      _vaultError = null;
    });
    try {
      final info = await _vault.loadInfo();
      if (!mounted) return;
      setState(() {
        _localWallet = info;
        _vaultLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vaultLoading = false;
        _vaultError = 'Impossible d\'ouvrir le coffre securise sur cet appareil.';
      });
    }
  }

  Future<void> _useForMining(MinerController m, String address) async {
    if (m.isActive) return;
    m.wallet = address.trim();
    await m.saveSettings();
    if (!mounted) return;
    setState(() {
      _addressController.text = m.wallet;
      _check = checkBitcoinAddress(m.wallet);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adresse utilisee pour les gains de minage.')),
    );
  }

  Future<void> _createLocalWallet(MinerController m) async {
    if (_vaultBusy || m.isActive) return;
    setState(() {
      _vaultBusy = true;
      _vaultError = null;
    });
    try {
      final created = await _vault.create();
      await _useForMining(m, created.address);
      if (!mounted) return;
      setState(() {
        _localWallet = LocalWalletInfo(
          address: created.address,
          backupConfirmed: false,
        );
      });
      await _showRecoveryPhrase(created.mnemonic, firstCreation: true);
      await _loadLocalWallet();
    } catch (e) {
      // En cas d'ecriture partielle, loadInfo() peut recuperer le portefeuille
      // a partir de la phrase deja presente dans le coffre.
      try {
        await _loadLocalWallet();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _vaultError = 'Creation impossible : ${_friendlyVaultError(e)}');
    } finally {
      if (mounted) setState(() => _vaultBusy = false);
    }
  }

  Future<void> _restoreLocalWallet(MinerController m) async {
    if (_vaultBusy || m.isActive) return;
    final phrase = await _askRecoveryPhrase();
    if (!mounted || phrase == null) return;

    setState(() {
      _vaultBusy = true;
      _vaultError = null;
    });
    try {
      final restored = await _vault.restore(phrase);
      await _useForMining(m, restored.address);
      if (!mounted) return;
      setState(() {
        _localWallet = LocalWalletInfo(
          address: restored.address,
          backupConfirmed: true,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Portefeuille restaure et adresse activee.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _vaultError = 'Restauration impossible : ${_friendlyVaultError(e)}');
    } finally {
      if (mounted) setState(() => _vaultBusy = false);
    }
  }

  Future<void> _revealRecoveryPhrase() async {
    final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Afficher les mots secrets ?'),
            content: const Text(
              'Verifie que personne ne regarde ton ecran et que tu ne partages '
              'pas ton affichage. Quiconque possede ces mots controle les fonds.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Afficher'),
              ),
            ],
          ),
        ) ??
        false;
    if (!proceed || !mounted) return;

    try {
      final phrase = await _vault.revealMnemonic();
      if (!mounted) return;
      if (phrase == null) {
        setState(() => _vaultError = 'Aucune phrase dans le coffre.');
        return;
      }
      await _showRecoveryPhrase(phrase, firstCreation: false);
      await _loadLocalWallet();
    } catch (e) {
      if (!mounted) return;
      setState(() => _vaultError = 'Lecture impossible : ${_friendlyVaultError(e)}');
    }
  }

  Future<void> _showRecoveryPhrase(
    String mnemonic, {
    required bool firstCreation,
  }) async {
    await SecretScreenGuard.setProtected(true);
    try {
      if (!mounted) return;
      final words = mnemonic.split(' ');
      final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text(firstCreation
                  ? 'Sauvegarde tes 12 mots'
                  : 'Phrase de recuperation'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstCreation
                            ? 'Ecris ces mots sur papier, dans cet ordre. Ne fais '
                                'ni capture d\'ecran, ni photo, ni sauvegarde cloud.'
                            : 'Ne partage jamais ces mots. Ils suffisent a '
                                'restaurer et controler ce portefeuille.',
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.night,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.coral.withOpacity(0.5)),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            for (var i = 0; i < words.length; i++)
                              SizedBox(
                                width: 130,
                                child: Text(
                                  '${i + 1}. ${words[i]}',
                                  style: mono(size: 13, color: AppColors.ink),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Chemin de derivation : ${WalletKeys.derivationPath}',
                        style: mono(size: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Fermer'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('J\'ai note les mots'),
                ),
              ],
            ),
          ) ??
          false;
      if (confirmed) {
        // Un bouton "j'ai note" ne prouve rien : on demande de ressaisir trois
        // mots tires au sort. C'est le seul moment ou une erreur de recopie se
        // decouvre sans consequence.
        final verified = firstCreation ? await _verifyBackup(words) : true;
        if (verified) {
          await _vault.markBackupConfirmed();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Sauvegarde non verifiee. Recommence avant de recevoir des fonds.'),
            ),
          );
        }
      }
    } finally {
      await SecretScreenGuard.setProtected(false);
    }
  }

  /// Demande de ressaisir trois mots tires au hasard dans la phrase.
  Future<bool> _verifyBackup(List<String> words) async {
    final random = Random.secure();
    final positions = <int>{};
    while (positions.length < 3 && positions.length < words.length) {
      positions.add(random.nextInt(words.length));
    }
    final ordered = positions.toList()..sort();
    final controllers = {
      for (final index in ordered) index: TextEditingController(),
    };

    try {
      final ok = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              String? error;
              return StatefulBuilder(
                builder: (context, setInnerState) => AlertDialog(
                  title: const Text('Verifie ta sauvegarde'),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reprends ton papier et saisis les mots demandes. '
                            'Une erreur de recopie decouverte maintenant ne '
                            'coute rien ; decouverte plus tard, elle coute tout.',
                            style: TextStyle(height: 1.5, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          for (final index in ordered)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                controller: controllers[index],
                                autocorrect: false,
                                enableSuggestions: false,
                                style: mono(size: 14),
                                decoration: InputDecoration(
                                  labelText: 'Mot numero ${index + 1}',
                                ),
                              ),
                            ),
                          if (error != null)
                            Text(error!,
                                style: const TextStyle(
                                    color: AppColors.coral, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Plus tard'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final wrong = ordered.where((index) =>
                            controllers[index]!.text.trim().toLowerCase() !=
                            words[index]);
                        if (wrong.isEmpty) {
                          Navigator.pop(context, true);
                        } else {
                          setInnerState(() => error =
                              'Ces mots ne correspondent pas. Verifie ta copie '
                              'papier, l\'ordre compte.');
                        }
                      },
                      child: const Text('Verifier'),
                    ),
                  ],
                ),
              );
            },
          ) ??
          false;
      return ok;
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Future<String?> _askRecoveryPhrase() async {
    final controller = TextEditingController();
    await SecretScreenGuard.setProtected(true);
    try {
      if (!mounted) return null;
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          String? error;
          return StatefulBuilder(
            builder: (context, setInnerState) => AlertDialog(
              title: const Text('Restaurer une phrase BIP39 (anglais)'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saisis ta phrase existante en anglais, sans passphrase '
                      'BIP39 additionnelle. Elle reste sur cet appareil et sert '
                      'a rederiver la meme adresse de reception.',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      maxLines: 5,
                      minLines: 3,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.text,
                      style: mono(size: 13),
                      decoration: InputDecoration(
                        labelText: '12, 15, 18, 21 ou 24 mots anglais',
                        errorText: error,
                        errorMaxLines: 3,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final normalized = WalletKeys.normalizeMnemonic(controller.text);
                    if (!WalletKeys.isValidMnemonic(normalized)) {
                      setInnerState(() => error = 'Phrase BIP39 invalide ou mots dans le mauvais ordre.');
                      return;
                    }
                    Navigator.pop(context, normalized);
                  },
                  child: const Text('Restaurer'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      controller.dispose();
      await SecretScreenGuard.setProtected(false);
    }
  }

  Future<void> _deleteLocalWallet(MinerController m) async {
    if (_vaultBusy || m.isActive || _localWallet == null) return;
    final backupConfirmed = _localWallet!.backupConfirmed;
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer le coffre local ?'),
            content: Text(
              backupConfirmed
                  ? 'La phrase sera effacee de cet appareil. Verifie que ta sauvegarde papier est lisible avant de continuer.'
                  : 'ATTENTION : tu n\'as pas confirme la sauvegarde des mots. Sans ces mots, supprimer le coffre peut rendre les fonds definitivement inaccessibles.',
              style: const TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm || !mounted) return;

    setState(() => _vaultBusy = true);
    try {
      final localAddress = _localWallet!.address;
      await _vault.deleteWallet();
      if (m.wallet.trim() == localAddress) {
        m.wallet = '';
        await m.saveSettings();
      }
      if (!mounted) return;
      setState(() {
        _localWallet = null;
        _addressController.text = m.wallet;
        _check = checkBitcoinAddress(m.wallet);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coffre local supprime de cet appareil.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _vaultError = 'Suppression impossible : ${_friendlyVaultError(e)}');
    } finally {
      if (mounted) setState(() => _vaultBusy = false);
    }
  }

  String _friendlyVaultError(Object error) {
    if (error is FormatException) return error.message.toString();
    if (error is StateError) return error.message.toString();
    return 'stockage securise indisponible ou erreur cryptographique.';
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.night,
        elevation: 0,
        title: const Text('Portefeuille Bitcoin',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppCard(
              accent: AppColors.amber.withOpacity(0.45),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ton coffre, tes cles',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Le portefeuille local cree une phrase de recuperation BIP39 '
                    'sur ton appareil et une adresse Native SegWit bc1q. Les '
                    'bitcoins restent sur la blockchain : la phrase est ce qui '
                    'donne le controle des fonds.',
                    style: TextStyle(fontSize: 12.8, height: 1.55, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionLabel('Mon coffre local'),
            if (_vaultLoading)
              const AppCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (_localWallet == null)
              _buildCreateCard(m)
            else
              _buildLocalWalletCard(m, _localWallet!),
            if (_vaultError != null) ...[
              const SizedBox(height: 10),
              AppCard(
                accent: AppColors.coral.withOpacity(0.45),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.coral),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _vaultError!,
                        style: const TextStyle(fontSize: 12.5, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            const SectionLabel('Utiliser une autre adresse'),
            _buildExternalAddressCard(m),
            const SizedBox(height: 20),
            AppCard(
              accent: AppColors.coral.withOpacity(0.35),
              child: const Text(
                'SECURITE : personne ne doit connaitre ta phrase de recuperation. '
                'BTC Miner Fun ne l\'envoie pas au pool ni a l\'explorateur. '
                'Cette version sait recevoir et conserver les cles, mais ne '
                'signe pas encore de transaction de depense. Pour depenser, '
                'restaure la phrase dans un portefeuille Bitcoin compatible BIP84.',
                style: TextStyle(fontSize: 12.5, height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard(MinerController m) {
    final disabled = _vaultBusy || m.isActive;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AUCUN PORTEFEUILLE LOCAL', style: label()),
          const SizedBox(height: 10),
          const Text(
            'Tu peux en creer un ici ou restaurer une phrase BIP39 que tu '
            'possedes deja. La creation se fait localement : aucun secret '
            'n\'est inclus dans le code source ou le ZIP.',
            style: TextStyle(fontSize: 12.8, height: 1.55, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: disabled ? null : () => _createLocalWallet(m),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text(_vaultBusy ? 'Preparation...' : 'Creer mon portefeuille'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: disabled ? null : () => _restoreLocalWallet(m),
              icon: const Icon(Icons.settings_backup_restore_rounded),
              label: const Text('Restaurer avec mes mots'),
            ),
          ),
          if (m.isActive) ...[
            const SizedBox(height: 10),
            const Text(
              'Arrete le minage avant de changer l\'adresse de paiement.',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocalWalletCard(MinerController m, LocalWalletInfo info) {
    final isActiveAddress = m.wallet.trim() == info.address;
    return AppCard(
      accent: (info.backupConfirmed ? AppColors.mint : AppColors.coral)
          .withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                info.backupConfirmed
                    ? Icons.verified_user_rounded
                    : Icons.warning_amber_rounded,
                color: info.backupConfirmed ? AppColors.mint : AppColors.coral,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info.backupConfirmed
                      ? 'Sauvegarde de recuperation confirmee'
                      : 'Sauvegarde des 12 mots a confirmer',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('ADRESSE BIP84', style: label()),
          const SizedBox(height: 7),
          SelectableText(info.address, style: mono(size: 12.5)),
          const SizedBox(height: 6),
          Text(info.derivationPath, style: mono(size: 10.5, color: AppColors.muted)),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: info.address,
                size: 190,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: info.address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Adresse copiee')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copier'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: m.isActive || isActiveAddress
                      ? null
                      : () => _useForMining(m, info.address),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.black,
                  ),
                  icon: Icon(isActiveAddress
                      ? Icons.check_rounded
                      : Icons.bolt_rounded),
                  label: Text(isActiveAddress ? 'Actif' : 'Pour miner'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _vaultBusy ? null : _revealRecoveryPhrase,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.coral),
              icon: const Icon(Icons.key_rounded),
              label: const Text('Afficher mes mots de recuperation'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: m.balanceLoading
                  ? null
                  : () => m.refreshBalance(info.address),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.mint),
              icon: const Icon(Icons.travel_explore_rounded),
              label: Text(m.balanceLoading ? 'Consultation...' : 'Consulter le solde'),
            ),
          ),
          if (m.balanceError != null) ...[
            const SizedBox(height: 10),
            Text(m.balanceError!, style: mono(size: 11.5, color: AppColors.coral)),
          ],
          if (m.balance != null && m.balance!.address == info.address) ...[
            const SizedBox(height: 10),
            Text(
              m.balance!.isEmpty
                  ? 'Aucun mouvement sur cette adresse.'
                  : 'Solde : ${formatBtc(m.balance!.totalBtc)} bitcoin',
              style: mono(size: 12, color: AppColors.mint),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: AppColors.line),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: m.isActive || _vaultBusy ? null : () => _deleteLocalWallet(m),
            style: TextButton.styleFrom(foregroundColor: AppColors.coral),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Supprimer le coffre de cet appareil'),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalAddressCard(MinerController m) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tu peux toujours miner vers un portefeuille externe. Ici, saisis '
            'uniquement une adresse publique de reception.',
            style: TextStyle(fontSize: 12.8, height: 1.5, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _addressController,
            style: mono(size: 13),
            maxLines: 2,
            minLines: 1,
            enabled: !m.isActive,
            onChanged: _verify,
            decoration: const InputDecoration(
              labelText: 'Adresse Bitcoin publique',
              helperText: 'Jamais de cle privee ni de phrase de recuperation dans ce champ.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 14),
          _Verdict(check: _check),
          if (_check.valid) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _addressController.text.trim()),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Adresse copiee')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copier'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: m.isActive
                        ? null
                        : () => _useForMining(m, _addressController.text),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: Colors.black,
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
          color: neutral ? AppColors.line : color.withOpacity(0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            neutral
                ? Icons.help_outline_rounded
                : (check.valid
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded),
            color: neutral ? AppColors.muted : color,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.valid ? check.type : check.message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: check.valid ? FontWeight.w700 : FontWeight.w500,
                    color: neutral ? AppColors.muted : color,
                  ),
                ),
                if (check.valid && check.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    check.message,
                    style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
