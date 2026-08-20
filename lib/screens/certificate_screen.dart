import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/my_chain.dart';

/// Le certificat d'un bloc : de quoi garder une trace, ou narguer ses amis.
///
/// Pas d'export d'image : sur Android, l'acces aux fichiers est cloisonne et
/// demanderait des permissions supplementaires pour un resultat identique a
/// une capture d'ecran. La page est donc concue pour etre capturee telle
/// quelle, et le texte reste copiable pour ceux qui preferent le partager
/// autrement.
class CertificateScreen extends StatelessWidget {
  const CertificateScreen({
    super.key,
    required this.block,
    required this.rules,
  });

  final MyBlock block;
  final ChainRules rules;

  String get _resume => 'Bloc ${block.height} de la chaine ${rules.name}\n'
      'Hash : ${block.hash}\n'
      'Nonce : ${block.nonce}\n'
      'Tentatives : ${formatCount(block.hashesTried)}\n'
      'Recompense : ${formatBtc(block.reward)} ${rules.symbol}\n'
      'Message : ${block.message}';

  @override
  Widget build(BuildContext context) {
    final d = block.dateTime;
    final date = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year} a '
        '${d.hour.toString().padLeft(2, '0')}h'
        '${d.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.abyss,
      appBar: AppBar(
        backgroundColor: AppColors.abyss,
        elevation: 0,
        title: const Text('Certificat de bloc',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _resume));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Certificat copie')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1206), Color(0xFF0B0E17)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.amber.withOpacity(.55), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withOpacity(.14),
                  blurRadius: 40,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD479), Color(0xFFC97A0B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amber.withOpacity(.5),
                        blurRadius: 26,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    rules.symbol.characters.first,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2A1A02),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('BLOC ${block.height}',
                    style: mono(
                        size: 30,
                        weight: FontWeight.w800,
                        color: AppColors.amberHot,
                        spacing: 2)),
                const SizedBox(height: 4),
                Text('chaine ${rules.name}',
                    style: mono(size: 12, color: AppColors.muted)),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: SelectableText(
                    block.hash,
                    textAlign: TextAlign.center,
                    style: mono(size: 10.5, color: AppColors.mint),
                  ),
                ),
                const SizedBox(height: 20),
                _Ligne('Trouve le', date),
                _Ligne('Tentatives', formatCount(block.hashesTried)),
                _Ligne('Nonce gagnant', '${block.nonce}'),
                _Ligne('Recompense',
                    '${formatBtc(block.reward)} ${rules.symbol}'),
                if (block.message.trim().isNotEmpty)
                  _Ligne('Message grave', block.message),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.panel.withOpacity(.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Ce bloc a demande ${formatCount(block.hashesTried)} '
                    'tentatives. Chacune etait un tirage independant : aucune '
                    'ne rapprochait de la suivante.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11.5, height: 1.5, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 14),
                Text('valeur : 0,00 € — et c\'est tres bien ainsi',
                    style: mono(size: 10, color: AppColors.dim)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.titre, this.valeur);
  final String titre;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(titre.toUpperCase(), style: label()),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(valeur,
                textAlign: TextAlign.right,
                style: mono(size: 12.5, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
