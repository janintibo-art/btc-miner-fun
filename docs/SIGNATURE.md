# Signer l'APK, pour installer les mises a jour par-dessus

## Le probleme

Sans cle, Gradle signe avec une cle de debogage **regeneree a chaque
compilation**. Deux APK successifs portent donc des signatures differentes, et
Android refuse categoriquement de remplacer une application par une autre qui
n'a pas la meme signature. D'ou la desinstallation a chaque mise a jour, et la
perte des reglages et de la chaine locale.

Avec une cle stable, les mises a jour s'installent normalement, et les donnees
sont conservees.

## Une seule fois : creer la cle

Dans Termux :

    pkg install -y openjdk-17

    cd ~
    keytool -genkeypair -v -keystore cle-tibo.jks -storetype PKCS12 \
      -keyalg RSA -keysize 2048 -validity 10000 -alias tibo

Il demande un mot de passe (deux fois), puis des informations d'identite : nom,
organisation, ville, pays. Rien n'est verifie, mets ce que tu veux, mais
**retiens le mot de passe** : sans lui, la cle est inutilisable et il faudra
tout desinstaller pour repartir d'une nouvelle.

Validite : 10 000 jours, soit vingt-sept ans. Largement suffisant.

## Mettre la cle a l'abri

**Garde une copie du fichier `cle-tibo.jks` ailleurs que sur le telephone.**
Perdue, elle ne se retrouve pas : il faudrait desinstaller l'application pour
en installer une signee autrement.

Puis convertis-la en texte, pour la confier aux secrets de GitHub :

    base64 -w 0 ~/cle-tibo.jks > ~/cle-tibo.txt
    termux-clipboard-set < ~/cle-tibo.txt

(sans `termux-api`, ouvre le fichier avec `cat ~/cle-tibo.txt` et copie tout)

## Declarer les quatre secrets

Sur GitHub : depot → **Settings** → **Secrets and variables** → **Actions** →
**New repository secret**. Quatre secrets a creer :

| Nom               | Valeur                                    |
|-------------------|-------------------------------------------|
| `KEYSTORE_BASE64` | le contenu de `cle-tibo.txt`              |
| `STORE_PASSWORD`  | le mot de passe choisi                    |
| `KEY_PASSWORD`    | le meme mot de passe                      |
| `KEY_ALIAS`       | `tibo`                                    |

Les secrets ne sont jamais affiches ensuite, meme par toi : GitHub les masque
aussi dans les journaux de compilation.

## Ensuite

Rien a faire. Le workflow detecte la cle et signe les APK. Le journal
l'indique clairement a l'etape « Nature de la signature ».

**La toute premiere fois seulement**, il faudra encore desinstaller
l'application : la version installee porte une signature de debogage,
incompatible avec la nouvelle. A partir de la suivante, les mises a jour
s'installeront par-dessus, et tu garderas ta chaine et tes reglages.

## Si aucune cle n'est declaree

La compilation continue avec la signature de debogage et le journal le dit.
Le depot reste donc utilisable par n'importe qui, sans secret ni cle.
