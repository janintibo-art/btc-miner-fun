# Termux, commande par commande

A copier-coller **une ligne a la fois**, dans l'ordre. Apres chaque commande,
appuie sur Entree et attends que le curseur revienne.

## 1. Preparer Termux

```
pkg update -y && pkg upgrade -y
```

```
pkg install -y git openssh unzip nano
```

```
termux-setup-storage
```

(Android affiche une demande d'autorisation : accepte.)

## 2. Dezipper le projet

Le fichier telecharge se trouve normalement dans `Download`.

```
cd ~/storage/downloads
```

```
ls | grep btc
```

```
mkdir -p ~/projets
```

```
unzip btc-miner-fun.zip -d ~/projets
```

```
cd ~/projets/btc-miner-fun
```

```
ls -a
```

Tu dois voir `lib`, `docs`, `tool`, `.github`, `pubspec.yaml`.

## 3. Se presenter a Git

Remplace les valeurs entre guillemets par les tiennes.

```
git config --global user.name "TonPseudoGitHub"
```

```
git config --global user.email "ton.email@exemple.com"
```

```
git config --global init.defaultBranch main
```

## 4. Creer une cle SSH et la donner a GitHub

```
ssh-keygen -t ed25519 -C "termux"
```

Appuie 3 fois sur Entree (emplacement par defaut, sans phrase de passe).

```
cat ~/.ssh/id_ed25519.pub
```

Selectionne la ligne affichee (elle commence par `ssh-ed25519`) et copie-la.
Puis, dans ton navigateur : **github.com → photo de profil → Settings → SSH and
GPG keys → New SSH key** → colle la cle → **Add SSH key**.

```
ssh -T git@github.com
```

Tape `yes` si la question apparait. Le message attendu contient
`successfully authenticated`.

## 5. Creer le depot

Dans le navigateur : **github.com → bouton + → New repository**
- Repository name : `btc-miner-fun`
- Public
- **Ne coche rien** (pas de README, pas de .gitignore, pas de licence)
- **Create repository**

## 6. Envoyer le projet

```
cd ~/projets/btc-miner-fun
```

```
git init
```

```
git add .
```

```
git commit -m "Etape 1 : base du mineur Bitcoin"
```

```
git branch -M main
```

Remplace `TonPseudoGitHub` par ton pseudo :

```
git remote add origin git@github.com:TonPseudoGitHub/btc-miner-fun.git
```

```
git push -u origin main
```

## 7. Recuperer l'APK

Va sur `https://github.com/TonPseudoGitHub/btc-miner-fun/actions`.
Le workflow demarre seul et dure une dizaine de minutes. Quand les deux jobs
sont verts, ouvre le workflow et telecharge, en bas, dans **Artifacts** :

- `BTCMinerFun-android-apk` (un zip contenant `app-release.apk`)
- `BTCMinerFun-windows` (le `.exe` et ses bibliotheques)

Dezippe l'APK et installe-le :

```
cd ~/storage/downloads
```

```
unzip BTCMinerFun-android-apk.zip
```

Puis ouvre `app-release.apk` depuis ton gestionnaire de fichiers.

## 8. Envoyer les modifications suivantes

Les trois seules commandes a retenir pour la suite :

```
git add .
```

```
git commit -m "decris ta modification"
```

```
git push
```

## En cas de probleme

| Message | Solution |
|---|---|
| `Permission denied (publickey)` | La cle SSH n'est pas ajoutee sur GitHub : refais l'etape 4. |
| `unzip: cannot find or open` | Le zip n'est pas dans `~/storage/downloads` : `ls ~/storage/downloads` pour le retrouver. |
| `remote origin already exists` | `git remote set-url origin git@github.com:TonPseudo/btc-miner-fun.git` |
| `Updates were rejected` | `git pull --rebase origin main` puis `git push`. |
| Le workflow echoue | Ouvre le job rouge dans Actions, la ligne en rouge indique l'etape fautive. |
