-- Comptes applicatifs et sessions de renouvellement.
--
-- Deux roles seulement : « consultation » (lecture) et « edition » (acces
-- complet). Le mot de passe n'est jamais stocke, seulement son empreinte
-- bcrypt. Les jetons de renouvellement sont eux aussi conserves sous forme
-- d'empreinte : une fuite de la base ne permet pas de rejouer une session.
CREATE TABLE IF NOT EXISTS utilisateurs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    identifiant TEXT NOT NULL UNIQUE,
    mot_de_passe_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('consultation', 'edition')),
    nom_complet TEXT,
    actif INTEGER NOT NULL DEFAULT 1 CHECK(actif IN (0, 1)),
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL,
    derniere_connexion TEXT
);

CREATE INDEX IF NOT EXISTS idx_utilisateurs_identifiant
    ON utilisateurs(identifiant);

-- Une ligne par session ouverte. La revocation (deconnexion, rotation du
-- jeton) est explicite : sans cette table, un jeton de renouvellement vole
-- resterait valable jusqu'a son expiration sans aucun moyen de l'annuler.
CREATE TABLE IF NOT EXISTS sessions_utilisateur (
    id TEXT PRIMARY KEY,
    utilisateur_id INTEGER NOT NULL,
    jeton_hash TEXT NOT NULL,
    cree_le TEXT NOT NULL,
    expire_le TEXT NOT NULL,
    revoque_le TEXT,
    FOREIGN KEY(utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_utilisateur_compte
    ON sessions_utilisateur(utilisateur_id, expire_le);
