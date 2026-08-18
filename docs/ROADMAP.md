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

## Etape 4 - a faire

- Service de premier plan Android pour miner ecran eteint
- Limiteur thermique : ralentir automatiquement quand l'appareil chauffe
- File d'attente des parts en cas de coupure reseau
- Historique des sessions et statistiques cumulees
- Signature de l'APK pour distribution hors GitHub
