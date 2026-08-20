# v42 : un import manquant, et le controle qui allait avec

## Le defaut

`LocalCurrencyController` etait utilise dans l'ecran du catalogue, sans que le
fichier qui le definit soit importe. La compilation s'arrete la.

## Ce que le verificateur savait faire, et ce qu'il ignorait

Il detectait deja :

- une classe utilisee mais definie nulle part ;
- une classe definie mais jamais utilisee ;
- un import dont le symbole n'apparait pas dans le fichier ;
- un ecran que rien n'ouvre.

Il lui manquait le pendant exact du troisieme : **un symbole utilise sans que
son module soit importe**. C'est desormais fait.

Premier essai : trois faux positifs, tous sur le mot « Scrypt » cite dans des
commentaires et des libelles. La recherche porte maintenant sur le code seul,
chaines de caracteres et commentaires retires.

Verification finale en retirant l'import volontairement : le script le signale,
et la restauration a ete controlee ensuite - la lecon de la version 39 ayant
ete retenue.

## Remarques de style

Deux interpolations superflues et un constructeur non constant ont ete
corriges dans la foulee.
