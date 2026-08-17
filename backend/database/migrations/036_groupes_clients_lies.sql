-- Groupes de clients liés et identification Centrale des risques.
--
-- L'EP30 détaille les risques portés sur chaque client d'un groupe de clients
-- liés. Il ne demande pas seulement des montants : il exige le numéro
-- Centrale des risques du groupe et de la contrepartie, la nature du lien qui
-- les unit, et le secteur d'activités. Aucun zéro ne remplace ces colonnes,
-- c'est pourquoi l'état restait vide plutôt que déclaré.
--
-- L'application agrégeait jusqu'ici par contrepartie, chacune formant de fait
-- son propre groupe : la division des risques (EP29, EP31, EP32) sous-estime
-- donc les concentrations tant qu'aucun groupe n'est constitué.
CREATE TABLE IF NOT EXISTS groupes_clients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nom TEXT NOT NULL UNIQUE,
    -- Identifiant du groupe à la Centrale des risques de la BCEAO.
    numero_centrale_risques TEXT,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

-- Rattachement d'une contrepartie à son groupe, et son identification
-- réglementaire. La catégorie de lien reprend les liens que retient le
-- dispositif : contrôle de droit ou de fait, et dépendance économique.
ALTER TABLE contreparties ADD COLUMN groupe_id INTEGER REFERENCES groupes_clients(id);
ALTER TABLE contreparties ADD COLUMN categorie_lien TEXT;
ALTER TABLE contreparties ADD COLUMN numero_centrale_risques TEXT;
ALTER TABLE contreparties ADD COLUMN secteur_activite TEXT;

CREATE INDEX IF NOT EXISTS idx_contreparties_groupe
    ON contreparties(groupe_id);
