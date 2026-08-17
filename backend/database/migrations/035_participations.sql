-- Participations de l'établissement, exigées par les états EP34 et EP35 du
-- FODEP et par trois normes de l'EP01.
--
-- Les cinq catégories reprennent exactement les sections de l'EP34 : le
-- formulaire ventile les participations entre établissements de crédit,
-- entreprises d'assurances, autres entités financières, sociétés immobilières
-- et entités commerciales. Coller à ce découpage évite d'avoir à reclasser à
-- l'export, et de faire diverger la saisie du formulaire.
--
-- Sans cette table, l'EP01 déclarait « CONFORME » les limites RA006 à RA008
-- faute de mesurer le moindre encours de participation.
CREATE TABLE IF NOT EXISTS participations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    denomination TEXT NOT NULL,
    categorie TEXT NOT NULL CHECK(categorie IN (
        'etablissement',
        'assurance',
        'autre_financiere',
        'societe_immobiliere',
        'entite_commerciale'
    )),
    -- Capital social de l'entreprise émettrice, dénominateur de la limite
    -- individuelle de 25 % (EP35, colonne d = b / a).
    capital_entreprise REAL NOT NULL DEFAULT 0 CHECK(capital_entreprise >= 0),
    -- Souscriptions.
    montant_brut REAL NOT NULL DEFAULT 0 CHECK(montant_brut >= 0),
    -- Montants libérés, nets des provisions : c'est ce montant que les
    -- limites en fonds propres rapportent au T1 et aux fonds propres effectifs.
    montant_net REAL NOT NULL DEFAULT 0 CHECK(montant_net >= 0),
    commentaire TEXT,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_participations_categorie
    ON participations(categorie, denomination);
