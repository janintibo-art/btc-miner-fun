import 'dart:convert';
import 'dart:io';

import 'my_chain.dart';

/// Etat de la chaine tel que le serveur le voit.
class RemoteHead {
  const RemoteHead({
    required this.height,
    required this.tip,
    required this.work,
  });

  final int height;
  final String? tip;

  /// Travail cumule, en chaine de caracteres : le nombre depasse largement ce
  /// qu'un entier classique peut contenir.
  final String work;
}

/// Reponse a une soumission.
class SubmitResult {
  const SubmitResult({
    required this.accepted,
    required this.message,
    this.remoteHeight,
  });

  final bool accepted;
  final String message;
  final int? remoteHeight;
}

/// Dialogue avec le serveur de chaine partagee.
///
/// Le serveur ne fait pas autorite sur la validite : l'application verifie
/// elle-meme toute chaine recue avant de l'adopter. Il ne fait que coordonner.
class ChainNetwork {
  ChainNetwork(this.baseUrl);

  final String baseUrl;
  static const Duration _delai = Duration(seconds: 15);

  Uri _uri(String chemin) {
    var base = baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return Uri.parse('$base$chemin');
  }

  Future<dynamic> _appel(String chemin,
      {String methode = 'GET', Object? corps}) async {
    final client = HttpClient()..connectionTimeout = _delai;
    try {
      final requete = methode == 'GET'
          ? await client.getUrl(_uri(chemin)).timeout(_delai)
          : await client.postUrl(_uri(chemin)).timeout(_delai);
      requete.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (corps != null) {
        requete.headers.contentType = ContentType.json;
        requete.write(jsonEncode(corps));
      }
      final reponse = await requete.close().timeout(_delai);
      final texte = await reponse.transform(utf8.decoder).join();
      return texte.isEmpty ? <String, dynamic>{} : jsonDecode(texte);
    } finally {
      client.close(force: true);
    }
  }

  Future<RemoteHead?> head() async {
    try {
      final donnees = await _appel('/head');
      if (donnees is! Map) return null;
      return RemoteHead(
        height: (donnees['height'] as num?)?.toInt() ?? 0,
        tip: donnees['tip'] as String?,
        work: donnees['work']?.toString() ?? '0',
      );
    } catch (_) {
      return null;
    }
  }

  /// Recupere la chaine distante et la verifie avant de la rendre.
  ///
  /// Une chaine qui ne passe pas la verification locale est rejetee, meme si
  /// le serveur l'affirme valide : c'est le seul garde-fou contre un serveur
  /// mal intentionne.
  Future<MyChain?> fetchChain() async {
    try {
      final donnees = await _appel('/chain');
      if (donnees is! Map) return null;
      final chaine = MyChain.tryDecode(jsonEncode(donnees));
      if (chaine == null) return null;
      return chaine.verify().valid ? chaine : null;
    } catch (_) {
      return null;
    }
  }

  Future<SubmitResult> submitBlock(MyBlock bloc) async {
    try {
      final donnees =
          await _appel('/block', methode: 'POST', corps: bloc.toJson());
      if (donnees is! Map) {
        return const SubmitResult(accepted: false, message: 'reponse inattendue');
      }
      return SubmitResult(
        accepted: donnees['accepted'] == true,
        message: donnees['reason']?.toString() ?? 'accepte',
        remoteHeight: (donnees['height'] as num?)?.toInt(),
      );
    } catch (e) {
      return SubmitResult(accepted: false, message: 'serveur injoignable : $e');
    }
  }

  /// Propose la chaine locale au serveur. Elle n'est adoptee que si elle
  /// totalise plus de travail que celle deja en place.
  Future<SubmitResult> pushChain(MyChain chaine) async {
    try {
      final donnees = await _appel('/chain',
          methode: 'POST', corps: jsonDecode(chaine.encode()));
      if (donnees is! Map) {
        return const SubmitResult(accepted: false, message: 'reponse inattendue');
      }
      return SubmitResult(
        accepted: donnees['accepted'] == true,
        message: donnees['reason']?.toString() ?? 'chaine adoptee',
        remoteHeight: (donnees['height'] as num?)?.toInt(),
      );
    } catch (e) {
      return SubmitResult(accepted: false, message: 'serveur injoignable : $e');
    }
  }
}
