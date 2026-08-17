-- Migration 025 : Module BIC — Approche Standard CRR3 (Art. 315-321 CRR3)
-- Hypothèse documentée : ILM (Internal Loss Multiplier) = 1 (non activé dans le cadre réglementaire UE de référence).
-- Note BCEAO : la BCEAO n'a pas publié de seuils propres à ce jour.
-- Ce module est un outil de pilotage interne / benchmark, pas une déclaration réglementaire officielle BCEAO.

CREATE TABLE IF NOT EXISTS op_risk_financial_inputs (
    annee                              INTEGER PRIMARY KEY,
    interets_percus                    REAL    NOT NULL DEFAULT 0,
    interets_verses                    REAL    NOT NULL DEFAULT 0,
    dividendes_percus                  REAL    NOT NULL DEFAULT 0,
    autres_produits_exploitation       REAL    NOT NULL DEFAULT 0,
    autres_charges_exploitation        REAL    NOT NULL DEFAULT 0,
    commissions_percues                REAL    NOT NULL DEFAULT 0,
    commissions_versees                REAL    NOT NULL DEFAULT 0,
    resultat_portefeuille_negociation  REAL    NOT NULL DEFAULT 0,
    resultat_portefeuille_bancaire     REAL    NOT NULL DEFAULT 0,
    tresorerie_et_banques_centrales    REAL    NOT NULL DEFAULT 0,
    creances_etablissements_credit     REAL    NOT NULL DEFAULT 0,
    creances_clientele                 REAL    NOT NULL DEFAULT 0,
    provisions                         REAL    NOT NULL DEFAULT 0,
    pnb                                REAL    NOT NULL DEFAULT 0,
    modifie_le                         TEXT    NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS op_risk_parametres (
    id                    INTEGER PRIMARY KEY CHECK(id = 1),
    seuil_ildc            REAL    NOT NULL DEFAULT 0.0225,
    coef_tranche1         REAL    NOT NULL DEFAULT 0.12,
    coef_tranche2         REAL    NOT NULL DEFAULT 0.15,
    coef_tranche3         REAL    NOT NULL DEFAULT 0.18,
    -- Option A (recommandée) : parité fixe EUR/FCFA (1 EUR = 655,957 FCFA)
    -- seuil1 =  1 Md EUR × 655,957 =  655 957 000 000 FCFA
    -- seuil2 = 30 Mds EUR × 655,957 = 19 678 710 000 000 FCFA
    seuil1_fcfa           REAL    NOT NULL DEFAULT 655957000000,
    seuil2_fcfa           REAL    NOT NULL DEFAULT 19678710000000,
    multiplicateur_rea    REAL    NOT NULL DEFAULT 12.5,      -- 12,5 : multiplicateur reglementaire (paragraphe 90)
    taux_conversion_eur_fcfa REAL NOT NULL DEFAULT 655.957
);

INSERT OR IGNORE INTO op_risk_parametres (id) VALUES (1);
