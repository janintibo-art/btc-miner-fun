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

## La page lit le serveur en direct

Depuis la version 33, `site/config.json` contient l'adresse du serveur de
chaine. La page l'interroge a chaque visite : plus rien a publier a la main.

    {
      "serveur": "https://btc-miner-fun.onrender.com"
    }

Elle ne se contente pas d'afficher ce que le serveur envoie : elle **recalcule
le hash de chaque bloc** dans le navigateur, a partir de son en-tete de 80
octets. Verification faite sur le bloc reel 125552 de Bitcoin, dont elle
retrouve le hash officiel.

Si le serveur ne repond pas - l'instance gratuite s'endort apres quinze
minutes - la page se rabat sur `chain.json` et l'indique clairement.

Laisse `serveur` vide pour revenir au fonctionnement manuel.

## Mettre la chaine a jour a la main (facultatif)

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
