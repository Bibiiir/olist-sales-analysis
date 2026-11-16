/*
 PROJET : Analyse des ventes e-commerce Olist
 Auteure : Abir Montigny
 SGBD : PostgreSQL 17
 Source : https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

 EXECUTION
 1. Creer la base olist_analytics dans pgAdmin et s'y connecter.
 2. Executer la section 1 pour creer les tables sources.
 3. Importer les CSV correspondants via Import/Export Data :
    CSV, UTF8, separateur virgule, Header = Yes. Une seule importation par table.
 4. Executer les controles de la section 2 et examiner les anomalies.
 5. Creer les vues (section 3), puis executer les analyses (section 4).
 Les CSV ne sont pas inclus dans ce depot. Aucun mot de passe n'est necessaire ici.

 REGLES METIER
 - Commandes livrees uniquement ; date d'analyse = date d'achat.
 - Ventes = somme du prix des articles, hors livraison, en BRL.
 - Il ne s'agit pas du chiffre d'affaires propre de la plateforme Olist.
 - Les vues conservent toutes les dates disponibles.
 - Analyses comparatives : janvier 2017 a juillet 2018 inclus (19 mois).
 - Categorie absente : 'Non renseignee' ; traduction absente : nom portugais.
 - Grain des ventes : une ligne par couple (order_id, order_item_id).

 Le script ne supprime et ne vide aucune table. IF NOT EXISTS ne verifie pas
 la structure d'une table preexistante : utiliser les colonnes definies ci-dessous.
*/

-- 1. STRUCTURE ET IMPORTATION DES SOURCES
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS analytics;

-- olist_orders_dataset.csv
CREATE TABLE IF NOT EXISTS raw.orders (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

-- olist_order_items_dataset.csv
CREATE TABLE IF NOT EXISTS raw.order_items (
    order_id TEXT,
    order_item_id INTEGER,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12, 2),
    freight_value NUMERIC(12, 2)
);

-- olist_products_dataset.csv : noms d'origine conserves, dont 'lenght'.
CREATE TABLE IF NOT EXISTS raw.products (
    product_id TEXT,
    product_category_name TEXT,
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);

-- product_category_name_translation.csv
CREATE TABLE IF NOT EXISTS raw.category_translation (
    product_category_name TEXT,
    product_category_name_english TEXT
);

-- olist_customers_dataset.csv
CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id TEXT,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT
);

-- olist_sellers_dataset.csv
CREATE TABLE IF NOT EXISTS raw.sellers (
    seller_id TEXT,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state TEXT
);

-- olist_order_payments_dataset.csv
CREATE TABLE IF NOT EXISTS raw.order_payments (
    order_id TEXT,
    payment_sequential INTEGER,
    payment_type TEXT,
    payment_installments INTEGER,
    payment_value NUMERIC(12, 2)
);

-- Importer les sept CSV avant de poursuivre.

-- 2. CONTROLES QUALITE

-- 2.1. Volumes importes
SELECT 'orders' AS table_name, COUNT(*) AS nombre_lignes FROM raw.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM raw.order_items
UNION ALL SELECT 'products', COUNT(*) FROM raw.products
UNION ALL SELECT 'category_translation', COUNT(*) FROM raw.category_translation
UNION ALL SELECT 'customers', COUNT(*) FROM raw.customers
UNION ALL SELECT 'sellers', COUNT(*) FROM raw.sellers
UNION ALL SELECT 'order_payments', COUNT(*) FROM raw.order_payments;

-- 2.2. Unicite et presence des identifiants des commandes et dimensions
SELECT 'orders' AS table_name, COUNT(*) AS nombre_lignes,
       COUNT(DISTINCT order_id) AS identifiants_distincts,
       COUNT(*) FILTER (WHERE NULLIF(TRIM(order_id), '') IS NULL) AS identifiants_manquants
FROM raw.orders
UNION ALL
SELECT 'products', COUNT(*), COUNT(DISTINCT product_id),
       COUNT(*) FILTER (WHERE NULLIF(TRIM(product_id), '') IS NULL)
FROM raw.products
UNION ALL
SELECT 'customers', COUNT(*), COUNT(DISTINCT customer_id),
       COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_id), '') IS NULL)
FROM raw.customers
UNION ALL
SELECT 'sellers', COUNT(*), COUNT(DISTINCT seller_id),
       COUNT(*) FILTER (WHERE NULLIF(TRIM(seller_id), '') IS NULL)
FROM raw.sellers;

-- 2.3. Unicite de chaque article dans sa commande
SELECT COUNT(*) AS nombre_lignes,
       COUNT(DISTINCT (order_id, order_item_id)) AS articles_distincts,
       COUNT(*) FILTER (
           WHERE NULLIF(TRIM(order_id), '') IS NULL OR order_item_id IS NULL
       ) AS cles_incompletes
FROM raw.order_items;

-- 2.4. Prix et frais de livraison : un montant nul n'est pas une valeur absente.
SELECT COUNT(*) FILTER (WHERE price IS NULL) AS prix_manquants,
       COUNT(*) FILTER (WHERE price < 0) AS prix_negatifs,
       COUNT(*) FILTER (WHERE price = 0) AS prix_a_zero,
       COUNT(*) FILTER (WHERE freight_value IS NULL) AS frais_manquants,
       COUNT(*) FILTER (WHERE freight_value < 0) AS frais_negatifs,
       COUNT(*) FILTER (WHERE freight_value = 0) AS frais_a_zero
FROM raw.order_items;

-- 2.5. References des articles. DISTINCT evite de multiplier les lignes du controle.
SELECT COUNT(*) FILTER (WHERE o.order_id IS NULL) AS articles_sans_commande,
       COUNT(*) FILTER (WHERE p.product_id IS NULL) AS articles_sans_produit,
       COUNT(*) FILTER (WHERE s.seller_id IS NULL) AS articles_sans_vendeur
FROM raw.order_items i
LEFT JOIN (SELECT DISTINCT order_id FROM raw.orders) o ON o.order_id = i.order_id
LEFT JOIN (SELECT DISTINCT product_id FROM raw.products) p ON p.product_id = i.product_id
LEFT JOIN (SELECT DISTINCT seller_id FROM raw.sellers) s ON s.seller_id = i.seller_id;

-- 2.6. Statuts et couverture temporelle
SELECT order_status AS statut, COUNT(*) AS nombre_commandes,
       MIN(order_purchase_timestamp) AS premier_achat,
       MAX(order_purchase_timestamp) AS dernier_achat,
       COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS dates_manquantes
FROM raw.orders
GROUP BY order_status
ORDER BY nombre_commandes DESC;

SELECT DATE_TRUNC('month', order_purchase_timestamp)::DATE AS mois,
       COUNT(*) AS commandes_livrees
FROM raw.orders
WHERE order_status = 'delivered'
GROUP BY 1
ORDER BY 1;

-- 2.7. Categories et traductions
SELECT COUNT(*) AS nombre_produits,
       COUNT(*) FILTER (
           WHERE NULLIF(TRIM(p.product_category_name), '') IS NULL
       ) AS produits_sans_categorie,
       COUNT(*) FILTER (
           WHERE NULLIF(TRIM(p.product_category_name), '') IS NOT NULL
             AND NOT EXISTS (
                 SELECT 1 FROM raw.category_translation t
                 WHERE t.product_category_name = p.product_category_name
                   AND NULLIF(TRIM(t.product_category_name_english), '') IS NOT NULL
             )
       ) AS produits_avec_categorie_sans_traduction
FROM raw.products p;

-- Cette requete doit retourner zero ligne avant la jointure des traductions.
SELECT product_category_name, COUNT(*) AS nombre_lignes
FROM raw.category_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;

-- 3. VUES POUR POWER BI

CREATE OR REPLACE VIEW analytics.fact_ventes AS
WITH commandes_livrees AS (
    SELECT order_id, customer_id,
           order_purchase_timestamp::DATE AS date_achat
    FROM raw.orders
    WHERE order_status = 'delivered'
)
SELECT i.order_id, i.order_item_id, c.date_achat,
       c.customer_id, cl.customer_unique_id, i.product_id, i.seller_id,
       COALESCE(NULLIF(TRIM(t.product_category_name_english), ''),
                NULLIF(TRIM(p.product_category_name), ''),
                'Non renseignée') AS categorie,
       cl.customer_city AS ville_client, cl.customer_state AS etat_client,
       i.price AS prix_article, i.freight_value AS frais_livraison
FROM commandes_livrees c
JOIN raw.order_items i ON i.order_id = c.order_id
JOIN raw.customers cl ON cl.customer_id = c.customer_id
JOIN raw.products p ON p.product_id = i.product_id
LEFT JOIN raw.category_translation t
    ON t.product_category_name = p.product_category_name;

CREATE OR REPLACE VIEW analytics.dim_produits AS
SELECT p.product_id,
       COALESCE(NULLIF(TRIM(t.product_category_name_english), ''),
                NULLIF(TRIM(p.product_category_name), ''),
                'Non renseignée') AS categorie,
       p.product_weight_g AS poids_g, p.product_length_cm AS longueur_cm,
       p.product_height_cm AS hauteur_cm, p.product_width_cm AS largeur_cm
FROM raw.products p
LEFT JOIN raw.category_translation t
    ON t.product_category_name = p.product_category_name;

CREATE OR REPLACE VIEW analytics.dim_clients AS
SELECT customer_id, customer_unique_id,
       customer_zip_code_prefix AS code_postal_prefixe,
       customer_city AS ville, customer_state AS etat
FROM raw.customers;

CREATE OR REPLACE VIEW analytics.dim_vendeurs AS
SELECT seller_id, seller_zip_code_prefix AS code_postal_prefixe,
       seller_city AS ville, seller_state AS etat
FROM raw.sellers;

-- Controle de la vue sur toutes les dates :
-- 110197 articles distincts, 96478 commandes,
-- ventes = 13221498.11 BRL ; frais = 2198275.64 BRL.
SELECT COUNT(*) AS nombre_articles,
       COUNT(DISTINCT (order_id, order_item_id)) AS articles_distincts,
       COUNT(DISTINCT order_id) AS commandes_avec_articles,
       SUM(prix_article) AS ventes_brl,
       SUM(frais_livraison) AS frais_livraison_brl
FROM analytics.fact_ventes;

-- Ne pas joindre directement les paiements aux articles : plusieurs lignes
-- de chaque cote par commande peuvent multiplier les montants.
-- Les paiements ne sont pas necessaires au perimetre du dashboard actuel.

-- 4. ANALYSES DE REFERENCE : JANVIER 2017 A JUILLET 2018

-- 4.1. Indicateurs mensuels ; panier moyen hors livraison.
SELECT DATE_TRUNC('month', date_achat)::DATE AS mois,
       COUNT(DISTINCT order_id) AS nombre_commandes,
       COUNT(*) AS nombre_articles,
       SUM(prix_article) AS ventes_brl,
       ROUND(SUM(prix_article) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS panier_moyen_brl,
       SUM(frais_livraison) AS frais_livraison_brl
FROM analytics.fact_ventes
WHERE date_achat >= DATE '2017-01-01' AND date_achat < DATE '2018-08-01'
GROUP BY 1
ORDER BY 1;

-- 4.2. Comparaisons mensuelles.
-- Les 19 mois sont presents : LAG correspond donc bien au mois precedent.
-- Janvier 2017 n'a pas de comparaison dans le perimetre SQL retenu.
WITH ventes_mensuelles AS (
    SELECT DATE_TRUNC('month', date_achat)::DATE AS mois,
           SUM(prix_article) AS ventes_brl
    FROM analytics.fact_ventes
    WHERE date_achat >= DATE '2017-01-01' AND date_achat < DATE '2018-08-01'
    GROUP BY 1
), comparaison AS (
    SELECT mois, ventes_brl,
           LAG(ventes_brl) OVER (ORDER BY mois) AS ventes_mois_precedent
    FROM ventes_mensuelles
)
SELECT mois, ventes_brl, ventes_mois_precedent,
       ventes_brl - ventes_mois_precedent AS ecart_brl,
       ROUND(100.0 * (ventes_brl - ventes_mois_precedent)
             / NULLIF(ventes_mois_precedent, 0), 2) AS evolution_pct
FROM comparaison
ORDER BY mois;

-- 4.3. Ventes et contribution par categorie.
-- Une commande peut appartenir a plusieurs categories : ne pas additionner
-- les nombres de commandes des categories pour obtenir le total global.
WITH ventes_categories AS (
    SELECT categorie, SUM(prix_article) AS ventes_brl,
           COUNT(DISTINCT order_id) AS nombre_commandes,
           COUNT(*) AS nombre_articles
    FROM analytics.fact_ventes
    WHERE date_achat >= DATE '2017-01-01' AND date_achat < DATE '2018-08-01'
    GROUP BY categorie
)
SELECT categorie, ventes_brl, nombre_commandes, nombre_articles,
       ROUND(100.0 * ventes_brl / NULLIF(SUM(ventes_brl) OVER (), 0), 2) AS contribution_pct
FROM ventes_categories
ORDER BY ventes_brl DESC;

-- 4.4. Moyenne mensuelle utilisee dans la carte Power BI.
-- Moyenne sur les 19 mois fixes, independante du mois selectionne.
SELECT ROUND(SUM(prix_article) / 19, 2) AS moyenne_mensuelle_brl
FROM analytics.fact_ventes
WHERE date_achat >= DATE '2017-01-01' AND date_achat < DATE '2018-08-01';

-- POWER BI : importer les quatre vues du schema analytics.
-- Retirer categorie, ville_client et etat_client de fact_ventes dans Power Query
-- (ces attributs restent accessibles via les dimensions).
-- Ajouter le calendrier et les mesures DAX dans Power BI.
