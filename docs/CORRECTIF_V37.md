# v37 : une porte muree

## Le defaut

En version 36, la chaine personnelle a rejoint le catalogue des monnaies. Sa
fiche remplacait l'ancienne carte d'acces, retiree comme faisant doublon.

Sauf que cette fiche n'apparait **que si une chaine existe deja**. Sans
chaine - apres une reinstallation, par exemple - il n'y avait plus aucun
chemin vers l'ecran de creation. La fonction existait toujours, entierement
fonctionnelle, mais injoignable.

Aucune erreur de compilation. Aucun test en echec. Aucun avertissement.

## Le correctif

Une carte « Creer ou rejoindre ta monnaie » s'affiche en tete du catalogue
tant qu'aucune chaine n'existe, et s'efface des qu'il y en a une - remplacee
par la fiche.

## Le correctif de fond

`tool/verifier_sources.py` detecte desormais les **ecrans orphelins** : toute
classe `*Screen` qui n'est ouverte nulle part ailleurs que dans sa propre
definition est signalee.

Verification faite en retirant volontairement les references a l'ecran de la
chaine : le script le signale. Il aurait donc arrete la version 36.

C'est le troisieme controle ajoute a cet outil apres un defaut reel, et le
premier a porter non sur la syntaxe mais sur l'accessibilite. Un code peut
etre parfaitement valide et une fonction rester hors d'atteinte.
