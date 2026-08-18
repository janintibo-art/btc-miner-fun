# La version Windows devient une vraie application de bureau

Jusqu'ici, le PC recevait l'interface concue pour un telephone : barre
d'onglets en bas, colonne etroite au centre d'un ecran large, et des reglages
calibres pour menager une batterie inexistante.

## Ce qui change

### Disposition

Au-dela de 900 pixels de large, la barre du bas laisse place a une navigation
laterale, et le contenu est borne a 1080 pixels puis centre : une carte etiree
sur toute la largeur d'un ecran de bureau est illisible. En dessous du seuil,
rien ne bouge : le telephone garde exactement son interface.

### Reglages selon la machine

Un ordinateur est ventile et branche ; un telephone ni l'un ni l'autre. La
valeur conseillee de coeurs passe donc de « la moitie, quatre au maximum » a
« tous sauf un », ce dernier etant garde pour le systeme et l'interface.

Les reglages sans objet disparaissent au lieu de rester inertes : l'ecran
maintenu allume et le service de premier plan Android ne s'affichent plus sur
ordinateur.

### Raccourcis clavier

    F5           demarrer ou arreter le minage
    F11          mode veille plein ecran
    Ctrl + 1..6  changer d'onglet

Ils n'utilisent que des touches qui ne servent jamais a la saisie : aucun
risque de lancer le minage en tapant une adresse Bitcoin.

### Fenetre

`tool/patch_windows.py` fixe desormais la taille d'ouverture a 1360x900 au lieu
du 1280x720 par defaut, positionne la fenetre a l'ecart du bord, et renseigne
le nom du produit dans les proprietes de l'executable.

### Paquet livre

Le zip Windows contient un `LISEZMOI.txt` : lancement, raccourcis, reglages
conseilles, et l'explication de l'avertissement SmartScreen au premier
demarrage, l'executable n'etant pas signe par un certificat commercial.

## Correction au passage

Le bouton « mode veille » ajoute en v21 n'avait jamais ete insere : le point
d'ancrage du remplacement ne correspondait plus au tableau de bord refondu.
Le mode n'etait donc accessible que par F11, et seulement sur ordinateur. Il
est desormais bien present sur les deux plateformes.
