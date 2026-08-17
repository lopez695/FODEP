-- Migration 029 : Correction du ratio de solvabilite minimum UMOA (8% -> 9%)
-- Contexte : le dispositif prudentiel BCEAO retient un ratio de solvabilite
-- minimum de 9 % (cf. MIN_SOLVENCY_RATIO dans app/core/bceao_calculations.py
-- et app/core/calculations.py). Les migrations 025 et 028 avaient seede des
-- valeurs par defaut incoherentes (8 % / multiplicateur 12,5 = 1/0.08) au
-- lieu de 9 % / 11,111111 = 1/0.09. Cette migration corrige les lignes deja
-- persistees dans les bases existantes (les DEFAULT des CREATE TABLE ont ete
-- corriges directement dans 025 et 028, mais cela n'affecte pas les bases
-- deja initialisees).

UPDATE op_parametres_aib
   SET ratio_solvabilite_min = 0.09
 WHERE ratio_solvabilite_min = 0.08;

UPDATE op_parametres_aib
   SET multiplicateur_rwa = 11.111111
 WHERE multiplicateur_rwa = 12.5;

UPDATE op_parametres_as
   SET ratio_solvabilite_min = 0.09
 WHERE ratio_solvabilite_min = 0.08;

UPDATE op_parametres_as
   SET multiplicateur_rwa = 11.111111
 WHERE multiplicateur_rwa = 12.5;

UPDATE op_risk_parametres
   SET multiplicateur_rea = 11.111111
 WHERE multiplicateur_rea = 12.5;
