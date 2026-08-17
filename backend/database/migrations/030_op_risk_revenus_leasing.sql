-- Migration 030 : Ajout du poste "revenus de leasing" aux entrées financières
-- BIC (CRR3 Art. 314 : composante ILDC, incluse dans les produits d'intérêts).
ALTER TABLE op_risk_financial_inputs ADD COLUMN revenus_leasing REAL NOT NULL DEFAULT 0;
