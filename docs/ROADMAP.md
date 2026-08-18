# Feuille de route

## Etape 1 - terminee

- Architecture Flutter Android + Windows, un seul depot
- Interface complete : Minage, Reglages, Tutoriel, A propos
- Moteur double SHA-256 dans un isolate, courbe de hashrate, journal
- Client Stratum V1
- Compilation automatique APK + EXE par GitHub Actions

## Etape 2 - terminee

- Suppression du mode demo : l'application ne fait que du minage reel
- Inspecteur du bloc en cours : prevhash, racine de Merkle, extranonce,
  cible et difficulte, chaque champ explique en francais
- Reconnexion automatique au pool avec delai croissant (6 tentatives)
- Choix du pool par presets, verification de forme de l'adresse Bitcoin
- Tutoriel reecrit autour du protocole reel

## Etape 3 - terminee

- Tests unitaires executes par la CI avant chaque compilation :
  double SHA-256 verifie contre le bloc 125552, cibles, difficultes,
  racine de Merkle et en-tete Stratum compares a des vecteurs de reference
- Minage multi-coeurs : un isolate par coeur, plages de nonces disjointes
- Reglage du nombre de coeurs, avec valeur conseillee prudente
- Ecran maintenu allume pendant le minage
- Icone d'application et executable nomme BTCMinerFun.exe

## Etape 4 - terminee

- File d'attente des parts trouvees pendant une coupure reseau,
  avec abandon de celles qui visent un travail perime
- Intensite reglable de 10 a 100 % : pauses intercalees entre les lots
  de hachages, applicable en cours de minage
- Arret automatique programmable (15, 30, 60, 120 minutes)
- Historique des sessions sur l'appareil, avec totaux cumules
- APK decoupes par architecture : environ 8 Mo au lieu de 22 Mo

## Etape 5 - terminee

- Service de premier plan Android ecrit en Kotlin (MiningService.kt),
  genere par tool/patch_android.py au moment de la compilation
- Verrou processeur partiel : le calcul continue ecran eteint
- Notification permanente mise a jour toutes les dix secondes
  (puissance, parts acceptees, duree)
- Pont MethodChannel entre Dart et Android, sans effet sur Windows
- Demande de la permission de notification sur Android 13 et suivants
- L'ecran allume devient un choix, plus une obligation

## Etape 6 - terminee

- SHA-256 ecrit a la main : tampons reutilises, aucune allocation par tentative
- Midstate : le premier des deux blocs de l'en-tete calcule une fois par travail
- Rejet precoce sur les quatre premiers octets du hash retourne
- Trois moteurs selectionnables, comparables dans un banc d'essai integre
- Tests : mille en-tetes aleatoires compares au paquet crypto, chemin midstate
  compare au calcul complet, correspondance du mot de rejet precoce

## Etape 7 - terminee

- Trois strategies d'exploration des nonces : sequentielle, aleatoire, signature
- Marche signature : generateur congruentiel derive d'une phrase, respectant les
  conditions de Hull-Dobell, donc permutation complete des 2^32 nonces
- Chaque coeur parcourt la meme suite avec un decalage et un pas propres :
  aucun chevauchement, verifie par les tests
- Empreinte de la marche affichee dans les reglages
- Honnetete assumee : le mode ne change pas les probabilites, il supprime les
  doublons et rend le parcours unique

## Etape 8 - terminee

- Onglet Convertir : bitcoin vers euros et inversement, affichage en satoshis
- Cours recupere sur CoinGecko, puissance du reseau sur mempool.space,
  sans cle d'API ni donnee envoyee
- Dernier cours connu conserve : la conversion fonctionne hors ligne
- Saisie manuelle du cours en cas d'absence de connexion
- Esperance de gain calculee a partir de la puissance reellement mesuree,
  avec le delai moyen avant un bloc
- Navigation reorganisee en cinq onglets, la presentation rejoint le guide

## Etape 9 - terminee

- Assistant portefeuille : guide de creation en cinq etapes, mise en garde
  contre les classements remuneres, regles de sauvegarde de la phrase
- Verification reelle des adresses : checksum bech32 (BIP 173), bech32m
  (BIP 350) et base58check recalcules, detection du type d'adresse,
  refus du reseau de test et des autres chaines
- Messages d'erreur explicites plutot qu'un simple "invalide"
- QR code de l'adresse et copie en un geste
- Choix assume : l'application ne genere aucune cle privee

## Etape 10 - terminee

- Consultation du solde de l'adresse configuree via mempool.space
- Distinction entre solde confirme et mouvements en attente
- Conversion immediate du solde en euros au cours affiche
- Dernier solde connu conserve pour l'affichage hors ligne
- Choix assume et documente : aucune cle privee, aucune signature de
  transaction. Consulter ne demande que l'adresse, depenser exige la cle.
  Pour depenser, la phrase de recuperation se saisit dans un portefeuille
  dedie : le format BIP39 est universel.

## Etape 11 - a faire

- Lecture de la temperature de la batterie pour brider automatiquement
- Bouton d'arret directement dans la notification
- Signature de l'APK pour distribution hors GitHub
- Publication automatique d'une release GitHub sur tag de version
