# BTC Miner Fun

Mineur Bitcoin pedagogique, une seule base de code Flutter pour **Android (.apk)** et **Windows (.exe)**.
Interface soignee, onglet tutoriel integre, mode demo hors ligne et mode pool reel (Stratum V1).

> Ce projet sert a comprendre le minage. Un telephone n'a aucune chance realiste
> de trouver un bloc. C'est assume, et explique dans l'application.

## Ce que fait l'application

- **Minage reel** : connexion Stratum V1 a un vrai pool (subscribe / authorize / notify / submit).
- **Inspecteur de bloc** : l'en-tete sur lequel tu travailles, champ par champ, avec
  l'explication de chaque valeur. Rien n'est simule.
- Double SHA-256 dans un *isolate* separe : l'interface ne gele jamais.
- Reconnexion automatique au pool, avec delai croissant.
- Tableau de bord : puissance de calcul, courbe 60 s, parts, meilleure difficulte, journal.
- Onglet tutoriel en 8 chapitres.

## Structure du depot

```
btc-miner-fun/
├── .github/workflows/build.yml   Compilation automatique APK + EXE
├── tool/patch_android.py         Ajoute la permission INTERNET au manifeste
├── lib/
│   ├── main.dart                 Point d'entree et navigation
│   ├── app_theme.dart            Palette et typographie
│   ├── core/
│   │   ├── bitcoin_utils.dart    Hex, endianness, SHA-256d, cibles
│   │   ├── stratum_job.dart      Job du pool, en-tete de bloc 80 octets
│   │   ├── stratum_client.dart   Client Stratum V1 (TCP + JSON-RPC)
│   │   └── miner_engine.dart     Boucle de hachage dans un isolate
│   ├── state/miner_controller.dart
│   ├── screens/                  Minage, Reglages, Tutoriel, A propos
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
   - `BTCMinerFun-android-apk` → l'APK a installer
   - `BTCMinerFun-windows` → le dossier avec le `.exe`

Sur Android, autorise l'installation depuis une source inconnue pour ton
gestionnaire de fichiers.

## Etat du projet

Etape 2 terminee : minage reel uniquement, inspecteur de bloc explique,
reconnexion automatique, presets de pools.
Voir `docs/ROADMAP.md` pour la suite.
