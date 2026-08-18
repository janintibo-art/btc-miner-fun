# Feuille de route

## Etape 1 - terminee

- Architecture Flutter Android + Windows, un seul depot
- Interface complete : Minage, Reglages, Tutoriel, A propos
- Moteur double SHA-256 dans un isolate, courbe de hashrate, journal
- Client Stratum V1 et mode demo hors ligne
- Compilation automatique APK + EXE par GitHub Actions

## Etape 2 - fiabiliser le minage reel

- Tests unitaires sur la construction de l'en-tete avec un bloc connu
  (verifier version, prevhash, racine de Merkle, ntime, nbits)
- Reconnexion automatique au pool et file d'attente des parts
- Choix du nombre de coeurs utilises (plusieurs isolates)
- Icone et nom d'application personnalises

## Etape 3 - confort

- Service de premier plan Android pour miner ecran eteint
- Limiteur thermique : ralentir si le telephone chauffe
- Historique des sessions et statistiques cumulees
- Traductions et signature de l'APK pour distribution
