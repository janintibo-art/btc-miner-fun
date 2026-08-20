# Serveur du Tibo

Un coordinateur pour une chaine partagee : plusieurs personnes minent la meme
chaine et se disputent chaque bloc.

## Ce qu'il fait, et ce qu'il ne fait pas

Il **verifie** : forme du bloc, chainage sur la tete actuelle, horodatage,
preuve de travail reelle, difficulte conforme au reajustement, recompense
conforme au bareme. Un bloc qui triche sur l'un de ces points est refuse.

Il **arbitre** : entre deux chaines, il garde celle qui totalise le plus de
travail cumule - la regle de Bitcoin, et non le simple nombre de blocs.

Il **ne mine pas** et ne peut pas fabriquer de blocs : il n'a aucun moyen de
produire une preuve de travail sans la calculer comme tout le monde.

En revanche, **il faut faire confiance a celui qui l'heberge** pour ne pas
effacer la chaine ou la remplacer. C'est exactement ce dont Bitcoin se passe
grace a son reseau pair a pair, et c'est ce qui separe ce serveur d'un vrai
noeud.

## Deployer gratuitement sur Render

1. Va sur render.com, cree un compte, puis **New** → **Web Service**.
2. Connecte le depot `btc-miner-fun`.
3. Renseigne :
   - **Root Directory** : `server`
   - **Build Command** : (laisse vide)
   - **Start Command** : `node server.js`
   - **Instance Type** : Free
4. Deploie. L'adresse obtenue ressemble a
   `https://tibo-xxxx.onrender.com`.
5. Colle cette adresse dans l'application : Monnaies → ta monnaie → Chaine
   partagee → Enregistrer, puis Synchroniser.

### Deux limites du gratuit

Le service **s'endort apres quinze minutes sans trafic** et met environ une
minute a se reveiller. La premiere synchronisation apres une pause sera donc
lente : c'est normal, pas une panne.

Le disque est **efface a chaque redemarrage**. Ce n'est pas fatal : au premier
demarrage a vide, le premier mineur qui se synchronise repousse sa copie, et
la regle du travail cumule la fait adopter. La chaine se reconstitue d'elle-
meme, a condition qu'au moins un participant en ait gardé une copie - ce que
l'application fait automatiquement.

## Essayer en local

    cd server
    node server.js

Puis dans l'application, adresse : `http://192.168.x.x:8080` (l'adresse de
l'ordinateur sur le reseau local, pas `localhost`, qui designerait le
telephone lui-meme).

## Points d'acces

| Methode | Chemin   | Role                                              |
|---------|----------|---------------------------------------------------|
| GET     | `/head`  | hauteur, tete, travail cumule                     |
| GET     | `/chain` | la chaine complete                                |
| POST    | `/block` | soumettre un bloc mine                            |
| POST    | `/chain` | proposer une chaine entiere (adoptee si plus dure)|
| GET     | `/`      | page d'etat lisible                               |

## Verifications effectuees avant livraison

Le validateur a d'abord ete confronte au **bloc reel 125552 de Bitcoin** : il
en retrouve le hash officiel. Le serveur a ensuite ete lance et soumis a une
serie d'attaques :

- bloc sans preuve de travail : refuse ;
- bloc annoncant une difficulte plus facile : refuse ;
- bloc s'attribuant un million d'unites : refuse ;
- bloc greffe ailleurs que sur la tete : refuse ;
- bloc mal forme, champ manquant, message de cinq cents caracteres : refuse ;
- chaine entiere dont une recompense a ete modifiee : refusee ;
- chaine plus courte que l'actuelle : refusee ;
- deux mineurs sur la meme hauteur : un seul accepte, l'autre invite a se
  resynchroniser.

La premiere version acceptait les deux premieres attaques. C'est ce test qui
l'a revele.
