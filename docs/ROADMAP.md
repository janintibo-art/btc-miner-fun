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

## Etape 3 - a faire

- Tests unitaires sur la construction de l'en-tete avec un bloc connu
- Plusieurs isolates pour utiliser tous les coeurs du processeur
- Icone et nom d'application personnalises
- Service de premier plan Android pour miner ecran eteint
- Limiteur thermique : ralentir quand l'appareil chauffe
- Historique des sessions
