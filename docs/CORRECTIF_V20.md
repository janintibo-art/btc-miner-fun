# v20 : conflit de versions du SDK Android

## Le probleme

Les tests et la compilation Windows passent. Seul l'APK echouait, et pas sur du
code :

```
Dependency ':flutter_secure_storage' requires libraries and applications that
depend on it to compile against version 37 or later of the Android APIs.
:app is currently compiled against android-36.
```

Le coffre du portefeuille se compile contre l'API 37. Flutter, lui, propose
encore 36 par defaut. Les deux ne peuvent pas se lier.

Un second message brouillait la lecture : le plugin Gradle 9.1.0 annonce 36
comme « maximum recommande ». C'est un avertissement de prudence, pas une
incompatibilite : compiler contre une API plus recente reste retrocompatible.

## La correction

Dans `tool/patch_android.py`, deux ajouts :

- `compileSdk = maxOf(flutter.compileSdkVersion, 37)` dans
  `android/app/build.gradle.kts` ;
- `android.suppressUnsupportedCompileSdk=37` dans `android/gradle.properties`,
  qui neutralise l'avertissement du plugin Gradle.

Le script reste idempotent : deux executions successives laissent un fichier
valide, verifie sur un projet Android factice.

## Si cela ne suffisait pas

Solution de repli : ramener `flutter_secure_storage` a la serie 10 dans
`pubspec.yaml` (`flutter_secure_storage: ^10.0.0`), qui se compile contre
l'API 36. Le coffre fonctionne de la meme facon ; seules les options
`storageNamespace` et `migrateWithBackup` devraient etre retirees de
`wallet_vault.dart`.
