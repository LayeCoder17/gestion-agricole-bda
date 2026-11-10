# Gestion comptable agricole

Projet du cours de Bases de données avancées — Licence 3 Génie Logiciel, Université Iba Der Thiam de Thiès (2025-2026).

## Le besoin

Un exploitant cultive 10 hectares de produits maraîchers (oignon, carotte, aubergine, piment, chou…), chacun en plusieurs variétés. Il doit suivre ses récoltes, son stock, ses ventes et ses pertes, pour savoir ce qui se vend et réduire ce qui se perd.

## Ce que contient le dépôt

La conception complète de la base de données, sur les trois niveaux :

1. **Conceptuel** — un diagramme entité-association de 8 entités : produit, variété, tarif, récolte, stock, vente, perte et rapport statistique.
2. **Logique** — le schéma relationnel, avec ses clés primaires, ses clés étrangères et ses contraintes d'unicité.
3. **Physique** — les scripts de création pour PostgreSQL.

Le détail se trouve dans [`Projets_BDA/documents/agri_modeling.md`](Projets_BDA/documents/agri_modeling.md).

## Les choix techniques

- **La base protège ses propres données.** Des contraintes `CHECK` interdisent une quantité nulle, un prix négatif ou un stock négatif.
- **Le montant d'une vente n'est jamais saisi à la main.** C'est une colonne générée par PostgreSQL : quantité × prix unitaire.
- **Le stock se met à jour tout seul.** Trois triggers PL/pgSQL l'augmentent à chaque récolte et le diminuent à chaque vente ou perte. Comme le stock ne peut pas descendre sous zéro, une vente plus grande que le stock disponible est refusée par la base elle-même.
- **Les recherches fréquentes sont indexées** : clés étrangères et dates de récolte et de vente.

## État du projet

Le travail rendu porte sur la base de données. L'application Laravel 12 (avec Vite et Tailwind CSS) est initialisée, mais ses écrans ne sont pas encore développés, et le calcul de la table des rapports statistiques reste à écrire.

## Technologies

PostgreSQL · PL/pgSQL · Laravel 12 · Vite · Tailwind CSS
