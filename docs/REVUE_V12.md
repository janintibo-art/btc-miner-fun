# Revue externe de la v11 et suites

Une analyse externe de la version 11 a produit une version 12 corrigee. La
quasi-totalite de ses corrections a ete conservee. Deux d'entre elles ont ete
annulees apres verification, et un defaut supplementaire a ete corrige.

## Corrections conservees (les plus importantes)

- **Base58Check** : les zeros de tete sont desormais preservés et la longueur
  decodee doit valoir exactement 25 octets. La v11 acceptait une adresse non
  canonique comme `11A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa`.
- **BIP 350** : versions de temoin limitees a 0..16, Bech32 exige pour la
  version 0, Bech32m pour les versions 1 a 16, section de donnees vide geree.
- **Arret propre** : tout chemin d'erreur libere desormais isolates, timers,
  socket, wakelock et service Android.
- **Clients Stratum obsoletes** : les callbacks d'une ancienne connexion ne
  peuvent plus declencher une reconnexion concurrente.
- **Android** : `START_NOT_STICKY` (le service ne renait plus sans moteur Dart),
  type `specialUse` avec la permission et la propriete correspondantes,
  notification mise a jour sans relancer le service, script de patch idempotent.
- **Moteur** : plus de copie de tampon a chaque nonce, pause d'intensite
  decoupee et non plafonnee, demarrage des isolates avec delai de garde.
- **Protocole** : champs de `mining.notify` valides avant usage, extranonce2 a
  la largeur exacte demandee, support de `mining.set_extranonce`.
- **Formulation** : la consultation du solde transmet bien l'adresse publique a
  l'explorateur. L'ancien texte pretendait qu'aucune donnee n'etait envoyee.

## Corrections annulees

- **Points d'acces des pools (historique).** Cette section de la revue v12
  indiquait initialement le port 21496 pour Public Pool. Au 18 aout 2026,
  l'interface officielle de Public Pool publie `public-pool.io:3333` : la
  v14 utilise donc 3333. `stratum.ckpool.org` reste distinct du preset CKPool
  solo ; le choix partage demeure etiquete separement.

## Defaut introduit par la v12, corrige ici

- **Demarrage bloque.** La v12 differait toute difficulte au prochain job. Le
  principe est juste : changer la cible d'un travail en cours invalide les
  parts en vol. Mais si le pool envoie `mining.set_difficulty` *apres* le
  premier `mining.notify`, le minage restait a l'arret jusqu'au job suivant.
  La difficulte est desormais appliquee immediatement dans ce seul cas.

## CI

`flutter analyze` est execute mais rendu non bloquant : une regle de style ne
doit pas empecher de produire un APK. Les erreurs reelles restent attrapees par
`flutter test` et par la compilation.
