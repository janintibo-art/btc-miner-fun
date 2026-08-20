# Le catalogue des monnaies

## Ce que contient l'onglet

Vingt chaines, avec pour chacune : l'algorithme de preuve de travail et son
explication, l'intervalle entre blocs, la recompense, et - pour celles que
l'explorateur public couvre - la difficulte reelle, la puissance du reseau et
le cours.

Les difficultes sont affichees sur une echelle logarithmique commune : c'est
la seule facon de faire tenir sur un meme graphique des valeurs allant de
quelques milliers a plus de cent mille milliards.

Quand une session de minage a eu lieu, chaque chaine indique aussi le delai
moyen avant un bloc a la puissance mesuree sur l'appareil.

## Ce que l'application sait miner

Sept chaines utilisent le meme SHA-256d que Bitcoin : Bitcoin, Bitcoin Cash,
Bitcoin SV, eCash, DigiByte, Namecoin et Peercoin. Le moteur fonctionne sans
la moindre modification ; seuls le pool et les regles d'adresse changent.

Les autres demanderaient un second moteur de calcul. Le protocole Stratum,
lui, serait identique - c'est la partie deja ecrite.

Monero est le candidat le plus interessant si nous ecrivons un jour ce second
moteur : son algorithme RandomX est concu pour que les processeurs ordinaires
restent competitifs, ce qui en fait la seule grande chaine ou un ordinateur
personnel a un sens.

## Honnetete sur les adresses

Bitcoin Cash et eCash utilisent aujourd'hui un format d'adresse
(cashaddr) dont le code de controle n'est pas encore verifie par cette
application. Plutot que d'accepter ces adresses sans les verifier, le
catalogue demande le format historique, que tous les pools acceptent. Une
verification partielle serait pire qu'une verification absente : elle
donnerait une fausse assurance.

## Source des chiffres

Un seul explorateur public pour toutes les chaines, afin que les valeurs
soient comparables entre elles. Les chaines qu'il ne couvre pas affichent
leurs caracteristiques fixes sans statistiques en direct.
