# Un second algorithme : Scrypt

## Ce qui change

Le moteur n'etait cable que pour du double SHA-256. Il accepte desormais
plusieurs familles, chacune apportant trois choses :

- sa fonction de hachage ;
- sa cible de reference, car la difficulte 1 ne vaut pas la meme chose partout ;
- la taille de ses lots de travail.

Ce dernier point n'est pas un detail : un hachage Scrypt coute environ mille
fois un double SHA-256. Conserver des lots de mille hachages figerait
l'interface plusieurs secondes. Les lots Scrypt en comptent quatre.

## Neuf chaines minables

SHA-256d : Bitcoin, Bitcoin Cash, Bitcoin SV, eCash, DigiByte, Namecoin,
Peercoin.

Scrypt : Litecoin, Dogecoin.

## La cible de reference, piege discret

Chez Bitcoin, la difficulte 1 correspond a la cible
`00000000FFFF0000...`. Chez les chaines Scrypt, c'est `0000FFFF00000000...`,
soit 65 536 fois plus facile. Utiliser la mauvaise constante n'aurait rien
casse visiblement : le minage aurait tourne normalement et toutes les parts
auraient ete refusees par le pool.

## Verification

L'implementation de Scrypt a d'abord ete ecrite et confrontee a une
implementation de reference du systeme, sur des en-tetes aleatoires. La
premiere version etait fausse : dans la rotation de Salsa20, l'addition doit
etre ramenee a 32 bits **avant** de tourner. Le resultat restait plausible,
mais faux - exactement le genre de defaut qu'un test de fumee ne voit pas.

Deux vecteurs figes ont ete extraits de la version corrigee et sont verifies
par la CI.

Les adresses des nouvelles chaines sont validees avec leur propre octet de
version, code de controle recalcule. Les vecteurs de test ne sont pas des
adresses trouvees quelque part : elles sont construites depuis leur octet de
version, donc valides par construction.

## Et les autres algorithmes ?

RandomX (Monero) demanderait une machine virtuelle complete, Ethash un fichier
de plusieurs gigaoctets, Equihash et X11 des bibliotheques entieres de
fonctions de hachage. Aucun ne se pretait a une implementation verifiable
dans ce cadre. Scrypt etait le seul a offrir un vrai gain - deux chaines
majeures - pour un risque maitrise.
