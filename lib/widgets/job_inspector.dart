import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../core/stratum_job.dart';
import 'app_card.dart';

/// Affiche le travail reel envoye par le pool, champ par champ, avec
/// l'explication de ce que chaque valeur represente.
class JobInspector extends StatelessWidget {
  const JobInspector({super.key, required this.job});

  final JobSnapshot? job;

  @override
  Widget build(BuildContext context) {
    final j = job;
    if (j == null) {
      return AppCard(
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty_rounded,
                color: AppColors.muted, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Aucun travail recu pour l\'instant. Le pool en envoie un des '
                'que la connexion est etablie, puis un nouveau a chaque bloc.',
                style: mono(size: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('TRAVAIL ${j.jobId}', style: label())),
              Text('recu a ${_hhmmss(j.receivedAt)}',
                  style: mono(size: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 16),
          _Field(
            title: 'Bloc precedent',
            value: _short(j.prevHash),
            explain:
                'Le hash du dernier bloc valide. Il enchaine ton bloc au reste '
                'de la chaine : si ce bloc change, tout ton travail repart de zero.',
          ),
          _Field(
            title: 'Racine de Merkle',
            value: _short(j.merkleRoot),
            explain:
                'Le resume, en un seul hash, de toutes les transactions du bloc. '
                'Elle inclut la coinbase, la transaction qui te paierait.',
          ),
          _Field(
            title: 'Branches de Merkle',
            value: '${j.transactionsCount} niveaux',
            explain:
                'Ce que le pool t\'envoie pour reconstruire la racine sans avoir '
                'a telecharger les milliers de transactions du bloc.',
          ),
          _Field(
            title: 'Extranonce',
            value: '${j.extranonce1} / ${j.extranonce2}',
            explain:
                'Ton espace de recherche personnel. Le pool te donne la premiere '
                'moitie, l\'application fait varier la seconde : deux mineurs ne '
                'testent jamais les memes combinaisons.',
          ),
          _Field(
            title: 'Difficulte demandee',
            value: j.difficulty.toStringAsFixed(4),
            explain:
                'Le niveau exige par le pool pour compter une part. La difficulte '
                'du reseau, elle, se compte en dizaines de milliers de milliards.',
          ),
          _Field(
            title: 'Cible a battre',
            value: '${j.targetHex.substring(0, 20)}...',
            explain:
                'Le hash de ton en-tete doit etre numeriquement inferieur a ce '
                'nombre. Plus il commence par des zeros, plus c\'est rare.',
          ),
          _Field(
            title: 'Horodatage / nBits',
            value: '${j.nTime} / ${j.nBits}',
            explain:
                'L\'heure du bloc et la difficulte du reseau encodee. Ces deux '
                'champs font partie des 80 octets que l\'application hache.',
            last: true,
          ),
        ],
      ),
    );
  }

  static String _short(String hex) =>
      hex.length <= 24 ? hex : '${hex.substring(0, 12)}...${hex.substring(hex.length - 8)}';

  static String _hhmmss(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}

class _Field extends StatelessWidget {
  const _Field({
    required this.title,
    required this.value,
    required this.explain,
    this.last = false,
  });

  final String title;
  final String value;
  final String explain;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
              ),
              Expanded(
                child: Text(value,
                    style: mono(size: 12.5, color: AppColors.amber)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(explain,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}
