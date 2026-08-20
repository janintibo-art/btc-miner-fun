import 'my_chain.dart';

/// Le palmares d'un mineur sur une chaine.
///
/// L'identite du mineur est le message qu'il inscrit dans ses blocs. Ce n'est
/// pas un compte, et rien n'empeche deux personnes de choisir le meme texte -
/// mais c'est le seul champ que la preuve de travail engage reellement, donc
/// le seul qui ne puisse pas etre falsifie apres coup.
class MinerScore {
  const MinerScore({
    required this.name,
    required this.blocks,
    required this.totalAttempts,
    required this.bestBlock,
    required this.bestAttempts,
    required this.worstBlock,
    required this.worstAttempts,
    required this.reward,
  });

  final String name;
  final int blocks;
  final int totalAttempts;

  /// Le bloc trouve avec le moins de tentatives : le coup de chance.
  final int bestBlock;
  final int bestAttempts;

  /// Celui qui a demande le plus d'acharnement.
  final int worstBlock;
  final int worstAttempts;

  final double reward;

  double get averageAttempts => blocks == 0 ? 0 : totalAttempts / blocks;
}

/// Classe les mineurs d'une chaine par nombre de blocs trouves.
///
/// Le bloc de genese est exclu : personne ne l'a mine, il a ete pose.
List<MinerScore> rankMiners(MyChain chain) {
  final parBloc = <String, List<MyBlock>>{};
  for (final bloc in chain.blocks) {
    if (bloc.height == 0) continue;
    final nom = bloc.message.trim().isEmpty ? 'sans nom' : bloc.message.trim();
    parBloc.putIfAbsent(nom, () => <MyBlock>[]).add(bloc);
  }

  final scores = <MinerScore>[];
  parBloc.forEach((nom, blocs) {
    var total = 0;
    var meilleur = blocs.first;
    var pire = blocs.first;
    for (final bloc in blocs) {
      total += bloc.hashesTried;
      if (bloc.hashesTried < meilleur.hashesTried) meilleur = bloc;
      if (bloc.hashesTried > pire.hashesTried) pire = bloc;
    }
    scores.add(MinerScore(
      name: nom,
      blocks: blocs.length,
      totalAttempts: total,
      bestBlock: meilleur.height,
      bestAttempts: meilleur.hashesTried,
      worstBlock: pire.height,
      worstAttempts: pire.hashesTried,
      reward: blocs.fold(0.0, (s, b) => s + b.reward),
    ));
  });

  scores.sort((a, b) {
    final parBlocs = b.blocks.compareTo(a.blocks);
    if (parBlocs != 0) return parBlocs;
    return a.averageAttempts.compareTo(b.averageAttempts);
  });
  return scores;
}

/// Le plus grand coup de chance de toute la chaine, tous mineurs confondus.
MyBlock? luckiestBlock(MyChain chain) {
  MyBlock? meilleur;
  for (final bloc in chain.blocks) {
    if (bloc.height == 0 || bloc.hashesTried == 0) continue;
    if (meilleur == null || bloc.hashesTried < meilleur.hashesTried) {
      meilleur = bloc;
    }
  }
  return meilleur;
}
