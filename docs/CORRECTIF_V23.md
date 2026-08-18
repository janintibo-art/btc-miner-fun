# v23 : corriger la cause, pas seulement le symptome

## Les deux erreurs de la v22

- `_Shortcut` : la classe etait utilisee trois fois dans l'ecran des reglages
  et definie nulle part. Je l'avais ajoutee par recherche de motif, en visant
  `class _ModeTile` — un point d'ancrage qui n'existait plus depuis la refonte
  visuelle. Le remplacement a echoue en silence, seul l'appel a ete ecrit.
- `dart:io` : l'import est devenu inutile quand `Platform.numberOfProcessors`
  a ete deplace dans `PlatformProfile`.

## La cause commune

Trois versions de suite ont echoue pour la meme raison de fond : des
modifications appliquees par recherche de motif, dont l'ancrage n'existait
plus. Le code etait coherent dans mon raisonnement, pas dans le depot, et
seule la compilation le disait — quatre minutes plus tard.

## Le correctif de fond

`tool/verifier_sources.py` controle les sources sans SDK Dart, en une seconde :

1. toute classe privee utilisee est-elle definie dans son fichier ;
2. tout import relatif pointe-t-il vers un fichier existant, dont le symbole
   principal est reellement employe ;
3. tout import de bibliotheque standard sert-il encore a quelque chose.

Il est branche dans la CI **avant** `flutter pub get`, donc avant toute
installation. Verification faite : en reintroduisant les deux bugs de la v22,
le script les signale tous les deux et sort en erreur.

Ce n'est pas un remplacant de `flutter analyze`. C'est un garde-fou contre une
classe d'erreurs precise, celle que ce projet a rencontree trois fois.
