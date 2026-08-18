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
                'Cette application se connecte a un vrai pool et effectue le vrai '
                'travail de minage. Elle ne te rendra pas riche : un telephone '
                'represente une part infime du reseau. Elle sert a voir, avec de '
                'vraies donnees, comment Bitcoin fonctionne reellement.',
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
    'Un bloc Bitcoin commence par un en-tete de 80 octets : la version, le hash '
        'du bloc precedent, la racine de Merkle des transactions, l\'heure, la '
        'difficulte du reseau, et un nombre libre de 4 octets appele nonce.\n\n'
        'Miner, c\'est passer cet en-tete dans un double SHA-256 en changeant le '
        'nonce, encore et encore, jusqu\'a obtenir un resultat inferieur a une '
        'cible. Il n\'existe aucune astuce mathematique : c\'est de la force brute.\n\n'
        'L\'onglet Minage affiche cet en-tete en direct, champ par champ, pendant '
        'que l\'application le hache.',
    Icons.memory_rounded,
  ),
  _ChapterData(
    'Ce que fait le pool',
    'Seul, tu devrais telecharger la chaine entiere et construire toi-meme les '
        'blocs. Le pool fait ce travail et t\'envoie un resume par le protocole '
        'Stratum : c\'est le message mining.notify que tu vois passer dans le '
        'journal.\n\n'
        'Il te donne aussi un extranonce, ton espace de recherche personnel, pour '
        'que deux mineurs ne testent jamais les memes combinaisons. Puis il fixe '
        'une difficulte reduite : chaque solution atteignant ce niveau compte '
        'comme une "part", la preuve que tu travailles vraiment.',
    Icons.hub_rounded,
  ),
  _ChapterData(
    'Parts, difficulte, et ce qu\'il faut regarder',
    'Parts acceptees : les solutions validees par le pool. Sur un telephone, '
        'elles arrivent rarement, parfois jamais selon le pool choisi.\n\n'
        'Meilleure difficulte : la meilleure solution trouvee depuis le '
        'demarrage. C\'est le seul compteur qui bouge vraiment, et donc le plus '
        'interessant a suivre. Une valeur de 5000 signifie que ton hash etait '
        '5000 fois meilleur que la difficulte 1.\n\n'
        'Pour trouver un bloc, il faudrait atteindre la difficulte du reseau, '
        'qui se compte en dizaines de milliers de milliards.',
    Icons.insights_rounded,
  ),
  _ChapterData(
    'La verite sur les chances',
    'Une machine dediee (ASIC) calcule environ 200 000 milliards de hachages par '
        'seconde. Un telephone en calcule quelques centaines de milliers : un '
        'rapport de l\'ordre du milliard.\n\n'
        'Le reseau entier produit des centaines de milliards de milliards de '
        'hachages par seconde. La part d\'un telephone est si infime que '
        'l\'attente moyenne avant de trouver un bloc se compte en milliards '
        'd\'annees.\n\n'
        'Le travail effectue est pourtant exactement le meme que celui d\'une '
        'ferme de minage. C\'est ce qui rend l\'exercice interessant : tu vois '
        'le vrai protocole, avec de vraies donnees.',
    Icons.speed_rounded,
  ),
  _ChapterData(
    'Configurer l\'application',
    'Il te faut une adresse Bitcoin publique, commencant par bc1, 1 ou 3. Elle '
        'sert uniquement a recevoir : ne saisis jamais de cle privee ni de phrase '
        'de recuperation dans un logiciel de minage.\n\n'
        'Choisis ensuite un pool dans l\'onglet Reglages. Les pools classiques '
        'imposent une difficulte minimale hors de portee ; ceux prevus pour les '
        'petits appareils descendent assez bas pour que des parts apparaissent.\n\n'
        'Le nom du worker te permet de reconnaitre cet appareil sur le tableau '
        'de bord du pool.',
    Icons.tune_rounded,
  ),
  _ChapterData(
    'Lire le journal',
    'Chaque ligne correspond a un echange reel avec le pool :\n\n'
        'Abonne au pool : le pool a accepte la connexion et donne ton extranonce.\n'
        'Worker autorise : ton adresse est reconnue.\n'
        'Difficulte du pool : le niveau exige pour une part.\n'
        'Nouveau job : un nouveau bloc a miner, souvent apres qu\'un bloc vient '
        'd\'etre trouve quelque part dans le monde.\n'
        'Solution trouvee puis Part acceptee : ton hachage a paye.\n\n'
        'Si la connexion tombe, l\'application se reconnecte seule, avec un delai '
        'qui augmente a chaque tentative.',
    Icons.terminal_rounded,
  ),
  _ChapterData(
    'Coeurs, chaleur et batterie',
    'Le minage est un calcul pur : chaque coeur du processeur peut chercher des '
        'nonces en parallele, sur une plage differente. Doubler les coeurs double '
        'a peu pres la puissance de calcul.\n\n'
        'Mais un telephone n\'est pas refroidi. Au-dela de la moitie des coeurs, '
        'il chauffe, se bride tout seul, et la batterie fond. C\'est pourquoi le '
        'reglage par defaut n\'utilise que la moitie des coeurs, quatre au '
        'maximum.\n\n'
        'Pendant le minage, l\'ecran reste allume : c\'est necessaire pour que '
        'Android n\'endorme pas l\'application.',
    Icons.developer_board_rounded,
  ),
  _ChapterData(
    'Laisser tourner sans surveillance',
    'Trois reglages servent a miner longtemps sans abimer l\'appareil :\n\n'
        'L\'intensite reduit la cadence en intercalant des pauses. A 50 %, tu '
        'produis moitie moins de hachages mais l\'appareil reste tiede.\n\n'
        'L\'arret automatique coupe le minage apres un delai choisi.\n\n'
        'La file d\'attente garde les solutions trouvees pendant une coupure '
        'reseau et les envoie des le retour du pool. Celles qui visaient un '
        'travail perime sont abandonnees : une part ne vaut que pour le bloc '
        'auquel elle repond.\n\n'
        'Chaque session de plus de dix secondes est ensuite archivee dans '
        'l\'onglet Sessions, sur l\'appareil uniquement.',
    Icons.schedule_rounded,
  ),
  _ChapterData(
    'Miner ecran eteint',
    'Android suspend les applications quelques minutes apres l\'extinction de '
        'l\'ecran. Pour continuer a calculer, il faut un service de premier '
        'plan : c\'est le seul mecanisme autorise pour un travail long, et il '
        'impose une notification permanente.\n\n'
        'Cette notification n\'est pas une contrainte a subir mais une garantie : '
        'aucune application ne peut faire chauffer ton processeur en cachette. '
        'Elle affiche la puissance et les parts, et se met a jour toutes les dix '
        'secondes.\n\n'
        'Le service prend aussi un verrou processeur partiel, qui empeche la '
        'mise en veille profonde. Balayer l\'application dans la liste des '
        'taches arrete le minage et libere tout.',
    Icons.notifications_active_rounded,
  ),
  _ChapterData(
    'Pourquoi on ne peut pas tricher',
    'SHA-256 est une fonction a avalanche : changer un seul bit de l\'entree '
        'change en moyenne la moitie des bits de sortie. Un hash calcule a '
        'moitie n\'a donc aucune ressemblance avec le vrai. Aucun calcul '
        'approche n\'existe, et le pool recalcule tout avant d\'accepter une '
        'part : une solution approximative serait rejetee.\n\n'
        'Ce qui est possible, en revanche, c\'est de supprimer du travail '
        'inutile, sans jamais changer le resultat :\n\n'
        'Le midstate. L\'en-tete fait 80 octets, SHA-256 travaille par blocs de '
        '64, et le nonce ne se trouve que dans le second bloc. Le premier est '
        'donc identique pour des milliards de tentatives : on le calcule une '
        'fois par travail recu.\n\n'
        'Le rejet precoce. Les quatre premiers octets du hash suffisent presque '
        'toujours a condamner une tentative : inutile de serialiser les 32.\n\n'
        'L\'onglet Sessions te laisse mesurer les trois moteurs sur ton propre '
        'appareil, et verifie qu\'ils produisent bien le meme hash.',
    Icons.bolt_rounded,
  ),
  _ChapterData(
    'Compiler l\'APK et le .exe',
    'Le projet est compile par GitHub Actions, pas par ton telephone. A chaque '
        'envoi de code sur la branche main, GitHub construit :\n\n'
        '- BTCMinerFun-android-apk : le fichier a installer sur Android\n'
        '- BTCMinerFun-windows : le dossier contenant le .exe et ses bibliotheques\n\n'
        'Tu les recuperes dans l\'onglet Actions du depot, section Artifacts.',
    Icons.build_circle_rounded,
  ),
  _ChapterData(
    'Chaleur, batterie, honnetete',
    'Le minage fait tourner le processeur a fond : le telephone chauffe et la '
        'batterie se vide vite. Evite de miner longtemps en charge, et arrete des '
        'que l\'appareil devient chaud.\n\n'
        'Ne fais jamais tourner un mineur sur un appareil qui ne t\'appartient '
        'pas : sans accord explicite du proprietaire, c\'est illegal.',
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
