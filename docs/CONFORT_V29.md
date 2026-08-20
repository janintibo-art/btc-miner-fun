# Confort et securite

## Limiteur thermique

Un telephone n'a aucun refroidissement actif : passe un certain seuil, il se
bride lui-meme et la puissance chute, tout en continuant a vider la batterie.
Autant ralentir avant d'y arriver.

Le limiteur lit la temperature de la batterie toutes les cinq secondes. En
dessous de 39 degres, le reglage de l'utilisateur est intact. Entre 39 et 43,
la cadence decroit **progressivement** - une reduction par paliers ferait
osciller l'appareil entre chaud et froid. Au-dela de 43, cadence minimale.
Tout est rendu des que la temperature redescend.

Le capteur de batterie est le seul lisible sans permission particuliere. Il ne
mesure pas le processeur, mais il en suit fidelement l'echauffement.

Cinq tests couvrent la fonction, dont la propriete la plus importante : le
limiteur ne remonte jamais au-dessus du choix de l'utilisateur.

## Bouton d'arret dans la notification

La notification porte une action Arreter. Elle leve un drapeau que Dart
consulte chaque seconde, plutot que de tenter de reveiller l'application
depuis le service : le processus est de toute facon vivant tant qu'il mine.
Le minage se coupe donc sans ouvrir l'application.

## Export des sessions

Format CSV, separateur point-virgule et decimales a la virgule, pour qu'un
tableur francais l'ouvre sans manipulation.

Sur ordinateur, le fichier est ecrit dans le dossier personnel et son chemin
s'affiche. Sur telephone, ou l'acces aux fichiers est cloisonne, le contenu
part dans le presse-papiers.

## Note sur le service Kotlin

Le service avait ete refondu entre-temps : la notification se construit
desormais dans l'objet compagnon. Le patch a ete adapte a la structure reelle
plutot qu'a celle que j'avais en tete, puis rejoue deux fois sur un projet
factice pour verifier l'idempotence et l'equilibre des accolades du Kotlin
produit.
