-- Rattachement des derives aux contreparties du portefeuille.
--
-- La premiere version du registre laissait le nom de la contrepartie libre, et
-- faisait choisir sa categorie a la main. Deux saisies pour une information que
-- l'application tient deja : la table `contreparties` porte, pour chaque
-- tiers, son identifiant, son nom, sa categorie prudentielle et sa notation.
--
-- Laisser le nom libre avait deux defauts. La meme banque pouvait apparaitre
-- sous trois graphies, et rien ne reliait le derive au reste des engagements
-- sur ce tiers. Et la categorie choisie a la main pouvait contredire celle que
-- le moteur de calcul applique a la meme contrepartie sur ses prets.
--
-- Le contrat designe desormais une contrepartie existante. Les colonnes
-- `contrepartie` et `categorie_contrepartie` restent : elles recopient, au
-- moment de l'enregistrement, le nom et la colonne EP11 de la fiche. Si la
-- fiche disparait, le contrat reste lisible ; tant qu'elle existe, c'est elle
-- qui fait foi a la lecture.

ALTER TABLE derives ADD COLUMN contrepartie_id TEXT REFERENCES contreparties(id);

CREATE INDEX IF NOT EXISTS idx_derives_contrepartie
    ON derives (contrepartie_id);
