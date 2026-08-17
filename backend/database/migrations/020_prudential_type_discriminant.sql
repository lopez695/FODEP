-- Migration 020 : ajout du discriminant prudential_type sur exposures.
-- Corrige la violation MERISE : sans colonne discriminante, une même exposition
-- pouvait avoir des lignes dans plusieurs sous-tables de type simultanément,
-- et le type devait être inféré depuis counterparties.category_prudential (indirect).
-- Après cette migration, exposures.prudential_type est la source de vérité unique.

-- ── 1. Table exposure_high_risk (cat. j : créances à risque élevé) ──────────
-- Créée d'abord car la phase de backfill ci-dessous y fait référence.
-- Cette catégorie a une pondération fixe à 150% (aucun attribut supplémentaire).
-- La table sert uniquement de marqueur de type dans l'héritage MERISE.

CREATE TABLE IF NOT EXISTS exposure_high_risk (
    exposure_id TEXT PRIMARY KEY,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_exp_high_risk ON exposure_high_risk(exposure_id);

-- ── 2. Ajout du discriminant ─────────────────────────────────────────────────

ALTER TABLE exposures ADD COLUMN prudential_type TEXT NOT NULL DEFAULT '';

-- Backfill depuis la contrepartie associée (source canonique initiale)
UPDATE exposures
SET prudential_type = (
    SELECT category_prudential
    FROM counterparties
    WHERE counterparties.id = exposures.counterparty_id
);

-- Sécurité : si la contrepartie manque ou category_prudential est vide, on
-- déduit le type depuis la sous-table qui a une ligne (priorité alphabétique).
UPDATE exposures
SET prudential_type = CASE
    WHEN EXISTS (SELECT 1 FROM exposure_sovereign              WHERE exposure_id = exposures.id) THEN 'a'
    WHEN EXISTS (SELECT 1 FROM exposure_public_body            WHERE exposure_id = exposures.id) THEN 'b'
    WHEN EXISTS (SELECT 1 FROM exposure_bmd                    WHERE exposure_id = exposures.id) THEN 'c'
    WHEN EXISTS (SELECT 1 FROM exposure_bank                   WHERE exposure_id = exposures.id) THEN 'd'
    WHEN EXISTS (SELECT 1 FROM exposure_enterprise             WHERE exposure_id = exposures.id) THEN 'e'
    WHEN EXISTS (SELECT 1 FROM exposure_retail                 WHERE exposure_id = exposures.id) THEN 'f'
    WHEN EXISTS (SELECT 1 FROM exposure_residential_mortgage   WHERE exposure_id = exposures.id) THEN 'g'
    WHEN EXISTS (SELECT 1 FROM exposure_commercial_real_estate WHERE exposure_id = exposures.id) THEN 'h'
    WHEN EXISTS (SELECT 1 FROM exposure_defaulted              WHERE exposure_id = exposures.id) THEN 'i'
    WHEN EXISTS (SELECT 1 FROM exposure_high_risk              WHERE exposure_id = exposures.id) THEN 'j'
    WHEN EXISTS (SELECT 1 FROM exposure_other_asset            WHERE exposure_id = exposures.id) THEN 'k'
    WHEN EXISTS (SELECT 1 FROM exposure_off_balance_detail     WHERE exposure_id = exposures.id) THEN 'l'
    ELSE prudential_type
END
WHERE prudential_type = '';

-- Fallback final : entreprise (catégorie par défaut la plus courante)
UPDATE exposures SET prudential_type = 'e' WHERE prudential_type = '';

CREATE INDEX IF NOT EXISTS idx_exposures_prudential_type ON exposures(prudential_type);

-- ── 3. Backfill exposure_high_risk depuis les contreparties cat. j ───────────
INSERT OR IGNORE INTO exposure_high_risk(exposure_id)
SELECT id FROM exposures WHERE prudential_type = 'j';
