# Chantier GPU, etape B : le noyau de hachage

## Ce qui est ajoute

- `tool/native/gpu_kernel.cl.h` : le noyau OpenCL, double SHA-256 sur en-tete
  de 80 octets, avec deux points d'entree :
  - `mine` : chaque unite de travail teste un nonce et empile les candidats ;
  - `hash_one` : renvoie le hash complet d'un nonce, pour la verification.
- Dans `gpu_probe.cpp` : contexte, file de commandes, compilation du noyau,
  transferts memoire et lecture des resultats.
- `lib/core/gpu_miner.dart` : les liaisons Dart et l'auto-test.

## La regle non negociable

Aucun resultat de la carte n'est utilise tant qu'elle n'a pas reproduit
exactement les hachages du processeur :

1. le bloc reel 125552, dont le hash est connu et verifiable publiquement ;
2. soixante-quatre en-tetes tires au hasard, compares un par un au moteur CPU.

En cas d'ecart, le moteur GPU est desactive, et l'interface affiche l'en-tete
fautif ainsi que les deux hachages, pour pouvoir rejouer le cas.

Le debit n'est mesure qu'apres : on n'annonce une vitesse qu'une fois la
justesse etablie.

## Precautions de construction

**Les constantes du noyau sont extraites du code Dart**, pas recopiees a la
main : la table K et le vecteur initial proviennent de `sha256_fast.dart`. Une
divergence de recopie etait le risque le plus probable, il est supprime a la
source.

**L'algorithme a ete verifie avant livraison** en transcrivant le noyau
fidelement et en le confrontant a une implementation de reference sur deux
cents en-tetes aleatoires, ainsi que sur le bloc 125552.

**Le journal du compilateur OpenCL est remonte jusqu'a l'interface.** C'est la
seule information exploitable si le noyau refuse de se compiler sur une carte
que je ne peux pas tester : le message d'erreur affiche contient le texte
complet du pilote.

**OpenCL reste charge dynamiquement.** Une machine sans carte compatible
n'a aucun comportement different d'avant.

## Ce qui n'est pas encore fait

Le moteur GPU ne mine pas : il se teste et se mesure. L'integration au moteur
de minage, avec repartition du travail et soumission des parts, est l'etape C.
