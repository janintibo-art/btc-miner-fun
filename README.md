# BTC Miner Fun

Mineur Bitcoin pedagogique, une seule base de code Flutter pour **Android (.apk)** et **Windows (.exe)**.
Interface soignee, onglet tutoriel integre, mode demo hors ligne et mode pool reel (Stratum V1).

> Ce projet sert a comprendre le minage. Un telephone n'a aucune chance realiste
> de trouver un bloc. C'est assume, et explique dans l'application.

## Ce que fait l'application

- **Minage reel** : connexion Stratum V1 a un vrai pool (subscribe / authorize / notify / submit).
- **Inspecteur de bloc** : l'en-tete sur lequel tu travailles, champ par champ, avec
  l'explication de chaque valeur. Rien n'est simule.
- **Multi-coeurs** : un isolate par coeur demande, l'interface ne gele jamais.
- **Trois moteurs de hachage comparables** : paquet crypto, SHA-256 maison,
  et midstate avec rejet precoce. Banc d'essai integre, resultats verifies identiques.
- Reconnexion automatique au pool, avec file d'attente des parts trouvees hors ligne.
- Reglage d'intensite, arret automatique programmable, historique des sessions.
- **Minage ecran eteint** sur Android via un service de premier plan en Kotlin,
  genere a la compilation par `tool/patch_android.py`.
- Tableau de bord : puissance de calcul, courbe 60 s, parts, meilleure difficulte, journal.
- Ecran maintenu allume pendant le minage, icone d'application dediee.
- Onglet tutoriel en 13 chapitres.
- **Tests automatiques** : les calculs sont verifies contre le vrai bloc 125552
  de la chaine Bitcoin avant chaque compilation.

## Structure du depot

```
btc-miner-fun/
├── .github/workflows/build.yml   Compilation automatique APK + EXE
├── tool/patch_android.py         Ajoute la permission INTERNET au manifeste
├── tool/patch_windows.py         Renomme l'executable et la fenetre
├── assets/icon/                  Icone de l'application
├── test/mining_test.dart         Vecteurs de reference du protocole
├── lib/
│   ├── main.dart                 Point d'entree et navigation
│   ├── app_theme.dart            Palette et typographie
│   ├── core/
│   │   ├── bitcoin_utils.dart    Hex, endianness, SHA-256d, cibles
│   │   ├── stratum_job.dart      Job du pool, en-tete de bloc 80 octets
│   │   ├── sha256_fast.dart      SHA-256 maison, midstate, zero allocation
│   │   ├── nonce_walker.dart     Strategies d'exploration, marche signature
│   │   ├── benchmark.dart        Mesure comparative des trois moteurs
│   │   ├── stratum_client.dart   Client Stratum V1 (TCP + JSON-RPC)
│   │   └── miner_engine.dart     Boucle de hachage dans un isolate
│   ├── state/miner_controller.dart
│   ├── screens/                  Minage, Sessions, Reglages, Tutoriel, A propos
│   └── widgets/                  Carte, courbe, console, inspecteur
├── docs/TERMUX.md                Toutes les commandes, une par une
├── docs/ROADMAP.md               Les etapes suivantes
├── pubspec.yaml
└── LICENSE
```

Les dossiers `android/`, `windows/` et `build/` ne sont pas versionnes : la CI les
regenere a chaque compilation avec `flutter create`.

## Recuperer l'APK et l'EXE

1. Pousse le code sur la branche `main` (voir `docs/TERMUX.md`).
2. Onglet **Actions** du depot : le workflow demarre tout seul.
3. Une fois les deux jobs verts, section **Artifacts** :
   - `BTCMinerFun-android-apk` → les APK. Prends `app-arm64-v8a-release.apk`
     (tous les telephones recents). En cas de refus d'installation, prends
     `app-release.apk`, l'universel, qui fonctionne partout mais pese le triple.
   - `BTCMinerFun-windows` → le dossier avec le `.exe`

Sur Android, autorise l'installation depuis une source inconnue pour ton
gestionnaire de fichiers.

## Etat du projet

Etape 7 terminee : trois strategies d'exploration des nonces, dont une marche
signature propre a chaque utilisateur, verifiee sans repetition ni
chevauchement entre coeurs.
Voir `docs/ROADMAP.md` pour la suite.
