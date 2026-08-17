-- Migration 028 : Module UEMOI — Pilier 1 (AIB + AS) + seuils reporting Pilier 2
-- Règle : ne dupliquer aucune table existante.
-- op_risk_financial_inputs et op_risk_parametres (BIC/CRR3) déjà créés en migration 025.
-- ro_incidents déjà créé en migration 022 — on ajoute les colonnes manquantes ici.

-- ─── BLOC A1 : Approche Indicateur de Base (AIB) ─────────────────────────────

-- PNB global annuel — données sources communes AIB et AS
CREATE TABLE IF NOT EXISTS op_pnb_annuel (
    annee              INTEGER PRIMARY KEY CHECK(annee BETWEEN 2000 AND 2100),
    produit_brut_total REAL    NOT NULL,        -- valeur réelle, peut être négative
    source_document    TEXT    NOT NULL DEFAULT '',
    modifie_le         TEXT    NOT NULL DEFAULT ''
);

-- Paramètres réglementaires AIB (1 seule ligne)
CREATE TABLE IF NOT EXISTS op_parametres_aib (
    id                    INTEGER PRIMARY KEY CHECK(id = 1),
    alpha                 REAL    NOT NULL DEFAULT 0.15,   -- art. 301 coefficient 15 %
    multiplicateur_rwa    REAL    NOT NULL DEFAULT 12.5,         -- 12,5 : multiplicateur reglementaire (paragraphe 90)
    ratio_solvabilite_min REAL    NOT NULL DEFAULT 0.09    -- Titre III
);
INSERT OR IGNORE INTO op_parametres_aib (id) VALUES (1);

-- ─── BLOC A2 : Approche Standard (AS) ────────────────────────────────────────

-- PNB ventilé par ligne de métier
CREATE TABLE IF NOT EXISTS op_pnb_par_ligne (
    annee              INTEGER NOT NULL,
    ligne_metier       TEXT    NOT NULL,
    produit_brut_ligne REAL    NOT NULL DEFAULT 0,  -- peut être négatif (art. 308)
    modifie_le         TEXT    NOT NULL DEFAULT '',
    PRIMARY KEY (annee, ligne_metier)
);

-- Référentiel des bêtas par ligne de métier (art. 311) — pré-chargé
CREATE TABLE IF NOT EXISTS op_beta_lignes (
    ligne_metier TEXT PRIMARY KEY,
    beta         REAL NOT NULL,
    description  TEXT NOT NULL DEFAULT ''
);
INSERT OR IGNORE INTO op_beta_lignes (ligne_metier, beta, description) VALUES
    ('Financement d''entreprise',   0.18, 'Conseil et services aux grandes entreprises'),
    ('Activités de marché',         0.18, 'Trading, ventes, tenue de marché'),
    ('Paiements et règlements',     0.18, 'Transferts, compensation, règlement-livraison'),
    ('Banque commerciale',          0.15, 'Prêts et dépôts aux entreprises'),
    ('Fonctions d''agent',          0.15, 'Conservation, gestion de fonds institutionnels'),
    ('Banque de détail',            0.12, 'Prêts et dépôts aux particuliers'),
    ('Gestion d''actifs',           0.12, 'Gestion de portefeuilles discrétionnaires'),
    ('Courtage de détail',          0.12, 'Exécution d''ordres pour le compte de tiers');

-- Paramètres AS + drapeau d'autorisation Commission Bancaire (1 seule ligne)
CREATE TABLE IF NOT EXISTS op_parametres_as (
    id                     INTEGER PRIMARY KEY CHECK(id = 1),
    as_autorisee           INTEGER NOT NULL DEFAULT 0,   -- 0 = FALSE, 1 = TRUE
    date_autorisation      TEXT    NOT NULL DEFAULT '',
    reference_autorisation TEXT    NOT NULL DEFAULT '',
    multiplicateur_rwa     REAL    NOT NULL DEFAULT 12.5,        -- 12,5 : multiplicateur reglementaire (paragraphe 90)
    ratio_solvabilite_min  REAL    NOT NULL DEFAULT 0.09
);
INSERT OR IGNORE INTO op_parametres_as (id) VALUES (1);

-- ─── Seuils de reporting Pilier 2 (table op_parametres_seuils) ───────────────
CREATE TABLE IF NOT EXISTS op_parametres_seuils (
    id                        INTEGER PRIMARY KEY CHECK(id = 1),
    seuil_reporting_interne   REAL    NOT NULL DEFAULT 500000,
    seuil_reporting_direction REAL    NOT NULL DEFAULT 2000000,
    seuil_reporting_conseil   REAL    NOT NULL DEFAULT 10000000
);
INSERT OR IGNORE INTO op_parametres_seuils (id) VALUES (1);

-- ─── Extension de ro_incidents pour le Pilier 2 PIEAFP complet ───────────────
-- SQLite : on ajoute les colonnes si elles n'existent pas déjà.
-- ALTER TABLE ne supporte pas IF NOT EXISTS, donc on encapsule dans des triggers
-- ou on gère ça côté application.  SQLite autorise ADD COLUMN sans condition.
-- Si la colonne existe déjà, l'instruction génère une erreur silencieuse grâce
-- au IGNORE dans la couche Python de démarrage.

ALTER TABLE ro_incidents ADD COLUMN date_survenance       TEXT NOT NULL DEFAULT '';
ALTER TABLE ro_incidents ADD COLUMN date_detection        TEXT NOT NULL DEFAULT '';
ALTER TABLE ro_incidents ADD COLUMN date_comptabilisation TEXT NOT NULL DEFAULT '';
ALTER TABLE ro_incidents ADD COLUMN categorie_risque      TEXT NOT NULL DEFAULT '';
ALTER TABLE ro_incidents ADD COLUMN provision_constituee  REAL NOT NULL DEFAULT 0;
ALTER TABLE ro_incidents ADD COLUMN date_cloture          TEXT NOT NULL DEFAULT '';
ALTER TABLE ro_incidents ADD COLUMN action_corrective     TEXT NOT NULL DEFAULT '';
ALTER TABLE ro_incidents ADD COLUMN responsable_action    TEXT NOT NULL DEFAULT '';
ALTER TABLE ro_incidents ADD COLUMN date_limite_action    TEXT NOT NULL DEFAULT '';
ALTER TABLE ro_incidents ADD COLUMN action_realisee       TEXT NOT NULL DEFAULT '';
