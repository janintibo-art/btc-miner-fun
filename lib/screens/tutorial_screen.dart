import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/app_card.dart';
import 'about_screen.dart';

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
        const SizedBox(height: 22),
        const SectionLabel('L\'application'),
        const AboutSection(),
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
    'Il te faut une adresse Bitcoin publique, commencant par bc1, 1 ou 3. Dans '
        'Reglages > Portefeuille Bitcoin, tu peux creer un coffre local BIP39/BIP84 '
        'ou utiliser l\'adresse publique d\'un portefeuille externe.\n\n'
        'La phrase de recuperation ne doit etre saisie que dans l\'ecran du coffre '
        'lors d\'une restauration, jamais dans les champs du pool ni envoyee a '
        'quelqu\'un.\n\n'
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
    'Ta marche personnelle',
    'Le calcul, lui, est impose : SHA-256, verifie par le pool, identique pour '
        'tout le monde. Impossible d\'inventer un raccourci.\n\n'
        'Ce qui n\'est impose par personne, c\'est l\'ordre dans lequel tu '
        'testes les quatre milliards de nonces. Le mode Signature transforme ta '
        'phrase en une permutation complete de cet espace : une suite qui passe '
        'par chaque nonce exactement une fois avant de boucler, dans un ordre '
        'que personne d\'autre n\'utilise.\n\n'
        'Sois lucide sur ce que ca apporte : rien, en probabilite. Tous les '
        'nonces se valent, et ton extranonce te separait deja des autres '
        'mineurs. Ce que ca garantit, c\'est qu\'aucune tentative n\'est '
        'gaspillee a retester un nonce deja vu, contrairement au tirage '
        'aleatoire ou un essai sur trois est un doublon au bout d\'un tour.\n\n'
        'L\'empreinte affichee dans Reglages est la carte d\'identite de ta '
        'marche : deux constantes, calculees a partir de ta phrase.',
    Icons.route_rounded,
  ),
  _ChapterData(
    'Ce que vaut vraiment ta puissance',
    'L\'onglet Convertir affiche le cours du bitcoin, mais surtout une '
        'estimation honnete : ta puissance divisee par celle du reseau entier, '
        'multipliee par les 144 blocs quotidiens et la recompense actuelle.\n\n'
        'Le chiffre obtenu est une esperance mathematique. En solo, tu ne '
        'toucheras pas un centieme d\'euro par jour : tu toucheras zero, '
        'pendant tres longtemps, avec une chance infime de toucher un bloc '
        'entier. C\'est une loterie, pas un salaire.\n\n'
        'La ligne la plus parlante est celle du delai moyen avant un bloc. '
        'Regarde-la une fois, elle vaut tous les discours.\n\n'
        'Le cours vient de CoinGecko et la puissance du reseau de '
        "mempool.space. Aucune inscription ni cle secrete n'est envoyee, mais "
        "ces services voient naturellement l'adresse IP de la requete. Hors "
        'ligne, tu peux fixer le cours a la main.',
    Icons.euro_rounded,
  ),
  _ChapterData(
    'Ton portefeuille, tes cles',
    'Un portefeuille ne contient pas de bitcoins : il contient les cles qui '
        'permettent de controler ceux inscrits sur la chaine. Perdre les cles, '
        'c\'est perdre les fonds, sans recours ni service client.\n\n'
        'Le coffre local cree une phrase BIP39 de douze mots sur ton appareil, '
        'puis derive une adresse Native SegWit BIP84. La phrase est chiffree par '
        'le stockage securise de la plateforme et n\'est jamais envoyee au pool.\n\n'
        'Ecris les douze mots sur papier avant de recevoir des fonds. Le chemin '
        "utilise est m/84'/0'/0'/0/0, afin de pouvoir restaurer la meme adresse "
        'dans un portefeuille compatible BIP84.',
    Icons.key_rounded,
  ),
  _ChapterData(
    'Regarder sans signer',
    'Une adresse Bitcoin est publique par nature : n\'importe qui peut '
        'consulter ce qu\'elle a recu, puisque toutes les transactions sont '
        'inscrites dans une chaine ouverte. C\'est ce que fait l\'onglet '
        "Convertir en interrogeant mempool.space. L'adresse consultee est "
        'donc transmise a cet explorateur via HTTPS.\n\n'
        'Le module de solde ne lit jamais la phrase de recuperation. Cette '
        'version du coffre conserve les cles et sait recevoir, mais ne signe '
        'volontairement aucune transaction de depense dans le mineur.\n\n'
        'Pour depenser, restaure les mots dans un portefeuille Bitcoin compatible '
        'BIP84. Un appareil compromis reste un risque : protege le telephone et '
        'garde surtout une sauvegarde papier hors ligne.',
    Icons.visibility_rounded,
  ),
  _ChapterData(
    'Le labo : tout observer',
    'L\'onglet Labo montre le minage sans filtre.\n\n'
        'Les 80 octets : l\'en-tete du travail en cours, colore champ par '
        'champ. Touche une couleur pour savoir ce qu\'elle contient. Le nonce '
        'defile en direct.\n\n'
        'La coinbase : la transaction que tu fabriques et qui te paierait. '
        'L\'application y lit la hauteur du bloc, la recompense convertie en '
        'euros, et le message que le pool laisse dans ses blocs.\n\n'
        'Le seuil d\'observation : un curseur qui decide a partir de quand une '
        'tentative est affichee. Il ne change rien au minage, mais il rend le '
        'hasard visible. L\'histogramme montre alors que chaque palier de '
        'difficulte apparait deux fois moins souvent que le precedent.\n\n'
        'La console : les lignes JSON echangees avec le pool, telles quelles.\n\n'
        'Le banc d\'avalanche : un bit change dans l\'entree, et environ 128 '
        'des 256 bits du hash changent. C\'est la demonstration en une seconde '
        'qu\'aucun raccourci n\'existe.',
    Icons.science_rounded,
  ),
  _ChapterData(
    'Dix mille univers, et un mode veille',
    'Le simulateur du labo applique la loi de Poisson : avec ta puissance '
        'reelle et celle du reseau, il fait vivre dix mille univers paralleles '
        'pendant cinquante ans chacun, et compte ceux ou tu as trouve un bloc.\n\n'
        'Le resultat sera presque toujours zero. Ce n\'est pas un defaut de la '
        'simulation : la probabilite exacte, affichee a cote, montre combien '
        'd\'univers il faudrait pour en voir un seul. La formule prend le '
        'relais la ou le tirage devient muet.\n\n'
        'Le mode veille, lui, transforme le telephone en console de reacteur : '
        'puissance, nonce en cours et trouvailles qui defilent. A poser sur le '
        'bureau pendant que ca calcule. Une touche sur l\'ecran pour revenir.',
    Icons.casino_rounded,
  ),
  _ChapterData(
    'Les autres monnaies',
    'L\'onglet Monnaies liste une vingtaine de chaines avec leur algorithme, '
        'leur difficulte reelle et ce que cette application peut en faire.\n\n'
        'Sept d\'entre elles utilisent le meme SHA-256d que Bitcoin : le moteur '
        'fonctionne tel quel, il suffit de viser un pool de cette chaine. Les '
        'autres demanderaient un second moteur de calcul.\n\n'
        'La comparaison des difficultes est instructive. Bitcoin Cash utilise '
        'exactement le meme algorithme que Bitcoin, mais sa difficulte est bien '
        'plus basse : les blocs y sont donc bien plus faciles a trouver. Ce '
        'n\'est pas un defaut de conception, c\'est le reflet de la puissance '
        'qui s\'y consacre. Et si la recompense vaut cent fois moins cher, le '
        'compte revient au meme.\n\n'
        'La difficulte se reajuste toujours pour maintenir l\'intervalle entre '
        'blocs. Elle mesure la concurrence, pas la qualite.\n\n'
        'Deux cas particuliers valent le detour : Namecoin, qui se mine en meme '
        'temps que Bitcoin sans calcul supplementaire, et Ethereum, qui a '
        'abandonne la preuve de travail en 2022 - liberant des millions de '
        'cartes graphiques qui ont peuple toutes les autres chaines.',
    Icons.currency_bitcoin_rounded,
  ),
  _ChapterData(
    'Deux algorithmes, neuf chaines',
    'Le moteur sait maintenant calculer deux familles de preuve de travail.\n\n'
        'SHA-256d, celui de Bitcoin : rapide, sans besoin de memoire. Il '
        'couvre Bitcoin, Bitcoin Cash, Bitcoin SV, eCash, DigiByte, Namecoin '
        'et Peercoin.\n\n'
        'Scrypt, celui de Litecoin et Dogecoin : chaque hachage remplit et '
        'relit 128 kio de memoire, ce qui le rend environ mille fois plus lent. '
        'Ne t\'etonne pas de passer de centaines de milliers de hachages par '
        'seconde a quelques centaines : c\'est normal, et c\'etait le but de '
        'ses concepteurs en 2011, rendre les machines dediees inutiles. Elles '
        'sont arrivees en 2014.\n\n'
        'Un detail invisible mais essentiel : la difficulte 1 n\'a pas la meme '
        'valeur partout. Chez Scrypt, la cible de reference est 65 536 fois '
        'plus facile. Le moteur en tient compte automatiquement, sinon toutes '
        'les parts seraient refusees.\n\n'
        'Choisis la chaine dans l\'onglet Monnaies : le pool et l\'algorithme '
        'se configurent seuls. Il ne reste qu\'a saisir une adresse de cette '
        'chaine - une adresse Bitcoin ne fonctionne nulle part ailleurs, et '
        'l\'application le verifie.',
    Icons.functions_rounded,
  ),
  _ChapterData(
    'Les petites chaines, et ou miner vraiment',
    'Le catalogue compte desormais une trentaine de chaines, dont une '
        'quinzaine de confidentielles. Certaines datent de 2013 et ont ete '
        'ressuscitees par leur communaute dix ans plus tard.\n\n'
        'Leur interet est reel : tres peu de puissance s\'y consacre, donc la '
        'difficulte y est mille a un million de fois plus basse que sur '
        'Bitcoin. C\'est la que tu verras enfin des parts acceptees, voire un '
        'bloc entier. Leur limite l\'est tout autant : peu de pools, peu '
        'd\'echanges possibles, et un avenir incertain.\n\n'
        'Le classement en tete de l\'onglet Monnaies tranche la question '
        'autrement. Il calcule, pour chaque chaine et a ta puissance reelle, '
        'l\'esperance de gain quotidien : difficulte, rythme des blocs, '
        'recompense et cours reunis dans un seul chiffre.\n\n'
        'Le resultat surprend souvent. Une difficulte basse ne suffit pas : si '
        'la recompense ne vaut rien, mille blocs faciles ne pesent pas un bloc '
        'difficile. C\'est exactement le calcul que font les fermes de minage '
        'professionnelles, en permanence.',
    Icons.leaderboard_rounded,
  ),
  _ChapterData(
    'Le fil des blocs',
    'Dans le labo, le fil affiche les derniers blocs trouves sur Bitcoin, avec '
        'le nom du pool qui les a trouves et le message laisse dans leur '
        'coinbase.\n\n'
        'C\'est le meme decodeur que celui de ton propre travail, applique aux '
        'blocs des autres. Chacun de ces blocs a ete trouve il y a quelques '
        'minutes par une machine reelle, quelque part - le plus souvent une '
        'ferme, parfois un particulier chanceux.\n\n'
        'Regarde les noms defiler : ils donnent une idee tres concrete de qui '
        'detient la puissance sur le reseau.',
    Icons.rss_feed_rounded,
  ),
  _ChapterData(
    'Chaleur, arret a distance, archives',
    'Le limiteur thermique surveille la temperature de la batterie une fois '
        'toutes les cinq secondes. A partir de 39 degres il reduit '
        'progressivement la cadence, a 43 il descend au minimum, et il rend '
        'tout des que l\'appareil refroidit. La baisse est graduelle et non '
        'par paliers : un reglage brutal ferait osciller la machine entre '
        'chaud et froid.\n\n'
        'La mesure vient du capteur de la batterie, le seul lisible sans '
        'permission particuliere. Il ne donne pas la temperature du '
        'processeur, mais sur un telephone les deux sont a quelques '
        'centimetres l\'un de l\'autre.\n\n'
        'La notification porte desormais un bouton Arreter : le minage se coupe '
        'sans ouvrir l\'application.\n\n'
        'Enfin, l\'onglet Historique permet d\'exporter toutes tes sessions au '
        'format CSV. Sur ordinateur, un fichier est ecrit dans ton dossier '
        'personnel ; sur telephone, le contenu part dans le presse-papiers, '
        'l\'acces aux fichiers y etant cloisonne.',
    Icons.thermostat_rounded,
  ),
  _ChapterData(
    'Creer ta propre monnaie',
    'Dans l\'onglet Monnaies, tu peux fabriquer ta chaine. Elle est reelle sur '
        'tous les plans techniques : en-tetes de 80 octets au format exact de '
        'Bitcoin, preuve de travail en double SHA-256, difficulte encodee au '
        'format compact et reajustee tous les dix blocs pour viser un bloc '
        'toutes les trente secondes, recompense divisee par deux a intervalle '
        'regulier, chainage verifiable bloc par bloc.\n\n'
        'Tu choisis son nom, son symbole, le message grave dans le bloc de '
        'genese - celui de Bitcoin citait un titre de journal du 3 janvier '
        '2009 - et sa difficulte de depart.\n\n'
        'Puis tu mines, et cette fois tu trouves des blocs. Vraiment. Chacun '
        'affiche son hash, son nonce et le nombre de tentatives qu\'il a '
        'fallu. Le bouton Verifier relit toute la chaine et refuse tout bloc '
        'qui n\'apporterait pas la preuve de travail qu\'il annonce.\n\n'
        'Et ta monnaie vaudra zero. Non par une limitation du programme, mais '
        'parce que personne d\'autre ne valide tes blocs, ne les echange, ne '
        'les accepte en paiement. C\'est exactement ce qui manque, et c\'est '
        'exactement ce qui fait la valeur des autres : pas la technique, mais '
        'le fait que des milliers d\'inconnus fassent tourner le meme code et '
        'reconnaissent les memes blocs.\n\n'
        'Cette lecon-la vaut tous les chapitres precedents.',
    Icons.auto_awesome_rounded,
  ),
  _ChapterData(
    'Partager ta chaine',
    'Une chaine sur un seul appareil reste un exercice. Avec un serveur, elle '
        'devient une petite economie : plusieurs personnes minent la meme '
        'chaine et se disputent chaque bloc.\n\n'
        'Le serveur ne mine pas et ne peut pas fabriquer de blocs. Il verifie '
        'la preuve de travail, impose la difficulte issue du reajustement et '
        'la recompense prevue par le bareme, et conserve la chaine qui '
        'totalise le plus de travail - la regle exacte de Bitcoin, et non le '
        'simple nombre de blocs.\n\n'
        'L\'application ne lui fait pas confiance pour autant : toute chaine '
        'recue est reverifiee ici, bloc par bloc, avant d\'etre adoptee.\n\n'
        'Il reste une difference de fond avec Bitcoin : il faut faire '
        'confiance a celui qui heberge le serveur pour ne pas effacer la '
        'chaine. Le pair a pair sert precisement a supprimer cette confiance. '
        'Le construire demanderait de gerer la decouverte des participants, la '
        'propagation des blocs et les fourches concurrentes - un autre projet, '
        'bien plus vaste.',
    Icons.hub_rounded,
  ),
  _ChapterData(
    'La genese, socle commun',
    'Deux chaines nees separement ne peuvent pas fusionner, meme si elles '
        'suivent les memes regles. Leur premier bloc differe, donc tout ce qui '
        'suit differe. C\'est vrai ici comme sur Bitcoin.\n\n'
        'Concretement : pour miner avec quelqu\'un, il faut partir de sa '
        'genese. L\'ecran de creation propose donc, avant toute chose, de '
        '**rejoindre** une chaine existante depuis son serveur. C\'est aussi le '
        'bon geste apres une reinstallation de l\'application : ta chaine n\'est '
        'pas perdue, elle est sur le serveur.\n\n'
        'Le serveur, lui, verrouille sa genese des le premier depot. Sans ce '
        'verrou, n\'importe qui pourrait miner cent blocs faciles dans son coin '
        'et remplacer la chaine de tout le monde en arrivant avec plus de '
        'travail cumule. Essai fait : une chaine rivale trois fois plus longue '
        'est refusee.',
    Icons.foundation_rounded,
  ),
  _ChapterData(
    'Quatre plaisirs gratuits',
    'Le certificat. Touche n\'importe quel bloc de ta chaine : tu obtiens sa '
        'carte d\'identite, hash compris, prete a etre capturee et envoyee. '
        'Le nombre de tentatives y figure - c\'est la seule mesure honnete de '
        'ta chance ce jour-la.\n\n'
        'La roulette, dans le labo. Les hachages defilent comme les rouleaux '
        'd\'une machine a sous, les zeros de tete s\'allument. Une machine a '
        'sous arrete ses rouleaux au bout de trois symboles ; il en faudrait '
        'dix-neuf alignes pour un bloc Bitcoin. Regarde tourner deux minutes, '
        'tu comprendras mieux qu\'avec n\'importe quel chiffre.\n\n'
        'Le championnat. Sur une chaine partagee, chacun grave son nom dans '
        'ses blocs, et le classement se calcule tout seul : qui en a trouve le '
        'plus, qui a eu le plus de chance. Le nom est inscrit dans la preuve '
        'de travail : impossible de le changer apres coup.\n\n'
        'Les sons. Un clic quand un bloc tombe, deux quand le serveur '
        'l\'accepte, une fanfare pour un record. Uniquement des sons systeme, '
        'rien de telecharge, et debrayable dans les reglages.',
    Icons.emoji_events_rounded,
  ),
  _ChapterData(
    'Quand une chaine de blocs ne sert a rien',
    'Une chaine de blocs sert a se passer d\'un tiers de confiance. C\'est sa '
        'seule raison d\'etre, et c\'est ce qui justifie tout ce qu\'elle '
        'coute : le minage, les cles privees, l\'irreversibilite des erreurs.\n\n'
        'Pour une monnaie de village geree par la mairie, ce tiers de '
        'confiance existe deja et personne ne veut s\'en passer. Une chaine y '
        'apporterait donc un cout enorme pour resoudre un probleme qu\'on n\'a '
        'pas - tout en imposant ses inconvenients : une phrase de recuperation '
        'perdue, et l\'argent l\'est aussi.\n\n'
        'L\'onglet Monnaies contient un registre local qui fonctionne '
        'reellement : des comptes, des paiements instantanes, et surtout un '
        'bouton d\'annulation. C\'est la difference la plus concrete avec ta '
        'chaine, ou une erreur est definitive.\n\n'
        'Aucun des deux modeles n\'est meilleur : ils repondent a des '
        'questions differentes. Bitcoin existe pour envoyer de l\'argent a un '
        'inconnu a l\'autre bout du monde sans permission. Une monnaie locale '
        'existe pour que la boulangerie du village garde la valeur sur place. '
        'Savoir lequel choisir vaut mieux que savoir coder les deux.',
    Icons.storefront_rounded,
  ),
  _ChapterData(
    'Envoyer des Tibo',
    'Le Tibo se transfere desormais vraiment. Chaque personne a une adresse, '
        'commencant par T, derivee de la phrase de recuperation de son '
        'portefeuille : la meme phrase redonne toujours la meme adresse, sur '
        'n\'importe quel appareil. Il n\'y a donc rien de plus a sauvegarder.\n\n'
        'Un virement est un texte signe : « de A vers B, tel montant, tel '
        'numero d\'ordre ». La signature se fait sur l\'appareil, avec la cle '
        'privee qui ne le quitte jamais. Le serveur verifie trois choses avant '
        'd\'accepter : que la signature est valable, que la cle publique '
        'correspond bien a l\'adresse emettrice, et que le solde suffit.\n\n'
        'Ce dernier point compte : sans lui, n\'importe qui pourrait signer '
        'avec sa propre cle en pretendant depenser l\'argent d\'un autre.\n\n'
        'Le numero d\'ordre empeche le rejeu. Sans lui, quelqu\'un qui '
        'intercepte un virement pourrait le renvoyer dix fois : la signature '
        'resterait valable, et le compte se viderait.\n\n'
        'Un virement depose attend dans une file, puis un mineur l\'inscrit '
        'dans un bloc. C\'est a ce moment qu\'il devient definitif : les '
        'virements entrent dans l\'empreinte du bloc, donc dans sa preuve de '
        'travail. Les modifier apres coup demanderait de refaire tout le '
        'travail.\n\n'
        'Ta recompense de minage va maintenant a ton adresse plutot que dans '
        'un compteur. Le Tibo est devenu une monnaie qui se possede et se '
        'donne - et qui ne vaut toujours rien.',
    Icons.send_rounded,
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
