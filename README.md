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
- Onglet guide en 16 chapitres.
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
│   │   ├── price_service.dart    Cours du bitcoin et etat du reseau
│   │   ├── address_validator.dart Verification bech32 / bech32m / base58check
│   │   ├── wallet_watch.dart     Consultation publique du solde
│   │   ├── wallet_keys.dart      BIP39 + derivation BIP84
│   │   ├── wallet_vault.dart     Coffre chiffre local
│   │   ├── benchmark.dart        Mesure comparative des trois moteurs
│   │   ├── stratum_client.dart   Client Stratum V1 (TCP + JSON-RPC)
│   │   └── miner_engine.dart     Boucle de hachage dans un isolate
│   ├── state/miner_controller.dart
│   ├── screens/                  Minage, Historique, Convertir, Reglages, Guide
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

## Signature de l'APK

Sans cle, chaque compilation produit une signature differente et Android exige
une desinstallation avant chaque mise a jour. Voir `docs/SIGNATURE.md` pour
declarer une cle stable en quatre secrets - dix minutes, une seule fois.

## Le serveur

Le dossier `server/` contient un coordinateur Node.js sans dependance, pour
partager la chaine du Tibo entre plusieurs mineurs. Voir
`server/LISEZMOI.md` pour le deployer gratuitement.

## Le site

Le dossier `site/` contient la page publique du Tibo, publiee gratuitement par
GitHub Pages. Voir `docs/SITE.md` pour l'activer en trois clics.

## Etat du projet

Version 0.21.0 : simulateur de loterie Monte-Carlo, mode veille plein ecran,
et numero de version unique.


Version 0.16.0 : onglet **Labo** - decodeur d'en-tete interactif, lecture de la
transaction coinbase, seuil d'observation, console Stratum brute et banc
d'avalanche.


Version 0.14.0 (build 14), basee sur la v13 : portefeuille Bitcoin local non-custodial,
phrase BIP39 creee/restauree sur l'appareil, premiere adresse Native SegWit BIP84
(`m/84'/0'/0'/0/0`) et coffre chiffre avec le stockage securise de la plateforme.

Etape 11 terminee : coffre local, sauvegarde des 12 mots, restauration BIP39,
QR de reception et activation directe de l'adresse comme identifiant de paiement du pool.
Aucune phrase de portefeuille utilisateur n'est pregeneree dans le depot et aucune n'est envoyee au pool.

Etape 10 terminee : suivi du solde de l'adresse en lecture seule. Ce module
utilise seulement l'adresse publique et n'accede jamais au coffre.

Etape 9 terminee : assistant portefeuille, verification complete des adresses
avec recalcul du code de controle, QR code de reception.

Etape 8 terminee : onglet de conversion bitcoin/euros avec cours en direct,
cache hors ligne, cours manuel, et estimation chiffree de l'esperance de gain.

Etape 7 terminee : trois strategies d'exploration des nonces, dont une marche
signature propre a chaque utilisateur, verifiee sans repetition ni
chevauchement entre coeurs.
Voir `docs/ROADMAP.md` pour la suite.

## Durcissement v12

La v12 corrige plusieurs cas limites trouves lors d'une revue approfondie :

- presets verifies : `public-pool.io:3333` (solo, sans commission), `solo.ckpool.org:3333` (solo) et `stratum.ckpool.org:3333` (partage) ;
- arret complet du moteur, wakelock, socket et service Android apres un refus du
  pool ou l'abandon des reconnexions ;
- application de `mining.set_difficulty` et `mining.set_extranonce` au prochain
  job Stratum, conformement au comportement attendu de Stratum V1 ;
- validation Base58Check canonique et validation BIP 350 complete (versions 0 a
  16, Bech32 pour v0, Bech32m pour v1-v16) ;
- correction de la synchronisation de l'adresse entre l'assistant portefeuille
  et l'ecran Reglages, et consultation du solde de l'adresse reellement saisie ;
- service Android `specialUse`, `START_NOT_STICKY` et mise a jour de notification
  sans redemarrer le foreground service ;
- suppression d'allocations inutiles dans les moteurs SHA-256 maison/midstate ;
- intensite plus fidele sur les appareils lents ;
- totaux "Depuis le debut" persistants meme lorsque seules les 50 dernieres
  sessions sont conservees a l'ecran ;
- `flutter analyze` ajoute a la CI avant les tests.
