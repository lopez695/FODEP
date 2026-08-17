-- Migration 019 : décomposition MERISE de la table exposures en sous-entités par type prudentiel.
-- Chaque type d'exposition obtient sa propre table (relation 1:0-1 avec exposures).
-- Les colonnes de type sont supprimées de la table principale.

-- ── Sous-tables par type prudentiel ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS exposure_sovereign (
    exposure_id TEXT PRIMARY KEY,
    special_case TEXT NOT NULL DEFAULT '',
    preferential_zero_weight INTEGER NOT NULL DEFAULT 0,
    oce_established INTEGER NOT NULL DEFAULT 0,
    oce_note TEXT NOT NULL DEFAULT '',
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposure_public_body (
    exposure_id TEXT PRIMARY KEY,
    uemoa_fcfa_case INTEGER,
    non_public_activity INTEGER,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposure_bmd (
    exposure_id TEXT PRIMARY KEY,
    high_quality_case INTEGER,
    uemoa_fcfa_case INTEGER,
    uemoa_criteria_satisfied INTEGER,
    listed_institution_fcfa_case INTEGER,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposure_bank (
    exposure_id TEXT PRIMARY KEY,
    institution_case TEXT,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposure_retail (
    exposure_id TEXT PRIMARY KEY,
    eligibility_criteria_satisfied INTEGER,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposure_residential_mortgage (
    exposure_id TEXT PRIMARY KEY,
    eligible INTEGER,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposure_commercial_real_estate (
    exposure_id TEXT PRIMARY KEY,
    eligible INTEGER,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposure_defaulted (
    exposure_id TEXT PRIMARY KEY,
    initial_risk_weight REAL,
    residential_mortgage_in_default INTEGER,
    provision_at_least_twenty_percent INTEGER,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposure_enterprise (
    exposure_id TEXT PRIMARY KEY,
    exceeds_bceao_degradation_threshold INTEGER,
    prudential_procedure INTEGER,
    investment_firm_without_banking_law INTEGER,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposure_other_asset (
    exposure_id TEXT PRIMARY KEY,
    asset_type TEXT,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposure_off_balance_detail (
    exposure_id TEXT PRIMARY KEY,
    risk_level TEXT,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

-- ── Index sur les sous-tables ────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_exp_sovereign ON exposure_sovereign(exposure_id);
CREATE INDEX IF NOT EXISTS idx_exp_public_body ON exposure_public_body(exposure_id);
CREATE INDEX IF NOT EXISTS idx_exp_bmd ON exposure_bmd(exposure_id);
CREATE INDEX IF NOT EXISTS idx_exp_bank ON exposure_bank(exposure_id);
CREATE INDEX IF NOT EXISTS idx_exp_retail ON exposure_retail(exposure_id);
CREATE INDEX IF NOT EXISTS idx_exp_res_mortgage ON exposure_residential_mortgage(exposure_id);
CREATE INDEX IF NOT EXISTS idx_exp_comm_re ON exposure_commercial_real_estate(exposure_id);
CREATE INDEX IF NOT EXISTS idx_exp_defaulted ON exposure_defaulted(exposure_id);
CREATE INDEX IF NOT EXISTS idx_exp_enterprise ON exposure_enterprise(exposure_id);
CREATE INDEX IF NOT EXISTS idx_exp_other_asset ON exposure_other_asset(exposure_id);
CREATE INDEX IF NOT EXISTS idx_exp_off_balance ON exposure_off_balance_detail(exposure_id);

-- ── Migration des données existantes ────────────────────────────────────────

INSERT OR IGNORE INTO exposure_sovereign(exposure_id, special_case, preferential_zero_weight, oce_established, oce_note)
SELECT id,
       COALESCE(sovereign_special_case, ''),
       COALESCE(sovereign_preferential_zero_weight, 0),
       COALESCE(sovereign_oce_established, 0),
       COALESCE(sovereign_oce_note, '')
FROM exposures
WHERE sovereign_special_case != ''
   OR sovereign_preferential_zero_weight != 0
   OR sovereign_oce_established != 0
   OR sovereign_oce_note != '';

INSERT OR IGNORE INTO exposure_public_body(exposure_id, uemoa_fcfa_case, non_public_activity)
SELECT id, public_body_uemoa_fcfa_case, public_body_non_public_activity
FROM exposures
WHERE public_body_uemoa_fcfa_case IS NOT NULL
   OR public_body_non_public_activity IS NOT NULL;

INSERT OR IGNORE INTO exposure_bmd(exposure_id, high_quality_case, uemoa_fcfa_case, uemoa_criteria_satisfied, listed_institution_fcfa_case)
SELECT id, bmd_high_quality_case, bmd_uemoa_fcfa_case, bmd_uemoa_criteria_satisfied, bmd_listed_institution_fcfa_case
FROM exposures
WHERE bmd_high_quality_case IS NOT NULL
   OR bmd_uemoa_fcfa_case IS NOT NULL
   OR bmd_uemoa_criteria_satisfied IS NOT NULL
   OR bmd_listed_institution_fcfa_case IS NOT NULL;

INSERT OR IGNORE INTO exposure_bank(exposure_id, institution_case)
SELECT id, bank_institution_case
FROM exposures
WHERE bank_institution_case IS NOT NULL AND bank_institution_case != '';

INSERT OR IGNORE INTO exposure_retail(exposure_id, eligibility_criteria_satisfied)
SELECT id, retail_eligibility_criteria_satisfied
FROM exposures
WHERE retail_eligibility_criteria_satisfied IS NOT NULL;

INSERT OR IGNORE INTO exposure_residential_mortgage(exposure_id, eligible)
SELECT id, residential_mortgage_eligible
FROM exposures
WHERE residential_mortgage_eligible IS NOT NULL;

INSERT OR IGNORE INTO exposure_commercial_real_estate(exposure_id, eligible)
SELECT id, commercial_real_estate_eligible
FROM exposures
WHERE commercial_real_estate_eligible IS NOT NULL;

INSERT OR IGNORE INTO exposure_defaulted(exposure_id, initial_risk_weight, residential_mortgage_in_default, provision_at_least_twenty_percent)
SELECT id,
       defaulted_exposure_initial_risk_weight,
       defaulted_exposure_residential_mortgage_in_default,
       defaulted_exposure_provision_at_least_twenty_percent
FROM exposures
WHERE defaulted_exposure_initial_risk_weight IS NOT NULL
   OR defaulted_exposure_residential_mortgage_in_default IS NOT NULL
   OR defaulted_exposure_provision_at_least_twenty_percent IS NOT NULL;

INSERT OR IGNORE INTO exposure_enterprise(exposure_id, exceeds_bceao_degradation_threshold, prudential_procedure, investment_firm_without_banking_law)
SELECT id,
       enterprise_exceeds_bceao_degradation_threshold,
       enterprise_prudential_procedure,
       enterprise_investment_firm_without_banking_law
FROM exposures
WHERE enterprise_exceeds_bceao_degradation_threshold IS NOT NULL
   OR enterprise_prudential_procedure IS NOT NULL
   OR enterprise_investment_firm_without_banking_law IS NOT NULL;

INSERT OR IGNORE INTO exposure_other_asset(exposure_id, asset_type)
SELECT id, other_asset_type
FROM exposures
WHERE other_asset_type IS NOT NULL AND other_asset_type != '';

INSERT OR IGNORE INTO exposure_off_balance_detail(exposure_id, risk_level)
SELECT id, off_balance_risk_level
FROM exposures
WHERE off_balance_risk_level IS NOT NULL AND off_balance_risk_level != '';

-- ── Suppression des colonnes déplacées de la table exposures ────────────────
-- SQLite >= 3.35.0 requis (disponible depuis 2021-03-12)

ALTER TABLE exposures DROP COLUMN sovereign_special_case;
ALTER TABLE exposures DROP COLUMN sovereign_preferential_zero_weight;
ALTER TABLE exposures DROP COLUMN sovereign_oce_established;
ALTER TABLE exposures DROP COLUMN sovereign_oce_note;
ALTER TABLE exposures DROP COLUMN public_body_uemoa_fcfa_case;
ALTER TABLE exposures DROP COLUMN public_body_non_public_activity;
ALTER TABLE exposures DROP COLUMN bmd_high_quality_case;
ALTER TABLE exposures DROP COLUMN bmd_uemoa_fcfa_case;
ALTER TABLE exposures DROP COLUMN bmd_uemoa_criteria_satisfied;
ALTER TABLE exposures DROP COLUMN bmd_listed_institution_fcfa_case;
ALTER TABLE exposures DROP COLUMN bank_institution_case;
ALTER TABLE exposures DROP COLUMN other_asset_type;
ALTER TABLE exposures DROP COLUMN off_balance_risk_level;
ALTER TABLE exposures DROP COLUMN retail_eligibility_criteria_satisfied;
ALTER TABLE exposures DROP COLUMN residential_mortgage_eligible;
ALTER TABLE exposures DROP COLUMN commercial_real_estate_eligible;
ALTER TABLE exposures DROP COLUMN defaulted_exposure_initial_risk_weight;
ALTER TABLE exposures DROP COLUMN defaulted_exposure_residential_mortgage_in_default;
ALTER TABLE exposures DROP COLUMN defaulted_exposure_provision_at_least_twenty_percent;
ALTER TABLE exposures DROP COLUMN enterprise_exceeds_bceao_degradation_threshold;
ALTER TABLE exposures DROP COLUMN enterprise_prudential_procedure;
ALTER TABLE exposures DROP COLUMN enterprise_investment_firm_without_banking_law;

-- ── Contraintes CHECK sur les valeurs numériques ─────────────────────────────
-- (Ajoutées via nouvelles tables ; les tables existantes ne supportent pas
--  ALTER TABLE ADD CONSTRAINT en SQLite — elles sont correctes à la création.)
