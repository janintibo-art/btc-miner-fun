/// L'algorithme de preuve de travail d'une chaine.
///
/// C'est lui qui decide si cette application peut miner la monnaie ou non :
/// notre moteur ne sait faire qu'une chose, du double SHA-256.
enum PowAlgorithm {
  sha256d('SHA-256d',
      'Deux passages de SHA-256 sur l\'en-tete. L\'algorithme de Bitcoin, et '
          'le seul que cette application sait calculer.'),
  scrypt('Scrypt',
      'Concu pour demander beaucoup de memoire et resister aux machines '
          'dediees. Le pari a echoue : les ASIC Scrypt existent depuis 2014. '
          'Cette application sait le calculer, environ mille fois plus '
          'lentement que SHA-256d.'),
  randomx('RandomX',
      'Genere un programme aleatoire que le processeur doit executer. '
          'Volontairement hostile aux machines dediees, il reste le seul '
          'algorithme majeur ou un processeur ordinaire est competitif.'),
  ethash('Ethash / Etchash',
      'Exige de parcourir un fichier de plusieurs gigaoctets en memoire vive. '
          'Domaine des cartes graphiques.'),
  equihash('Equihash',
      'Un probleme de collisions gourmand en memoire, resolu par les cartes '
          'graphiques puis par des machines dediees.'),
  kawpow('KawPow',
      'Derive d\'Ethash, ajuste pour rester dans le domaine des cartes '
          'graphiques.'),
  x11('X11',
      'Onze fonctions de hachage enchainees. L\'enchainement n\'a pas empeche '
          'les machines dediees d\'arriver.'),
  kheavyhash('kHeavyHash',
      'Multiplication de matrices puis hachage. Concu pour des machines '
          'dediees economes en energie.'),
  autolykos('Autolykos',
      'Pense pour tenir dans la memoire d\'une carte graphique grand public.'),
  blake3('Blake3',
      'Fonction de hachage tres rapide, exploitee par des machines dediees.'),
  eaglesong('Eaglesong',
      'Algorithme simple, choisi pour que les machines dediees arrivent vite '
          'et que la puissance se stabilise.'),
  groestl('Groestl',
      'Fonction issue du concours qui a designe SHA-3. Rapide sur processeur, '
          'ce qui a longtemps garde cette chaine accessible.'),
  verthash('Verthash',
      'Exige un fichier de plusieurs gigaoctets genere depuis la chaine '
          'elle-meme. Concu pour rester hors de portee des machines dediees.'),
  firopow('FiroPoW',
      'Variante d\'Ethash ajustee pour les cartes graphiques grand public.'),
  blake2b('Blake2b',
      'Fonction de hachage tres rapide. Sa simplicite a fait arriver les '
          'machines dediees tres vite.'),
  none('Aucun',
      'La chaine ne repose plus sur la preuve de travail : il n\'y a plus rien '
          'a miner, la securite vient des jetons immobilises.');

  const PowAlgorithm(this.label, this.explanation);
  final String label;
  final String explanation;
}

/// Ce que cette application peut faire de la monnaie.
enum MiningSupport {
  supported('Minable ici',
      'Meme algorithme que Bitcoin : le moteur fonctionne tel quel, il suffit '
          'de pointer vers un pool de cette chaine.'),
  wrongAlgorithm('Autre algorithme',
      'Il faudrait ecrire un second moteur de calcul. Le protocole Stratum, '
          'lui, serait le meme.'),
  notMinable('Rien a miner',
      'Cette chaine n\'utilise pas la preuve de travail.');

  const MiningSupport(this.label, this.explanation);
  final String label;
  final String explanation;
}

/// Regles de validation des adresses d'une chaine.
class AddressRules {
  const AddressRules({
    this.bech32Hrp,
    this.base58Versions = const <int>[],
    this.note,
  });

  /// Prefixe des adresses modernes, par exemple "bc" pour Bitcoin.
  final String? bech32Hrp;

  /// Octets de version acceptes pour les adresses historiques.
  final List<int> base58Versions;

  final String? note;
}

/// Une monnaie du catalogue.
class Coin {
  const Coin({
    required this.symbol,
    required this.name,
    required this.algorithm,
    required this.support,
    required this.blockMinutes,
    required this.blockReward,
    required this.summary,
    this.blockchairSlug,
    this.pool,
    this.poolPort,
    this.addressRules,
    this.mergeMined = false,
    this.poolNote,
    this.obscure = false,
  });

  final String symbol;
  final String name;
  final PowAlgorithm algorithm;
  final MiningSupport support;

  /// Intervalle vise entre deux blocs, en minutes.
  final double blockMinutes;

  /// Recompense par bloc, dans l'unite de la chaine.
  final double blockReward;

  final String summary;

  /// Identifiant sur l'explorateur qui fournit les statistiques publiques.
  final String? blockchairSlug;

  final String? pool;
  final int? poolPort;
  final AddressRules? addressRules;

  /// Vrai si la chaine se mine en meme temps qu'une autre, sans travail
  /// supplementaire.
  final bool mergeMined;

  /// Precision sur le pool : ces adresses changent au fil du temps, et une
  /// petite chaine peut n'avoir qu'un ou deux pools actifs.
  final String? poolNote;

  /// Chaine confidentielle : peu de puissance, donc difficulte tres basse,
  /// mais aussi peu de pools, peu de liquidite et un avenir incertain.
  final bool obscure;

  bool get isMinableHere => support == MiningSupport.supported;
}

/// Le catalogue. Les chaines en SHA-256d sont utilisables immediatement ;
/// les autres sont la pour comprendre le paysage et comparer les difficultes.
const List<Coin> kCoins = <Coin>[
  Coin(
    symbol: 'BTC',
    name: 'Bitcoin',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 10,
    blockReward: 3.125,
    blockchairSlug: 'bitcoin',
    pool: 'public-pool.io',
    poolPort: 21496,
    addressRules: AddressRules(bech32Hrp: 'bc', base58Versions: [0x00, 0x05]),
    summary: 'L\'originale. La difficulte y est de loin la plus elevee de '
        'toutes les chaines, parce que c\'est la que va toute la puissance.',
  ),
  Coin(
    symbol: 'BCH',
    name: 'Bitcoin Cash',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 10,
    blockReward: 3.125,
    blockchairSlug: 'bitcoin-cash',
    pool: 'stratum.solomining.io',
    poolPort: 7011,
    addressRules: AddressRules(
      base58Versions: [0x00, 0x05],
      note: 'Saisis une adresse au format historique, commencant par 1 ou 3. '
          'Le format cashaddr, en bitcoincash:q..., n\'est pas encore verifie '
          'par cette application.',
    ),
    summary: 'Separee de Bitcoin en 2017 pour des blocs plus grands. Meme '
        'algorithme, donc meme materiel : la difficulte y est bien plus basse, '
        'mais la recompense vaut aussi bien moins cher.',
  ),
  Coin(
    symbol: 'BSV',
    name: 'Bitcoin SV',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 10,
    blockReward: 3.125,
    blockchairSlug: 'bitcoin-sv',
    addressRules: AddressRules(base58Versions: [0x00, 0x05]),
    summary: 'Separee de Bitcoin Cash en 2018. Tres peu de puissance sur le '
        'reseau, donc une difficulte tres basse.',
  ),
  Coin(
    symbol: 'XEC',
    name: 'eCash',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 10,
    blockReward: 3125000,
    blockchairSlug: 'ecash',
    addressRules: AddressRules(
      base58Versions: [0x00, 0x05],
      note: 'Le format moderne ecash:q... n\'est pas encore verifie ici.',
    ),
    summary: 'Ancienne Bitcoin ABC, redenominee : un bloc rapporte des '
        'millions d\'unites, mais chacune vaut une fraction de centime.',
  ),
  Coin(
    symbol: 'DGB',
    name: 'DigiByte',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 0.25,
    blockReward: 397,
    addressRules: AddressRules(bech32Hrp: 'dgb', base58Versions: [0x1E, 0x3F]),
    summary: 'Utilise cinq algorithmes en parallele, dont SHA-256d, chacun '
        'avec sa propre difficulte. Un bloc toutes les quinze secondes.',
  ),
  Coin(
    symbol: 'NMC',
    name: 'Namecoin',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 10,
    blockReward: 12.5,
    mergeMined: true,
    addressRules: AddressRules(base58Versions: [0x34, 0x0D]),
    summary: 'Premiere chaine derivee de Bitcoin, en 2011. Elle se mine en '
        'meme temps que Bitcoin, sans calcul supplementaire : le meme travail '
        'compte pour les deux chaines.',
  ),
  Coin(
    symbol: 'PPC',
    name: 'Peercoin',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 10,
    blockReward: 8,
    addressRules: AddressRules(base58Versions: [0x37, 0x75]),
    summary: 'Melange preuve de travail et preuve d\'enjeu depuis 2012. La '
        'part minable diminue au fil du temps.',
  ),
  Coin(
    symbol: 'MYR',
    name: 'Myriad',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 1,
    blockReward: 250,
    obscure: true,
    addressRules: AddressRules(base58Versions: [0x32, 0x09]),
    poolNote: 'Chaine confidentielle : verifie qu\'un pool SHA-256d est encore '
        'actif avant de lancer une session.',
    summary: 'Premiere chaine a avoir utilise cinq algorithmes en parallele, '
        'des 2014, chacun avec sa difficulte propre. Un mineur SHA-256d n\'y '
        'affronte que les autres mineurs SHA-256d, soit tres peu de monde.',
  ),
  Coin(
    symbol: 'ELA',
    name: 'Elastos',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 2,
    blockReward: 1.6,
    mergeMined: true,
    obscure: true,
    addressRules: AddressRules(base58Versions: [0x21, 0x12]),
    summary: 'Se mine conjointement avec Bitcoin depuis 2018 : une part '
        'notable de la puissance de Bitcoin la securise sans effort '
        'supplementaire.',
  ),
  Coin(
    symbol: 'SYS',
    name: 'Syscoin',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 1,
    blockReward: 42.1,
    mergeMined: true,
    obscure: true,
    addressRules: AddressRules(bech32Hrp: 'sys', base58Versions: [0x3F, 0x05]),
    summary: 'Egalement minee conjointement avec Bitcoin. Le meme hachage peut '
        'servir a Bitcoin, Namecoin, Elastos et Syscoin a la fois.',
  ),
  Coin(
    symbol: 'TRC',
    name: 'Terracoin',
    algorithm: PowAlgorithm.sha256d,
    support: MiningSupport.supported,
    blockMinutes: 2,
    blockReward: 20,
    obscure: true,
    addressRules: AddressRules(base58Versions: [0x00, 0x05]),
    summary: 'Lancee en 2012, une des plus anciennes chaines encore en vie. '
        'Tres peu de puissance, donc une difficulte parmi les plus basses de '
        'ce catalogue.',
  ),
  Coin(
    symbol: 'PEPE',
    name: 'Pepecoin',
    algorithm: PowAlgorithm.scrypt,
    support: MiningSupport.supported,
    blockMinutes: 1,
    blockReward: 500,
    mergeMined: true,
    obscure: true,
    addressRules: AddressRules(base58Versions: [0x38, 0x16]),
    summary: 'Chaine Scrypt de 2016, relancee depuis. Elle accepte le travail '
        'realise pour Dogecoin : mineurs Scrypt, le calcul compte double.',
  ),
  Coin(
    symbol: 'LKY',
    name: 'Luckycoin',
    algorithm: PowAlgorithm.scrypt,
    support: MiningSupport.supported,
    blockMinutes: 1,
    blockReward: 20,
    obscure: true,
    addressRules: AddressRules(base58Versions: [0x2F, 0x05]),
    summary: 'L\'ancetre direct de Dogecoin, dont elle a inspire le code en '
        '2013. Recompenses aleatoires : certains blocs rapportent bien plus '
        'que les autres.',
  ),
  Coin(
    symbol: 'BEL',
    name: 'Bellscoin',
    algorithm: PowAlgorithm.scrypt,
    support: MiningSupport.supported,
    blockMinutes: 1,
    blockReward: 50,
    obscure: true,
    addressRules: AddressRules(base58Versions: [0x19, 0x05]),
    summary: 'Nee en 2013, abandonnee, puis ressuscitee dix ans plus tard par '
        'sa communaute. Difficulte tres basse.',
  ),
  Coin(
    symbol: 'JKC',
    name: 'Junkcoin',
    algorithm: PowAlgorithm.scrypt,
    support: MiningSupport.supported,
    blockMinutes: 1,
    blockReward: 25,
    obscure: true,
    addressRules: AddressRules(base58Versions: [0x10, 0x05]),
    summary: 'Autre rescapee de 2013, remise en service recemment. Le genre de '
        'chaine ou un ordinateur ordinaire peut encore trouver un bloc.',
  ),
  Coin(
    symbol: 'DINGO',
    name: 'Dingocoin',
    algorithm: PowAlgorithm.scrypt,
    support: MiningSupport.supported,
    blockMinutes: 1,
    blockReward: 500000,
    obscure: true,
    addressRules: AddressRules(base58Versions: [0x1E, 0x1E]),
    summary: 'Derivee de Dogecoin, australienne. Puissance modeste, donc une '
        'difficulte accessible.',
  ),
  Coin(
    symbol: 'NVC',
    name: 'Novacoin',
    algorithm: PowAlgorithm.scrypt,
    support: MiningSupport.supported,
    blockMinutes: 10,
    blockReward: 2,
    obscure: true,
    addressRules: AddressRules(base58Versions: [0x08, 0x14]),
    summary: 'Melange preuve de travail et preuve d\'enjeu depuis 2013. La '
        'part minable se reduit a mesure que la chaine vieillit.',
  ),
  Coin(
    symbol: 'GRS',
    name: 'Groestlcoin',
    algorithm: PowAlgorithm.groestl,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 1,
    blockReward: 5,
    obscure: true,
    summary: 'Chaine de 2014, techniquement en avance sur son temps : elle a '
        'adopte SegWit avant Bitcoin. Algorithme Groestl, hors de portee du '
        'moteur actuel.',
  ),
  Coin(
    symbol: 'VTC',
    name: 'Vertcoin',
    algorithm: PowAlgorithm.verthash,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 2.5,
    blockReward: 12.5,
    obscure: true,
    summary: 'Change d\'algorithme des qu\'une machine dediee apparait. Elle '
        'l\'a fait trois fois. Un cas d\'ecole de la course entre mineurs et '
        'concepteurs.',
  ),
  Coin(
    symbol: 'FIRO',
    name: 'Firo',
    algorithm: PowAlgorithm.firopow,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 5,
    blockReward: 1.0625,
    obscure: true,
    summary: 'Chaine confidentielle au sens propre : elle efface le lien entre '
        'les pieces et leur historique. Algorithme reserve aux cartes '
        'graphiques.',
  ),
  Coin(
    symbol: 'SC',
    name: 'Siacoin',
    algorithm: PowAlgorithm.blake2b,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 10,
    blockReward: 30000,
    obscure: true,
    summary: 'Reseau de stockage decentralise. Le minage y securise un marche '
        'd\'espace disque plutot qu\'une simple monnaie.',
  ),
  Coin(
    symbol: 'HNS',
    name: 'Handshake',
    algorithm: PowAlgorithm.blake2b,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 10,
    blockReward: 2000,
    obscure: true,
    summary: 'Ne cherche pas a etre une monnaie mais un annuaire de noms de '
        'domaine sans autorite centrale.',
  ),
  Coin(
    symbol: 'LTC',
    name: 'Litecoin',
    algorithm: PowAlgorithm.scrypt,
    support: MiningSupport.supported,
    blockMinutes: 2.5,
    blockReward: 6.25,
    blockchairSlug: 'litecoin',
    pool: 'ltc.solomining.io',
    poolPort: 5030,
    addressRules: AddressRules(bech32Hrp: 'ltc', base58Versions: [0x30, 0x32]),
    summary: 'Cree en 2011 pour etre plus rapide et resister aux machines '
        'dediees. Se mine aujourd\'hui en meme temps que Dogecoin.',
  ),
  Coin(
    symbol: 'DOGE',
    name: 'Dogecoin',
    algorithm: PowAlgorithm.scrypt,
    support: MiningSupport.supported,
    blockMinutes: 1,
    blockReward: 10000,
    blockchairSlug: 'dogecoin',
    pool: 'doge.solomining.io',
    poolPort: 5040,
    addressRules: AddressRules(base58Versions: [0x1E, 0x16]),
    summary: 'Ne d\'une plaisanterie en 2013, il est devenu la deuxieme chaine '
        'en Scrypt. Son minage est adosse a celui de Litecoin.',
  ),
  Coin(
    symbol: 'XMR',
    name: 'Monero',
    algorithm: PowAlgorithm.randomx,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 2,
    blockReward: 0.6,
    blockchairSlug: 'monero',
    summary: 'La seule grande chaine ou un processeur ordinaire reste '
        'competitif : l\'algorithme est concu pour cela. Le candidat le plus '
        'serieux si un jour on ecrit un second moteur.',
  ),
  Coin(
    symbol: 'KAS',
    name: 'Kaspa',
    algorithm: PowAlgorithm.kheavyhash,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 0.017,
    blockReward: 55,
    summary: 'Un bloc par seconde grace a une structure en graphe plutot '
        'qu\'en chaine. Machines dediees indispensables.',
  ),
  Coin(
    symbol: 'ETC',
    name: 'Ethereum Classic',
    algorithm: PowAlgorithm.ethash,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 0.22,
    blockReward: 2.048,
    summary: 'A conserve la preuve de travail quand Ethereum l\'a abandonnee. '
        'Refuge des cartes graphiques depuis 2022.',
  ),
  Coin(
    symbol: 'RVN',
    name: 'Ravencoin',
    algorithm: PowAlgorithm.kawpow,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 1,
    blockReward: 2500,
    summary: 'Algorithme choisi explicitement pour rester accessible aux '
        'cartes graphiques grand public.',
  ),
  Coin(
    symbol: 'ERG',
    name: 'Ergo',
    algorithm: PowAlgorithm.autolykos,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 2,
    blockReward: 27,
    summary: 'Concu pour tenir dans la memoire d\'une carte graphique '
        'ordinaire, et le rester.',
  ),
  Coin(
    symbol: 'ZEC',
    name: 'Zcash',
    algorithm: PowAlgorithm.equihash,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 1.25,
    blockReward: 1.5625,
    blockchairSlug: 'zcash',
    summary: 'Transactions confidentielles par preuves a divulgation nulle. '
        'Machines dediees depuis 2018.',
  ),
  Coin(
    symbol: 'DASH',
    name: 'Dash',
    algorithm: PowAlgorithm.x11,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 2.6,
    blockReward: 1.1,
    blockchairSlug: 'dash',
    summary: 'Onze fonctions de hachage enchainees, pensees pour ralentir '
        'l\'arrivee des machines dediees. Elles sont arrivees quand meme.',
  ),
  Coin(
    symbol: 'CKB',
    name: 'Nervos',
    algorithm: PowAlgorithm.eaglesong,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 0.14,
    blockReward: 1917,
    summary: 'Algorithme volontairement simple : plutot que de retarder les '
        'machines dediees, le projet a choisi de les laisser venir vite.',
  ),
  Coin(
    symbol: 'ALPH',
    name: 'Alephium',
    algorithm: PowAlgorithm.blake3,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 0.27,
    blockReward: 2.2,
    summary: 'Chaine recente en Blake3, encore accessible aux cartes '
        'graphiques a ses debuts.',
  ),
  Coin(
    symbol: 'ETH',
    name: 'Ethereum',
    algorithm: PowAlgorithm.none,
    support: MiningSupport.notMinable,
    blockMinutes: 0.2,
    blockReward: 0,
    blockchairSlug: 'ethereum',
    summary: 'A abandonne la preuve de travail en septembre 2022. Du jour au '
        'lendemain, des millions de cartes graphiques n\'avaient plus rien a '
        'calculer : c\'est ce qui a peuple les autres chaines de cette liste.',
  ),
];

/// Les chaines que le moteur actuel sait miner.
List<Coin> get kMinableCoins =>
    kCoins.where((coin) => coin.isMinableHere).toList();

Coin? coinBySymbol(String symbol) {
  for (final coin in kCoins) {
    if (coin.symbol == symbol) return coin;
  }
  return null;
}
