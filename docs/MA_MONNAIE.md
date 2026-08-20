# Creer sa propre monnaie

## Ce qui est reel

Tout, sauf le reseau.

- **En-tetes de 80 octets** au format exact de Bitcoin : version, hash du bloc
  precedent, racine de Merkle, horodatage, difficulte compacte, nonce.
- **Preuve de travail** en double SHA-256, calculee par le meme moteur
  optimise que le minage reel, midstate et rejet precoce compris.
- **Difficulte au format compact** (nBits), le vrai encodage sur quatre
  octets. L'implementation a ete verifiee dans les deux sens contre les
  valeurs reelles de Bitcoin : 0x1d00ffff redonne bien la cible de difficulte
  1, et 0x1a44b9f2 celle du bloc 125552.
- **Reajustement de difficulte** tous les dix blocs, en comparant le temps
  reellement mis au temps vise, avec le meme garde-fou que Bitcoin : facteur
  borne a quatre dans chaque sens pour qu'un coup de chance ne fasse pas
  s'envoler la chaine.
- **Recompense divisee par deux** a intervalle regulier.
- **Verification** bloc par bloc : chainage, hauteurs, horodatages croissants,
  et surtout preuve de travail reelle. Un bloc fabrique sans miner est refuse.

## Ce qui manque, et pourquoi c'est le sujet

Personne d'autre ne valide ces blocs. Personne ne les echange. Personne ne les
accepte en paiement. Il n'y a pas de reseau pair a pair, pas de consensus, pas
de marche.

C'est precisement ce qui fait la valeur des autres chaines : pas la technique,
que l'on vient de reproduire en quelques centaines de lignes, mais le fait que
des milliers d'inconnus fassent tourner le meme code et reconnaissent les
memes blocs.

La monnaie creee ici vaut donc zero, et l'application le dit a l'ecran. Ce
n'est pas une limitation du programme : c'est la lecon.

## Separation stricte

La chaine personnelle est pilotee par un controleur distinct de celui du
minage reel. Les deux ne partagent aucun etat. Une part trouvee sur la chaine
locale ne peut en aucun cas partir vers un pool, et inversement.

## Tests

Onze tests couvrent l'encodage compact dans les deux sens, la genese, le
halving, la taille des en-tetes, la sauvegarde, et surtout les deux cas de
rejet : un bloc sans preuve de travail, et un bloc qui ne suit pas son
predecesseur.
