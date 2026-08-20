# v39 : quand tester casse ce qu'on vient de reparer

## Ce qui s'est passe

La version 37 corrigeait un defaut : l'ecran de creation de monnaie etait
devenu injoignable. Le correctif etait bon.

Puis, pour verifier que le nouveau controle du verificateur fonctionnait, j'ai
volontairement casse le fichier - retire la carte d'acces, remplace
l'ouverture de l'ecran par une fermeture. Ensuite, j'ai sauvegarde le fichier
**dans cet etat casse**, croyant sauvegarder l'etat correct, et je l'ai
restaure a la fin.

Les versions 37 et 38 ont donc ete livrees avec :

- la carte d'acces definie mais jamais affichee ;
- le bouton de la fiche du catalogue qui fermait la page au lieu d'ouvrir
  l'ecran de la chaine.

Le defaut initial n'etait donc pas corrige, et un second s'y etait ajoute.

## Ce qui l'a rattrape

`flutter analyze`, avec un avertissement sans ambiguite :

    The declaration '_CreerMaMonnaie' isn't referenced

Les avertissements font echouer la compilation - c'est ce qui a empeche cette
version d'arriver sur le telephone.

## Les deux corrections

Le bouton ouvre a nouveau l'ecran de la chaine, et la carte d'acces s'affiche
tant qu'aucune chaine n'existe.

## Le controle ajoute

Le verificateur savait detecter une classe **utilisee mais absente**. Il
detecte desormais aussi le symetrique : une classe **definie mais jamais
utilisee**. C'est le meme defaut vu de l'autre cote, et tout aussi revelateur
d'une insertion ratee.

Verification faite en retirant l'usage de la carte : le script le signale.

## La lecon de methode

Un test qui modifie le code doit restaurer l'etat **d'avant le test**, pas
celui d'apres. La sauvegarde doit etre prise avant la premiere modification,
jamais entre deux.
