import 'dart:typed_data';

import 'bitcoin_utils.dart';

/// Un travail ("job") envoye par le pool via mining.notify.
class StratumJob {
  StratumJob({
    required this.jobId,
    required this.prevHash,
    required this.coinb1,
    required this.coinb2,
    required this.merkleBranch,
    required this.version,
    required this.nBits,
    required this.nTime,
    required this.cleanJobs,
  });

  final String jobId;
  final String prevHash;
  final String coinb1;
  final String coinb2;
  final List<String> merkleBranch;
  final String version;
  final String nBits;
  final String nTime;
  final bool cleanJobs;

  factory StratumJob.fromNotify(List<dynamic> p) {
    return StratumJob(
      jobId: p[0] as String,
      prevHash: p[1] as String,
      coinb1: p[2] as String,
      coinb2: p[3] as String,
      merkleBranch: (p[4] as List).map((e) => e.toString()).toList(),
      version: p[5] as String,
      nBits: p[6] as String,
      nTime: p[7] as String,
      cleanJobs: p.length > 8 && p[8] == true,
    );
  }

  /// Racine de Merkle : la coinbase que nous fabriquons, puis les branches
  /// fournies par le pool. Elle resume toutes les transactions du bloc.
  Uint8List merkleRootFor(String extranonce1, String extranonce2) {
    final coinbase = hexToBytes(coinb1 + extranonce1 + extranonce2 + coinb2);
    return merkleRootFromBranch(sha256d(coinbase), merkleBranch);
  }

  /// En-tete de bloc de 80 octets. Le nonce (4 derniers octets) reste a zero :
  /// c'est le moteur de hachage qui l'incrementera des milliards de fois.
  Uint8List headerFor(Uint8List merkleRoot) {
    final header = Uint8List(80);
    header.setRange(0, 4, reverseBytes(hexToBytes(version)));
    header.setRange(4, 36, swapEndianWords(hexToBytes(prevHash)));
    header.setRange(36, 68, merkleRoot);
    header.setRange(68, 72, reverseBytes(hexToBytes(nTime)));
    header.setRange(72, 76, reverseBytes(hexToBytes(nBits)));
    return header;
  }
}

/// Photographie du travail en cours, affichee dans l'inspecteur.
class JobSnapshot {
  JobSnapshot({
    required this.jobId,
    required this.prevHash,
    required this.merkleRoot,
    required this.version,
    required this.nBits,
    required this.nTime,
    required this.extranonce1,
    required this.extranonce2,
    required this.targetHex,
    required this.difficulty,
    required this.transactionsCount,
    required this.receivedAt,
  });

  final String jobId;
  final String prevHash;
  final String merkleRoot;
  final String version;
  final String nBits;
  final String nTime;
  final String extranonce1;
  final String extranonce2;
  final String targetHex;
  final double difficulty;
  final int transactionsCount;
  final DateTime receivedAt;
}

/// Une unite de travail prete a etre envoyee au moteur de hachage.
class WorkPackage {
  WorkPackage({
    required this.jobId,
    required this.header,
    required this.target,
    required this.extranonce2,
    required this.nTime,
    required this.startNonce,
  });

  final String jobId;
  final Uint8List header;
  final Uint8List target;
  final String extranonce2;
  final String nTime;
  final int startNonce;

  Map<String, dynamic> toMap({int offset = 0, int stride = 1}) => {
        'type': 'work',
        'jobId': jobId,
        'header': header,
        'target': target,
        'extranonce2': extranonce2,
        'ntime': nTime,
        'startNonce': startNonce,
        'offset': offset,
        'stride': stride,
      };
}

/// Une solution trouvee par le moteur.
class FoundShare {
  FoundShare({
    required this.jobId,
    required this.extranonce2,
    required this.nTime,
    required this.nonce,
    required this.hashHex,
    required this.difficulty,
  });

  final String jobId;
  final String extranonce2;
  final String nTime;
  final int nonce;
  final String hashHex;
  final double difficulty;

  /// Le nonce se soumet au pool en big endian.
  String get nonceHex => nonce.toRadixString(16).padLeft(8, '0');
}
