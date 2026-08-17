-- Suivi mensuel des versements et cycle de vie prudentiel des expositions.
-- Une ligne par exposition et par mois ('AAAA-MM') ; une correction met à jour
-- la ligne existante et laisse une trace dans journal_operations : rien ne
-- disparaît silencieusement.
CREATE TABLE IF NOT EXISTS suivi_versements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    exposition_id TEXT NOT NULL,
    periode TEXT NOT NULL CHECK(length(periode) = 7),
    statut TEXT NOT NULL CHECK(statut IN ('verse', 'impaye')),
    montant_verse REAL CHECK(montant_verse IS NULL OR montant_verse >= 0),
    commentaire TEXT,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL,
    UNIQUE(exposition_id, periode),
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_suivi_versements_exposition
    ON suivi_versements(exposition_id, periode);

-- Statut prudentiel matérialisé : saine | impayee | douteuse.
-- Le déclassement manuel (anticipé) est conservé à part : il ne peut être levé
-- que par l'action dédiée, jamais par une simple réédition du formulaire.
ALTER TABLE expositions ADD COLUMN statut_prudentiel TEXT NOT NULL DEFAULT 'saine';
ALTER TABLE expositions ADD COLUMN declassement_manuel INTEGER NOT NULL DEFAULT 0;
ALTER TABLE expositions ADD COLUMN declassement_motif TEXT;
ALTER TABLE expositions ADD COLUMN declassement_le TEXT;
