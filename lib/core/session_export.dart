import 'dart:io';

import 'platform_profile.dart';
import 'session.dart';

/// Export des sessions au format CSV.
///
/// Sur ordinateur, le fichier est ecrit dans le dossier personnel : il est
/// immediatement ouvrable dans un tableur. Sur telephone, ou l'acces au
/// systeme de fichiers est cloisonne, le contenu est renvoye pour etre copie
/// dans le presse-papiers.
class SessionExport {
  /// Construit le contenu CSV. Separateur point-virgule et decimales a la
  /// virgule : c'est ce qu'attend un tableur en configuration francaise.
  static String toCsv(List<MiningSession> sessions) {
    final buffer = StringBuffer()
      ..writeln('date;duree_secondes;hachages;moyenne_hs;'
          'meilleure_difficulte;parts_acceptees;parts_refusees;coeurs;pool');

    for (final session in sessions) {
      final d = session.startedAt;
      final date = '${d.year}-${_two(d.month)}-${_two(d.day)} '
          '${_two(d.hour)}:${_two(d.minute)}';
      buffer.writeln([
        date,
        session.seconds,
        session.hashes,
        session.averageHashrate.toStringAsFixed(1).replaceAll('.', ','),
        session.bestDifficulty.toStringAsFixed(3).replaceAll('.', ','),
        session.accepted,
        session.rejected,
        session.threads,
        session.pool,
      ].join(';'));
    }
    return buffer.toString();
  }

  /// Ecrit le fichier quand la plateforme le permet, et renvoie son chemin.
  static Future<String?> writeToDisk(String csv) async {
    if (!PlatformProfile.isDesktop) return null;
    try {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.current.path;
      final now = DateTime.now();
      final name = 'btc-miner-fun-sessions-'
          '${now.year}${_two(now.month)}${_two(now.day)}.csv';
      final file = File('$home${Platform.pathSeparator}$name');
      await file.writeAsString(csv);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
