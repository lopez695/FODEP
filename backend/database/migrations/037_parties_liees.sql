-- Parties liées : actionnaires, dirigeants et personnel, exigés par les états
-- EP38 (montant des concours) et EP39 (liste nominative) du FODEP, et par la
-- norme RA011 de l'EP01.
--
-- Les six catégories sont exactement les colonnes du formulaire. Coller à ce
-- découpage évite d'avoir à reclasser à l'export : chaque valeur désigne une
-- colonne, sans interprétation.
--
-- Sans ce rattachement, l'EP01 déclarait « CONFORME » la limite sur les prêts
-- aux actionnaires et dirigeants sans qu'aucun encours ne l'ait mesurée.
ALTER TABLE contreparties ADD COLUMN categorie_partie_liee TEXT
    CHECK(categorie_partie_liee IS NULL OR categorie_partie_liee IN (
        'actionnaire',          -- détenant individuellement au moins 10 %
        'organe_deliberant',    -- membres du conseil, hors actionnaires
        'organe_executif',      -- direction générale, hors colonnes a et b
        'commissaire_comptes',
        'personnel_direction',
        'cadre'                 -- cadres moyens et supérieurs
    ));

CREATE INDEX IF NOT EXISTS idx_contreparties_partie_liee
    ON contreparties(categorie_partie_liee);
