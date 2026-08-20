# Publier le site du Tibo

## Mise en route, une seule fois

1. Pousse cette version : le dossier `site/` et le workflow arrivent dans le
   depot.
2. Sur GitHub : **Settings** → **Pages**.
3. Dans **Source**, choisis **GitHub Actions** (et non « Deploy from a
   branch »).
4. C'est tout. Le workflow s'execute et publie la page.

L'adresse sera :

    https://TONPSEUDO.github.io/btc-miner-fun/

Les liens de la page vers le depot et les telechargements se deduisent tout
seuls de cette adresse : aucun nom a modifier dans le code.

## Mettre la chaine a jour

1. Dans l'application, onglet Monnaies → ta monnaie → **Exporter chain.json**.
   Sur ordinateur, un fichier est ecrit dans ton dossier personnel ; sur
   telephone, le contenu part dans le presse-papiers.
2. Remplace `site/chain.json` par ce contenu.
3. `maj "chaine du Tibo mise a jour"`.

Le workflow verifie que le fichier est du JSON valide avant de publier : une
chaine mal collee ne casse pas la page en ligne.

## Ce que la page affiche

- La piece et la presentation.
- L'etat de la chaine : nombre de blocs, unites en circulation, tentatives
  cumulees.
- Les cinquante derniers blocs : hauteur, hash, nonce, nombre de tentatives et
  message inscrit.
- Un avertissement, volontairement mis en avant : ne pas acheter, ne pas
  vendre, ne pas accepter en paiement.

## Le cout

Aucun. GitHub Pages est gratuit et sans limite de duree pour un depot public,
avec certificat HTTPS automatique. Il ne sert que des fichiers statiques : pas
de serveur, donc rien qui puisse tomber en panne ni rien a surveiller.

C'est aussi sa limite. Pour que d'autres personnes minent **la meme chaine**,
il faudrait un service qui recoit et valide les blocs soumis - c'est l'etape
suivante, et elle demande une machine allumee en permanence.
