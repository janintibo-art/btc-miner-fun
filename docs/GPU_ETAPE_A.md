# Chantier GPU, etape A : la tuyauterie

## Ce que fait cette etape

Rien qui calcule. Elle prouve que le chemin le plus risque fonctionne :

    Dart  ->  dart:ffi  ->  gpu_probe.dll  ->  OpenCL.dll  ->  pilote graphique

L'application affiche, dans l'onglet Labo, le processeur et chaque
peripherique OpenCL detecte : nom, fabricant, unites de calcul, frequence,
memoire. Si cette liste s'affiche, la partie la plus casse-gueule du projet
- le cablage de compilation - est derriere nous.

## Choix techniques

**OpenCL est charge a l'execution, jamais a la compilation.** Le SDK n'est pas
installe sur les machines de compilation GitHub, et surtout : une machine sans
carte compatible doit demarrer normalement. `LoadLibraryA("OpenCL.dll")` echoue
proprement et l'application affiche une explication au lieu de refuser de se
lancer.

**Aucun en-tete OpenCL n'est inclus.** Les quelques constantes et signatures
necessaires sont declarees dans `gpu_probe.cpp`. Le fichier ne depend que de
l'API Windows.

**Le C++ vit dans `tool/native/`**, versionne, et il est copie dans le projet
Windows regenere a chaque compilation, comme le service Kotlin cote Android.
`tool/patch_windows.py` ajoute la cible CMake et la regle d'installation : la
DLL atterrit a cote de `BTCMinerFun.exe`. Le script est idempotent, verifie sur
un projet factice.

**Le protocole d'echange est volontairement primitif** : une ligne de texte par
peripherique, champs separes par des barres verticales. Pas de structure
partagee entre C++ et Dart, donc pas de risque d'alignement memoire.

## Codes de retour

    >= 0  nombre de peripheriques trouves
      -1  OpenCL absent de la machine
      -2  aucune plateforme declaree (pilotes a mettre a jour)
      -3  tampon trop petit

## Etapes suivantes

- **B** : le noyau SHA-256d sur GPU, avec auto-test obligatoire contre le
  processeur sur les vecteurs du bloc 125552. En cas d'ecart, le moteur GPU
  est desactive et rien n'est soumis au pool.
- **C** : integration au banc d'essai, comparaison chiffree CPU / GPU.
