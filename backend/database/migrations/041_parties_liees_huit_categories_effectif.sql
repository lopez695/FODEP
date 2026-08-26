-- La migration 038 voulait porter la contrainte à huit catégories. Elle n'a
-- jamais pu s'appliquer : sa première instruction supprime la colonne
-- `categorie_partie_liee`, or la 037 avait créé l'index
-- `idx_contreparties_partie_liee` qui s'appuie dessus, et SQLite refuse de
-- retirer une colonne qu'un index retient :
--
--     error in index idx_contreparties_partie_liee after drop column:
--     no such column: categorie_partie_liee
--
-- La base est donc restée sur les six catégories de la 037, alors que le
-- modèle applicatif en déclare huit et que l'EP38 comme l'EP39 comptent huit
-- colonnes de bénéficiaires. Conséquence : importer une contrepartie en
-- « Personnel d'exécution » ou « Autre partie liée » faisait échouer l'import
-- sur une violation de contrainte, et ces deux colonnes du formulaire ne
-- pouvaient jamais porter personne.
--
-- L'index est donc retiré d'abord, et les valeurs déjà déclarées sont
-- reprises : la colonne est recréée, pas vidée.

ALTER TABLE contreparties ADD COLUMN categorie_partie_liee_reprise TEXT;

UPDATE contreparties SET categorie_partie_liee_reprise = categorie_partie_liee;

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

UPDATE contreparties SET categorie_partie_liee = categorie_partie_liee_reprise;

ALTER TABLE contreparties DROP COLUMN categorie_partie_liee_reprise;

CREATE INDEX IF NOT EXISTS idx_contreparties_partie_liee
    ON contreparties(categorie_partie_liee);
