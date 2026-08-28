-- Le PIEAFP est un CYCLE, pas un instantané.
--
-- Le dispositif (Titre XI, chapitre 2) en décrit les neuf étapes : mise à jour
-- du profil de risque, stress tests, plan de fonds propres, rédaction du
-- rapport, validation par l'organe délibérant, transmission à la Commission
-- Bancaire, dialogue prudentiel. Un écran qui afficherait les ratios du jour
-- sans dire à quel exercice ils se rattachent ni si l'organe délibérant les a
-- validés ne documenterait aucune de ces étapes — or c'est précisément ce que
-- le superviseur examine dans le cadre du PSPER.
--
-- Cette table est l'ancrage : tout ce que les écrans ICAAP produiront ensuite
-- (appétence, capital interne, scénarios, plan de fonds propres) s'y rattache
-- par `exercice`, comme les fonds propres viennent de le faire à la migration
-- 042. Sans elle, chaque écran inventerait sa propre notion d'exercice.

CREATE TABLE IF NOT EXISTS icaap_exercices (
    exercice        INTEGER PRIMARY KEY,

    -- Où en est le cycle. « brouillon » tant que l'établissement travaille,
    -- « valide » une fois l'organe délibérant passé, « transmis » une fois la
    -- Commission Bancaire saisie. Le rapport PIEAFP engage la responsabilité
    -- des organes : la date et l'organe qui valide font partie de la pièce.
    statut          TEXT NOT NULL DEFAULT 'brouillon'
                    CHECK (statut IN ('brouillon', 'valide', 'transmis')),
    date_validation TEXT,
    organe          TEXT NOT NULL DEFAULT '',

    -- Le PIEAFP se met à jour au moins une fois par an, et le dialogue
    -- prudentiel peut en appeler une révision en cours d'exercice.
    version         INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),

    commentaire     TEXT,
    cree_le         TEXT NOT NULL,
    modifie_le      TEXT NOT NULL
);
