# Le Tibo devient transferable

## Ce qui a ete ajoute

**Une adresse par personne.** Derivee de la phrase de recuperation du
portefeuille, elle commence par T et porte un code de controle, comme une
adresse Bitcoin. La meme phrase redonne toujours la meme adresse : rien de
plus a sauvegarder.

La derivation est volontairement simple et documentee : cle privee = SHA-256
de l'etiquette « TIBO-v1 » suivie de la graine BIP39. Ce n'est pas un chemin
BIP32 standard, et c'est assume - une chaine qui ne vaut rien n'a pas besoin
d'etre compatible avec les portefeuilles du marche. Elle est en revanche
parfaitement reproductible.

**Des virements signes.** Un virement est un texte : « de A vers B, montant,
numero d'ordre, note ». Il est signe sur l'appareil, en ECDSA sur secp256k1 -
la courbe de Bitcoin. Aucune cryptographie n'est ecrite dans l'application :
la signature est faite par pointycastle, la derivation de graine par
blockchain_utils.

**Un serveur qui verifie tout.** Trois controles avant d'accepter un virement :

1. la signature est valable ;
2. la cle publique correspond bien a l'adresse emettrice ;
3. le solde suffit et le numero d'ordre est le bon.

Le deuxieme point est le plus important. Sans lui, n'importe qui pourrait
signer avec sa propre cle en pretendant depenser l'argent d'un autre.

**Une protection contre le rejeu.** Le numero d'ordre, croissant par emetteur.
Sans lui, quelqu'un qui intercepte un virement pourrait le renvoyer dix fois :
la signature resterait valable.

**Des virements engages dans la preuve de travail.** Ils entrent dans la
racine de Merkle, donc dans l'en-tete, donc dans le hachage. Les modifier
apres coup invaliderait le bloc.

## Ce qui a ete verifie, et comment

La partie serveur a ete lancee et attaquee pour de vrai :

- montant modifie apres signature : refuse ;
- destinataire detourne : refuse ;
- numero d'ordre change : refuse ;
- un tiers signant a la place de l'emetteur : refuse ;
- rejeu du meme virement : refuse ;
- depense superieure au solde : refuse ;
- adresse dont un caractere a ete change : refusee.

Puis un scenario complet : deux identites, trois blocs mines, un virement de
20 unites, inclusion dans un bloc. Soldes finaux justes, total conserve.

La partie Dart n'a pas pu etre executee ici. Les risques ont donc ete reduits
autrement : algorithmes rejoues en Python et en Node pour verifier les
formats, conversions de types rendues explicites, et surface d'API nouvelle
maintenue au minimum.

## Ce qui manque encore

Aucun frais de transaction, donc rien n'empeche d'inonder la file - une limite
de cent virements en attente en tient lieu. Et surtout, un mineur choisit
quels virements inclure : sur une vraie chaine, c'est ce qui donne naissance
aux frais de priorite.
