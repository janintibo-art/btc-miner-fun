# Correctif v18 : la chaine d'integration repasse au vert

## Ce qui bloquait

Trois erreurs, toutes au meme endroit, `lib/state/miner_controller.dart` :

```dart
final bucket = difficulty <= 1 ? 0 : (log(difficulty) / ln2).floor();
```

`dart:math` exporte une fonction `log()`, mais le controleur possede sa propre
methode `log(String)` pour le journal de l'application. A l'interieur de la
classe, c'est cette derniere qui l'emporte : l'appel visait le logarithme et
atteignait le journal. D'ou les trois messages de l'analyse — une valeur `void`
utilisee, un `double` passe la ou une `String` etait attendue, et une division
sur un resultat nul.

Correction : `import 'dart:math' as math;`, puis `math.log(...)` et `math.ln2`.
Le prefixe rend la collision impossible a reproduire.

## Deux points annexes

- `lab_screen.dart` importait `coinbase_decoder.dart` sans l'utiliser : le type
  arrive deja par le controleur. Import retire.
- `wallet_keys_test.dart` appelle un canal de plateforme via le coffre securise.
  `TestWidgetsFlutterBinding.ensureInitialized()` a ete ajoute : sans lui, le
  test echoue avec « Binding has not yet been initialized ». C'est
  vraisemblablement ce qui faisait echouer la version 15.

## Pourquoi l'erreur est passee inapercue

L'analyse produisait 90 remarques, dont 87 rappels de style sur `withOpacity`.
Les trois vraies erreurs etaient noyees au milieu. `deprecated_member_use` est
desormais ignore dans `analysis_options.yaml` : le rapport d'analyse ne
contiendra plus que ce qui merite une correction.
