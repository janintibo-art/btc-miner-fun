# Quatre ajouts pour le plaisir

## Le certificat de bloc

Toucher un bloc de sa chaine ouvre sa carte d'identite : numero, hash complet,
nonce gagnant, nombre de tentatives, message grave, date. Concu pour etre
capture tel quel et envoye.

Pas d'export d'image : sur Android, ecrire un fichier accessible demanderait
des permissions supplementaires pour un resultat identique a une capture
d'ecran. Le texte reste copiable pour ceux qui preferent le partager
autrement.

## La roulette des hachages

Les hachages defilent vingt fois par seconde, les zeros de tete s'allument, et
la couleur change avec leur nombre. Chaque tirage teste quatre cents nonces et
n'affiche que le meilleur : sans cela, on ne verrait jamais le moindre zero.

Le rappel qui donne le vertige est affiche en bas : une machine a sous arrete
ses rouleaux au bout de trois symboles, il en faudrait dix-neuf alignes pour
un bloc Bitcoin.

## Le championnat

L'identite d'un mineur est le message qu'il grave dans ses blocs. Ce n'est pas
un compte, et deux personnes peuvent choisir le meme texte - mais c'est le
seul champ que la preuve de travail engage, donc le seul qui ne puisse pas
etre falsifie apres coup.

Le classement figure dans l'application et sur le site, calcule des memes
blocs : nombre de blocs trouves, moyenne de tentatives, meilleur coup de
chance. Le site le calcule dans le navigateur, sans rien demander de plus au
serveur.

## Les sons

Un clic quand un bloc tombe, deux clics quand le serveur l'accepte, une
fanfare de quatre temps pour un record, une simple vibration pour un refus -
une mauvaise nouvelle n'a pas besoin d'etre bruyante.

Aucune bibliotheque audio : uniquement les sons systeme et le vibreur, donc
aucune dependance ajoutee et aucun fichier telecharge. Debrayable dans les
reglages.
