import 'dart:convert';
import 'dart:typed_data';

import 'bitcoin_utils.dart';

/// Une chaine personnelle, avec le meme mecanisme que Bitcoin.
///
/// Tout y est reel sauf une chose : le reseau. Les en-tetes font 80 octets et
/// respectent le format d'origine, la preuve de travail est un vrai double
/// SHA-256, la difficulte s'encode en format compact et se reajuste, et la
/// chaine se verifie bloc par bloc.
///
/// Ce qui manque - les autres participants - est precisement ce qui donne sa
/// valeur a une monnaie. D'ou une valeur de zero, assumee et affichee.

// ---------------------------------------------------------------------------
// Format compact de la difficulte, identique a celui de Bitcoin.
// ---------------------------------------------------------------------------

/// Decode les quatre octets de difficulte en cible complete.
BigInt targetFromBits(int bits) {
  final exponent = (bits >> 24) & 0xff;
  final mantissa = BigInt.from(bits & 0x007fffff);
  if (exponent <= 3) {
    return mantissa >> (8 * (3 - exponent));
  }
  return mantissa << (8 * (exponent - 3));
}

/// Encode une cible en quatre octets.
int bitsFromTarget(BigInt target) {
  if (target <= BigInt.zero) return 0;
  var bytes = _bigIntToBytes(target);
  if (bytes[0] > 0x7f) {
    bytes = Uint8List.fromList(<int>[0, ...bytes]);
  }
  final exponent = bytes.length;
  var mantissa = 0;
  for (var i = 0; i < 3; i++) {
    mantissa = (mantissa << 8) | (i < bytes.length ? bytes[i] : 0);
  }
  return (exponent << 24) | mantissa;
}

Uint8List _bigIntToBytes(BigInt value) {
  final result = <int>[];
  var v = value;
  final mask = BigInt.from(0xff);
  while (v > BigInt.zero) {
    result.insert(0, (v & mask).toInt());
    v = v >> 8;
  }
  return Uint8List.fromList(result.isEmpty ? <int>[0] : result);
}

Uint8List targetBytesFromBits(int bits) => bigIntTo32Bytes(targetFromBits(bits));

/// Difficulte lisible : combien de fois la cible est plus dure que celle de
/// reference de cette chaine.
double difficultyFromBits(int bits, int genesisBits) {
  final target = targetFromBits(bits);
  final reference = targetFromBits(genesisBits);
  if (target <= BigInt.zero) return 0;
  const scale = 1000000;
  return (reference * BigInt.from(scale) ~/ target).toDouble() / scale;
}

// ---------------------------------------------------------------------------
// Les blocs
// ---------------------------------------------------------------------------

class MyBlock {
  const MyBlock({
    required this.height,
    required this.version,
    required this.previousHash,
    required this.merkleRoot,
    required this.time,
    required this.bits,
    required this.nonce,
    required this.message,
    required this.reward,
    required this.hashesTried,
  });

  final int height;
  final int version;

  /// Hash du bloc precedent, en representation affichable.
  final String previousHash;

  /// Racine de Merkle : ici, le hash de la seule transaction du bloc, la
  /// coinbase qui te paie. Le mecanisme est identique, avec une transaction.
  final String merkleRoot;

  final int time;
  final int bits;
  final int nonce;

  /// Le texte inscrit dans la coinbase, comme les pools le font.
  final String message;

  final double reward;

  /// Nombre de tentatives qu'il a fallu pour trouver ce bloc.
  final int hashesTried;

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(time * 1000);

  /// L'en-tete de 80 octets, au format exact de Bitcoin.
  Uint8List header([int? overrideNonce]) {
    final bytes = Uint8List(80);
    final n = overrideNonce ?? nonce;
    bytes.setRange(0, 4, _le32(version));
    bytes.setRange(4, 36, reverseBytes(hexToBytes(previousHash)));
    bytes.setRange(36, 68, reverseBytes(hexToBytes(merkleRoot)));
    bytes.setRange(68, 72, _le32(time));
    bytes.setRange(72, 76, _le32(bits));
    bytes.setRange(76, 80, _le32(n));
    return bytes;
  }

  String get hash => bytesToHex(reverseBytes(sha256d(header())));

  static Uint8List _le32(int value) => Uint8List.fromList(<int>[
        value & 0xff,
        (value >> 8) & 0xff,
        (value >> 16) & 0xff,
        (value >> 24) & 0xff,
      ]);

  Map<String, dynamic> toJson() => {
        'h': height,
        'v': version,
        'p': previousHash,
        'm': merkleRoot,
        't': time,
        'b': bits,
        'n': nonce,
        'msg': message,
        'r': reward,
        'x': hashesTried,
      };

  factory MyBlock.fromJson(Map<String, dynamic> j) => MyBlock(
        height: j['h'] as int,
        version: j['v'] as int,
        previousHash: j['p'] as String,
        merkleRoot: j['m'] as String,
        time: j['t'] as int,
        bits: j['b'] as int,
        nonce: j['n'] as int,
        message: j['msg'] as String? ?? '',
        reward: (j['r'] as num).toDouble(),
        hashesTried: j['x'] as int? ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Les regles de la chaine
// ---------------------------------------------------------------------------

class ChainRules {
  const ChainRules({
    this.name = 'Tibo',
    this.symbol = 'TIBO',
    this.targetSeconds = 30,
    this.retargetInterval = 10,
    this.initialReward = 50,
    this.halvingInterval = 100,
    this.genesisBits = 0x1f00ffff,
    this.genesisMessage = 'Le premier bloc de ma monnaie',
  });

  final String name;
  final String symbol;

  /// Intervalle vise entre deux blocs.
  final int targetSeconds;

  /// Nombre de blocs entre deux reajustements de difficulte.
  final int retargetInterval;

  final double initialReward;

  /// Blocs entre deux divisions de la recompense, comme le halving de Bitcoin.
  final int halvingInterval;

  /// Difficulte de depart. 0x1f00ffff est tres facile : un bloc en quelques
  /// secondes sur un telephone.
  final int genesisBits;

  final String genesisMessage;

  double rewardAt(int height) {
    final halvings = height ~/ halvingInterval;
    if (halvings >= 64) return 0;
    return initialReward / (1 << halvings);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'symbol': symbol,
        'target': targetSeconds,
        'retarget': retargetInterval,
        'reward': initialReward,
        'halving': halvingInterval,
        'bits': genesisBits,
        'genesis': genesisMessage,
      };

  factory ChainRules.fromJson(Map<String, dynamic> j) => ChainRules(
        name: j['name'] as String? ?? 'Tibo',
        symbol: j['symbol'] as String? ?? 'TIBO',
        targetSeconds: j['target'] as int? ?? 30,
        retargetInterval: j['retarget'] as int? ?? 10,
        initialReward: (j['reward'] as num?)?.toDouble() ?? 50,
        halvingInterval: j['halving'] as int? ?? 100,
        genesisBits: j['bits'] as int? ?? 0x1f00ffff,
        genesisMessage: j['genesis'] as String? ?? 'Le premier bloc de ma monnaie',
      );
}

/// La chaine complete, en memoire.
class MyChain {
  MyChain({required this.rules, List<MyBlock>? blocks})
      : blocks = blocks ?? <MyBlock>[];

  final ChainRules rules;
  final List<MyBlock> blocks;

  bool get isEmpty => blocks.isEmpty;
  MyBlock? get tip => blocks.isEmpty ? null : blocks.last;
  int get height => blocks.length;

  /// Total detenu : la somme des recompenses, puisque rien n'est depense.
  double get balance =>
      blocks.fold(0.0, (sum, block) => sum + block.reward);

  int get totalHashes =>
      blocks.fold(0, (sum, block) => sum + block.hashesTried);

  /// Le bloc de genese : sa racine de Merkle vient du message fondateur, donc
  /// deux chaines aux messages differents divergent des le premier bloc.
  MyBlock createGenesis(DateTime now) {
    final root = bytesToHex(sha256d(utf8.encode(rules.genesisMessage)));
    return MyBlock(
      height: 0,
      version: 1,
      previousHash: '0' * 64,
      merkleRoot: root,
      time: now.millisecondsSinceEpoch ~/ 1000,
      bits: rules.genesisBits,
      nonce: 0,
      message: rules.genesisMessage,
      reward: rules.initialReward,
      hashesTried: 0,
    );
  }

  /// Difficulte du prochain bloc.
  ///
  /// Meme principe que Bitcoin : on compare le temps reellement mis pour le
  /// dernier lot de blocs au temps vise, et on corrige. Le facteur est borne
  /// pour eviter qu'un coup de chance ne fasse s'envoler la difficulte.
  int nextBits() {
    final last = tip;
    if (last == null) return rules.genesisBits;
    if (blocks.length % rules.retargetInterval != 0) return last.bits;
    if (blocks.length <= rules.retargetInterval) return last.bits;

    final first = blocks[blocks.length - rules.retargetInterval];
    var elapsed = last.time - first.time;
    final expected = rules.targetSeconds * rules.retargetInterval;
    if (elapsed <= 0) elapsed = 1;
    if (elapsed < expected ~/ 4) elapsed = expected ~/ 4;
    if (elapsed > expected * 4) elapsed = expected * 4;

    final target = targetFromBits(last.bits);
    final adjusted = target * BigInt.from(elapsed) ~/ BigInt.from(expected);
    final maximum = targetFromBits(rules.genesisBits);
    return bitsFromTarget(adjusted > maximum ? maximum : adjusted);
  }

  /// Prepare le bloc suivant, sans nonce valable : c'est le minage qui le
  /// trouvera.
  MyBlock prepareNext(DateTime now, String message) {
    final last = tip!;
    final payload = '${last.hash}|$message|${last.height + 1}';
    return MyBlock(
      height: last.height + 1,
      version: 1,
      previousHash: last.hash,
      merkleRoot: bytesToHex(sha256d(utf8.encode(payload))),
      time: now.millisecondsSinceEpoch ~/ 1000,
      bits: nextBits(),
      nonce: 0,
      message: message,
      reward: rules.rewardAt(last.height + 1),
      hashesTried: 0,
    );
  }

  /// Verifie la chaine entiere : chainage, hauteurs, horodatages, et surtout
  /// que chaque bloc apporte bien la preuve de travail qu'il annonce.
  ChainVerdict verify() {
    if (blocks.isEmpty) return const ChainVerdict(valid: true, checked: 0);

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      if (block.height != i) {
        return ChainVerdict(
            valid: false, checked: i, problem: 'hauteur incoherente au bloc $i');
      }

      if (i == 0) {
        if (block.previousHash != '0' * 64) {
          return const ChainVerdict(
              valid: false,
              checked: 0,
              problem: 'le bloc de genese ne doit succeder a rien');
        }
        continue;
      }

      final previous = blocks[i - 1];
      if (block.previousHash != previous.hash) {
        return ChainVerdict(
            valid: false,
            checked: i,
            problem: 'le bloc $i ne suit pas le precedent');
      }
      if (block.time < previous.time) {
        return ChainVerdict(
            valid: false, checked: i, problem: 'horodatage en arriere au bloc $i');
      }

      final hash = sha256d(block.header());
      if (!hashMeetsTarget(hash, targetBytesFromBits(block.bits))) {
        return ChainVerdict(
            valid: false,
            checked: i,
            problem: 'le bloc $i n\'atteint pas sa propre difficulte');
      }
    }

    return ChainVerdict(valid: true, checked: blocks.length);
  }

  String encode() => jsonEncode({
        'rules': rules.toJson(),
        'blocks': blocks.map((b) => b.toJson()).toList(),
      });

  static MyChain? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return MyChain(
        rules: ChainRules.fromJson(data['rules'] as Map<String, dynamic>),
        blocks: (data['blocks'] as List)
            .map((b) => MyBlock.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }
}

class ChainVerdict {
  const ChainVerdict({required this.valid, required this.checked, this.problem});

  final bool valid;
  final int checked;
  final String? problem;
}
