-- Migration 032 : Retablissement du multiplicateur RWA reglementaire (12,5)
-- Contexte : le dispositif prudentiel UMOA (Titre III, paragraphe 90) definit
-- le ratio de solvabilite comme :
--   FP / (APR credit + 12,5 x risque operationnel + 12,5 x risque de marche)
-- Le multiplicateur des exigences de fonds propres marche/operationnel en
-- equivalent RWA est donc 12,5, fixe par le texte, INDEPENDAMMENT du ratio
-- de solvabilite minimum (9 %). La migration 029 l'avait remplace a tort par
-- 1/0,09 = 11,111111 (confusion entre les deux notions). Le ratio de
-- solvabilite minimum de 9 % (paragraphe 91c), lui, etait correct et reste
-- inchange.

UPDATE op_parametres_aib
   SET multiplicateur_rwa = 12.5
 WHERE multiplicateur_rwa BETWEEN 11.11 AND 11.12;

UPDATE op_parametres_as
   SET multiplicateur_rwa = 12.5
 WHERE multiplicateur_rwa BETWEEN 11.11 AND 11.12;

UPDATE op_risk_parametres
   SET multiplicateur_rea = 12.5
 WHERE multiplicateur_rea BETWEEN 11.11 AND 11.12;
