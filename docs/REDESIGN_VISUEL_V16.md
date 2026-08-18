# Refonte visuelle v16 — BTC Miner Fun

Cette variante conserve la logique de minage, le portefeuille, Stratum, le labo,
les reglages et les donnees de l'application. La refonte porte sur la couche UI.

## Direction artistique

- Style **Bitcoin Reactor / cockpit futuriste**.
- Noir profond pour augmenter le contraste et donner de la profondeur.
- Ambre Bitcoin comme couleur d'energie principale.
- Cyan electrique pour les flux de donnees et la telemetrie.
- Violet plasma pour les records et fonctions secondaires.
- Vert menthe / rouge corail reserves aux etats positifs et erreurs.

## Modifications principales

- Nouveau fond technique avec grille, halos et noeuds de circuit dessines en
  `CustomPainter` sans asset lourd.
- Fond volontairement statique afin de ne pas consommer inutilement du CPU
  pendant le hachage.
- Nouvelle barre superieure avec identite `BTC // ...`, noyau Bitcoin en relief
  et badge de version.
- Nouvelle navigation basse en panneau flottant multicouche.
- Cartes globales refaites : gradients, ombres profondes, halo contextuel,
  filet lumineux et bordures plus fines.
- Titres de sections avec rail lumineux ambre/cyan.
- Theme global enrichi : champs, boutons, sliders, switches et SnackBars.
- Tableau de bord transforme en console de reacteur : etat systeme, gros
  indicateur de hashrate, telemetrie, graphique lumineux et commande principale.
- Grille de statistiques enrichie avec pictogrammes et couleurs fonctionnelles.
- Carte des records retravaillee avec rendu plasma/ambre.
- Console Stratum transformee en terminal technique avec barre d'etat.
- Sparkline refaite avec grille, remplissage, lueur et ligne cyan -> ambre.

## Fichiers UI touches

- `lib/app_theme.dart`
- `lib/main.dart`
- `lib/screens/dashboard_screen.dart`
- `lib/widgets/app_card.dart`
- `lib/widgets/futuristic_background.dart` (nouveau)
- `lib/widgets/sparkline.dart`
- `lib/widgets/log_console.dart`

## Remarque compilation

L'environnement de modification ne contient pas le SDK Flutter/Dart, donc une
compilation APK n'a pas pu etre lancee ici. La refonte a ete limitee a des API
Flutter/Material standard et n'ajoute aucune dependance au `pubspec.yaml`.


## Revue et complements (v17)

La refonte a ete relue : aucune couleur supprimee, aucune signature de widget
modifiee, aucune fonction perdue. Le fond `CustomPainter` renvoie
`shouldRepaint = false` et n'utilise aucun `BackdropFilter` : il ne coûte donc
rien pendant le hachage. Trois ajustements ont ete faits.

### Lisibilite

Six notes de bas de carte utilisaient `AppColors.line`, la couleur des
bordures : mesure faite, le contraste tombait a 1,6 pour 1 la ou la norme
demande 4,5. Elles passent a `AppColors.dim`. Les libelles de navigation, a
9,2 px, remontent a 10,5 px.

### Signature visuelle

La courbe de puissance affiche desormais les trouvailles remarquables sous
forme d'impacts cyan, positionnes selon leur age dans la fenetre de 60
secondes. Le seuil d'observation du labo pilote directement leur frequence :
la meme donnee, vue comme un evenement plutot que comme une ligne de journal.

### Mouvement

Le temoin d'etat bat lentement pendant le minage, et seulement pendant. Il
respecte le reglage systeme de reduction des animations.
