# Analyse des ventes e-commerce Olist

Projet d’analyse de données réalisé avec **SQL, PostgreSQL et Power BI**, à partir des données publiques de la plateforme brésilienne Olist.

L’objectif est de préparer et fiabiliser les données, puis de construire un dashboard interactif pour suivre les ventes, comparer les performances mensuelles et identifier les catégories les plus contributrices.

## Source des données

[Brazilian E-Commerce Public Dataset by Olist — Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

Les données sont réparties dans sept fichiers utilisés pour ce projet :

- Commandes.
- Articles des commandes.
- Produits.
- Traductions des catégories.
- Clients.
- Vendeurs.
- Paiements.

Les fichiers sources ne sont pas inclus dans ce dépôt et doivent être téléchargés depuis Kaggle.

## Périmètre et règles de calcul

- **Commandes retenues :** commandes livrées (`delivered`).
- **Date d’analyse :** date d’achat.
- **Période comparative :** janvier 2017 à juillet 2018 inclus, soit 19 mois.
- **Ventes :** somme des prix des articles, hors frais de livraison.
- **Devise :** réal brésilien (BRL).
- **Granularité :** une ligne par article de commande.
- **Catégories manquantes :** regroupées sous « Non renseignée ».
- **Traductions absentes :** conservation du nom portugais.

Les montants analysés correspondent aux ventes des produits sur la plateforme, et non au chiffre d’affaires propre d’Olist.

## Travail réalisé

### 1. Importation et contrôle des données

Création des tables PostgreSQL et importation des fichiers CSV.

Contrôles réalisés :

- Volumes importés.
- Unicité et présence des identifiants.
- Unicité du couple commande–article.
- Prix et frais de livraison manquants ou négatifs.
- Cohérence des références entre les tables.
- Statuts et couverture temporelle des commandes.
- Catégories manquantes et traductions absentes.

### 2. Préparation des données en SQL

Création de quatre vues dans le schéma `analytics` :

| Vue | Contenu |
|---|---|
| `fact_ventes` | Articles des commandes livrées |
| `dim_produits` | Produits et catégories |
| `dim_clients` | Clients et localisation |
| `dim_vendeurs` | Vendeurs et localisation |

Utilisation de CTE, de jointures et de fonctions de traitement des valeurs manquantes.

### 3. Analyses SQL

- Ventes, commandes et panier moyen par mois.
- Comparaison avec le mois précédent à l’aide de `LAG()`.
- Écarts mensuels en BRL et en pourcentage.
- Ventes et contribution par catégorie.
- Moyenne mensuelle sur les 19 mois retenus.

Les résultats SQL servent de référence pour vérifier les indicateurs Power BI.

## Technologies utilisées

PostgreSQL 17 · pgAdmin · SQL · Power Query · Power BI · DAX

## Portfolio

[Consulter mon portfolio](https://abirmontigny.carrd.co/)
