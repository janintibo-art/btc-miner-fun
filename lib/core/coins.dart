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
          'dediees. Le pari a echoue : les ASIC Scrypt existent depuis 2014.'),
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
    symbol: 'LTC',
    name: 'Litecoin',
    algorithm: PowAlgorithm.scrypt,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 2.5,
    blockReward: 6.25,
    blockchairSlug: 'litecoin',
    summary: 'Cree en 2011 pour etre plus rapide et resister aux machines '
        'dediees. Se mine aujourd\'hui en meme temps que Dogecoin.',
  ),
  Coin(
    symbol: 'DOGE',
    name: 'Dogecoin',
    algorithm: PowAlgorithm.scrypt,
    support: MiningSupport.wrongAlgorithm,
    blockMinutes: 1,
    blockReward: 10000,
    blockchairSlug: 'dogecoin',
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
