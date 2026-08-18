import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/app_card.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppCard(
          accent: AppColors.amber.withOpacity(0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A LIRE EN PREMIER', style: label()),
              const SizedBox(height: 10),
              const Text(
                'Cette application sert a comprendre le minage, pas a gagner de l\'argent. '
                'Un telephone produit quelques centaines de milliers de hachages par seconde ; '
                'le reseau Bitcoin en produit des centaines de milliards de milliards. '
                'La probabilite de trouver un bloc est si faible qu\'il faudrait, en moyenne, '
                'des milliards d\'annees.',
                style: TextStyle(height: 1.55, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Le tutoriel'),
        ..._chapters.map((c) => _Chapter(chapter: c)),
      ],
    );
  }
}

class _ChapterData {
  const _ChapterData(this.title, this.body, this.icon);
  final String title;
  final String body;
  final IconData icon;
}

const _chapters = <_ChapterData>[
  _ChapterData(
    'Le minage en une minute',
    'Miner, c\'est chercher un nombre (le "nonce") qui, ajoute a l\'en-tete du bloc, '
        'donne un resultat de double SHA-256 inferieur a une cible. Il n\'existe aucune '
        'astuce : on essaie des milliards de combinaisons au hasard.\n\n'
        'Le premier mineur du monde a trouver la bonne combinaison publie le bloc et '
        'recoit la recompense. Tous les autres recommencent a zero sur le bloc suivant.',
    Icons.memory_rounded,
  ),
  _ChapterData(
    'Pourquoi un telephone ne gagnera pas',
    'Une machine dediee (ASIC) calcule environ 200 000 milliards de hachages par seconde. '
        'Un telephone en calcule quelques centaines de milliers, soit un milliard de fois moins.\n\n'
        'Concretement : le telephone fait bien le meme travail, simplement il en fait une '
        'part infime. C\'est exactement pour cela que le mode demo existe : il abaisse la '
        'cible pour que tu vois des solutions apparaitre en quelques secondes et que tu '
        'comprennes le mecanisme.',
    Icons.speed_rounded,
  ),
  _ChapterData(
    'Etape 1 : un portefeuille',
    'Il te faut une adresse Bitcoin publique (elle commence par bc1, 1 ou 3). Elle sert '
        'uniquement a recevoir. Tu peux en creer une avec une application de portefeuille '
        'reconnue.\n\n'
        'Regle absolue : on ne saisit jamais de cle privee ni de phrase de recuperation '
        'dans un logiciel de minage. Cette application ne demande que l\'adresse publique.',
    Icons.account_balance_wallet_rounded,
  ),
  _ChapterData(
    'Etape 2 : choisir un pool',
    'Un pool regroupe des mineurs et distribue le travail. Les pools classiques imposent '
        'une difficulte minimale trop elevee pour un telephone.\n\n'
        'Les pools de type "solo" pour petits appareils (par exemple ceux utilises par les '
        'mineurs Bitaxe) acceptent des difficultes tres basses : ce sont les seuls ou tu '
        'verras peut-etre des parts acceptees. Renseigne le serveur et le port dans '
        'l\'onglet Reglages.',
    Icons.hub_rounded,
  ),
  _ChapterData(
    'Etape 3 : lancer et lire les compteurs',
    'Puissance de calcul : le nombre de hachages par seconde.\n'
        'Parts acceptees : les solutions validees par le pool.\n'
        'Meilleure difficulte : la meilleure solution trouvee depuis le demarrage. '
        'C\'est le vrai indicateur de progression quand les parts sont rares.\n\n'
        'Le journal en bas affiche tous les echanges avec le pool, ligne par ligne.',
    Icons.insights_rounded,
  ),
  _ChapterData(
    'Etape 4 : compiler l\'APK et le .exe',
    'Le projet est compile par GitHub Actions, pas par ton telephone. A chaque envoi de '
        'code sur la branche main, GitHub construit automatiquement :\n\n'
        '- BTCMinerFun-android-apk : le fichier a installer sur Android\n'
        '- BTCMinerFun-windows : le dossier contenant le .exe et ses bibliotheques\n\n'
        'Tu les recuperes dans l\'onglet Actions du depot, section Artifacts.',
    Icons.build_circle_rounded,
  ),
  _ChapterData(
    'Chaleur, batterie, honnetete',
    'Le minage fait tourner le processeur a fond : le telephone chauffe et la batterie '
        'se vide vite. Evite de miner en charge prolongee, et arrete des que l\'appareil '
        'devient chaud.\n\n'
        'Ne fais jamais tourner un mineur sur un appareil qui ne t\'appartient pas : sans '
        'accord explicite du proprietaire, c\'est illegal.',
    Icons.thermostat_rounded,
  ),
];

class _Chapter extends StatefulWidget {
  const _Chapter({required this.chapter});
  final _ChapterData chapter;

  @override
  State<_Chapter> createState() => _ChapterState();
}

class _ChapterState extends State<_Chapter> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Row(
                children: [
                  Icon(widget.chapter.icon, color: AppColors.amber, size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.chapter.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState:
                  _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 14, left: 34),
                child: Text(
                  widget.chapter.body,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.6, color: AppColors.muted),
                ),
              ),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
