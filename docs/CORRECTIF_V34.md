# v34 : l'application ne survivait pas a un changement d'application

## Le symptome

Passer sur une autre application puis revenir : tout etait revenu a l'ecran de
depart, et le minage arrete.

## Les deux causes

**Le minage de la chaine personnelle ne demarrait aucun service de premier
plan.** Le minage reel, lui, en lance un depuis la version 25 - c'est ce qui
l'empeche d'etre tue en arriere-plan. La chaine du Tibo n'en beneficiait pas :
Android etait donc libre de fermer l'application des qu'elle n'etait plus
visible. Corrige : le service demarre aussi pour la chaine personnelle, et sa
notification affiche le nombre de tentatives et le debit.

**L'onglet actif n'etait pas conserve.** Android peut recreer l'ecran a tout
moment, et l'etat d'un widget ne survit pas a cette recreation. L'onglet est
desormais memorise et restaure.

## Au passage : le minage de la chaine etait dix fois trop lent

Il n'utilisait **qu'un seul coeur**, la ou le minage reel en utilise plusieurs
depuis longtemps. Chaque lot lancait de surcroit un isolate neuf pour 120 000
hachages seulement, si bien que le cout de creation pesait lourd dans le
resultat.

Desormais : un lot par coeur, sur des plages de nonces disjointes, et des lots
de 400 000 hachages. Sur un telephone a quatre coeurs utilises, cela devrait
representer un facteur proche de dix.
