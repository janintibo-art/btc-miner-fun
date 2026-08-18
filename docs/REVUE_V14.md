# Revue du portefeuille local (v14) et corrections v15

La v14 a ajoute un portefeuille non-custodial. L'implementation a ete relue
ligne a ligne : elle est saine sur l'essentiel et a ete conservee.

## Ce qui a ete verifie et juge correct

- Aucune cryptographie ecrite a la main : BIP39, BIP32 et BIP84 sont delegues a
  `blockchain_utils`.
- Derivation `m/84'/0'/0'/0/0` testee contre le vecteur officiel BIP84
  (`abandon ... about` -> `bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu`).
- La phrase n'est jamais journalisee, jamais copiee dans le presse-papiers,
  jamais ecrite dans SharedPreferences. Seul le stockage securise natif est
  utilise, dans un espace de noms dedie.
- `FLAG_SECURE` pendant l'affichage et la saisie de la phrase.
- `android:allowBackup="false"`, script de patch idempotent (verifie en le
  rejouant deux fois sur un projet Android factice).
- L'adresse est toujours rederivee depuis la phrase : l'adresse stockee n'est
  jamais une source de verite.
- Aucune signature de transaction : la surface critique reste minimale.

## Corrections apportees en v15

1. **Entropie explicite.** La v14 laissait `fromWordsNumber` choisir sa source
   d'aleatoire. C'est le seul parametre dont depend la solidite du
   portefeuille : il est desormais fourni par `Random.secure()`, le generateur
   cryptographique du systeme, et le code correspondant tient en cinq lignes
   lisibles.
2. **Sauvegarde reellement verifiee.** Un bouton "j'ai note les mots" ne prouve
   rien. La creation demande maintenant de ressaisir trois mots tires au sort ;
   sans cela le portefeuille reste marque comme non sauvegarde.
3. **minSdk 24.** La version actuelle de `flutter_secure_storage` exige l'API
   24. Le script forcait 23, ce qui n'aurait tenu que par chance.

## Limite qui demeure

Ce coffre sert a recevoir et a conserver la capacite de recuperation. Pour
depenser, la phrase se restaure dans un portefeuille dedie. Et pour une somme
importante, le bon reflexe reste de la deplacer vers un portefeuille eprouve,
voire un appareil materiel.
