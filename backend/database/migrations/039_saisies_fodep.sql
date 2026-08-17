-- Saisies manuelles des cellules du FODEP que l'application ne calcule pas.
--
-- Le formulaire exige des états dont aucune donnée de l'application n'est la
-- source : risque de contrepartie, approche standard du risque opérationnel,
-- dispositions transitoires, détail du risque de marché. Ils étaient jusqu'ici
-- déclarés à zéro faute de mieux — or un zéro que personne n'a constaté n'est
-- pas une déclaration, c'est une case vide déguisée.
--
-- Cette table recueille ce que le déclarant y porte, cellule par cellule.
-- L'export les écrit avant son balayage final, de sorte qu'une case saisie
-- n'est jamais recouverte par un zéro automatique.
--
-- La clé est le couple (état, cellule) : c'est l'adresse dans le classeur, la
-- seule qui ne dépende pas de l'ordre des lignes du formulaire.
CREATE TABLE IF NOT EXISTS saisies_fodep (
    etat        TEXT NOT NULL,   -- onglet du classeur, ex. « EP11 »
    cellule     TEXT NOT NULL,   -- coordonnée Excel, ex. « C12 »
    valeur      REAL,            -- NULL efface la saisie
    commentaire TEXT,            -- justification, pour la relecture
    modifie_le  TEXT NOT NULL,
    PRIMARY KEY (etat, cellule)
);
