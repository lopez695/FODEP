-- L'EP38 et l'EP39 comptent huit colonnes de bénéficiaires, non six : la
-- migration précédente en avait omis deux, « Personnel d'exécution » et
-- « Autres parties liées ». La contrainte est reconstruite sur la liste
-- complète, dans l'ordre des colonnes du formulaire.
--
-- La colonne vient d'être créée et n'est encore renseignée nulle part : la
-- recréer ne perd donc aucune déclaration.
--
-- L'index de la migration 037 doit partir en premier : SQLite refuse de
-- supprimer une colonne qu'un index retient, et cette instruction échouait
-- donc systématiquement — « error in index idx_contreparties_partie_liee
-- after drop column ». Les bases déjà installées sont rattrapées par la
-- migration 041, celle-ci ne servant plus qu'aux installations neuves.
DROP INDEX IF EXISTS idx_contreparties_partie_liee;

ALTER TABLE contreparties DROP COLUMN categorie_partie_liee;

ALTER TABLE contreparties ADD COLUMN categorie_partie_liee TEXT
    CHECK(categorie_partie_liee IS NULL OR categorie_partie_liee IN (
        'actionnaire',          -- (a) détenant individuellement au moins 10 %
        'organe_deliberant',    -- (b) membres du conseil, hors actionnaires
        'organe_executif',      -- (c) direction générale, hors (a) et (b)
        'commissaire_comptes',  -- (d)
        'personnel_direction',  -- (e)
        'cadre',                -- (f) cadres moyens et supérieurs
        'personnel_execution',  -- (g)
        'autre_partie_liee'     -- (h)
    ));

CREATE INDEX IF NOT EXISTS idx_contreparties_partie_liee
    ON contreparties(categorie_partie_liee);
