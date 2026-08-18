# Securite du portefeuille local - v14

Cette version est construite a partir de `btc-miner-fun-v13`.

## Ce qui est implemente

- portefeuille non-custodial cree sur l'appareil ;
- entropie fournie explicitement par `Random.secure()` (generateur
  cryptographique du systeme), et non par le choix par defaut de la
  bibliotheque : c'est le point unique dont depend toute la solidite du
  portefeuille, il doit rester visible et verifiable dans le code ;
- sauvegarde verifiee par ressaisie de trois mots tires au sort avant que le
  portefeuille ne soit considere comme sauvegarde ;
- phrase de recuperation BIP39 de 12 mots pour les nouveaux portefeuilles ;
- restauration BIP39 anglaise de 12, 15, 18, 21 ou 24 mots, sans passphrase additionnelle ;
- derivation Bitcoin Native SegWit BIP84 : `m/84'/0'/0'/0/0` ;
- adresse de reception `bc1q...` directement utilisable par le mineur ;
- stockage de la phrase via `flutter_secure_storage`, dans un namespace dedie ;
- `migrateWithBackup: true` pour proteger les migrations du stockage chiffre ;
- Android `android:allowBackup="false"` ;
- Android API 24 minimum, exige par la version actuelle du stockage securise ;
- `FLAG_SECURE` pendant l'affichage ou la saisie de la phrase de recuperation ;
- aucun log de phrase, aucune copie automatique dans le presse-papiers ;
- test de derivation contre le vecteur officiel BIP84.

## Ce qui n'est volontairement pas implemente

Le mineur ne construit, ne signe et ne diffuse aucune transaction de depense.
Cette premiere version du coffre est destinee a **recevoir les gains** et a
conserver la capacite de recuperation. Pour depenser les fonds, restaure la
phrase dans un portefeuille Bitcoin compatible BIP84.

Cette separation limite fortement la surface critique du mineur : aucun code de
selection d'UTXO, de calcul de frais ou de signature de transaction n'est ajoute.

## Regles importantes

1. Les bitcoins ne sont pas dans le telephone : ils sont enregistres sur la
   blockchain. La phrase de recuperation donne le controle des fonds.
2. Ecris les mots sur papier avant de recevoir des fonds importants.
3. Ne mets jamais la phrase dans un message, un cloud, une capture d'ecran ou un
   formulaire web.
4. Ne supprime pas le coffre local avant d'avoir verifie la sauvegarde.
5. Un appareil root, infecte ou controle a distance peut contourner des protections
   logicielles. Le stockage securise reduit le risque, il ne rend pas un appareil
   compromis invulnerable.
6. Aucune phrase de portefeuille utilisateur n'est pregeneree. Chaque nouvelle
   phrase est creee au moment ou l'utilisateur appuie sur "Creer mon portefeuille".
   Le dossier `test/` contient uniquement le vecteur public officiel BIP84
   `abandon ... about` ; il est connu de tous et ne doit jamais recevoir de fonds.

## Recuperation

Avec les 12 mots generes par BTC Miner Fun :

- reseau : Bitcoin mainnet ;
- standard : BIP39 + BIP84 ;
- chemin : `m/84'/0'/0'/0/0` pour l'adresse affichee ;
- type : P2WPKH / Native SegWit (`bc1q...`).

Avant d'envoyer une somme importante, il est recommande de verifier avec une
petite somme et de tester la restauration de la phrase sur un appareil de test
ou un portefeuille compatible.
