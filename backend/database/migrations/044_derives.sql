-- Registre des instruments dérivés.
--
-- L'état EP11 du FODEP déclare le risque de contrepartie porté par les
-- dérivés : swaps de taux, change à terme, contrats sur titres de propriété ou
-- sur produits de base. L'application n'en tenait aucune trace. L'état était
-- donc offert à la saisie manuelle, cellule par cellule, puis cette saisie a
-- été retirée de l'écran : l'EP11 partait à zéro sans que personne puisse le
-- corriger, et le formulaire affirmait ainsi que l'établissement ne détient
-- aucun dérivé.
--
-- Le registre remplace la saisie de cellules par la saisie de contrats. Un
-- contrat porte ce que l'EP11 réclame et rien de plus : sa nature, sa
-- contrepartie, son notionnel, son coût de remplacement et son échéance.
-- L'agrégation en quinze lignes, la pondération et les colonnes calculées
-- restent l'affaire de l'export.
--
-- Un registre vide déclare toujours zéro -- mais c'est alors un zéro constaté,
-- et non un zéro faute de mieux.

CREATE TABLE IF NOT EXISTS derives (
    id                     INTEGER PRIMARY KEY AUTOINCREMENT,

    -- La contrepartie du contrat. Le nom est libre : un dérivé se traite
    -- souvent avec une banque qui ne figure pas au portefeuille de crédit, et
    -- exiger une contrepartie déjà enregistrée empêcherait de déclarer le
    -- contrat le plus courant.
    contrepartie           TEXT    NOT NULL,

    -- Catégorie prudentielle de la contrepartie, dans la nomenclature du
    -- FODEP : « a » souverains, « b » organismes publics hors administration
    -- centrale, « c » banques multilatérales de développement, « d »
    -- institutions financières, « e » entreprises. Ce sont exactement les cinq
    -- colonnes de ventilation de l'EP11, d'où le choix de la stocker plutôt
    -- que de la deviner à l'export.
    categorie_contrepartie TEXT    NOT NULL DEFAULT 'd',

    -- Nature du sous-jacent. Les cinq valeurs sont les cinq blocs de l'EP11,
    -- chacun avec ses trois pondérations de durée. Elles ne sont pas un choix
    -- de conception : le formulaire ventile ainsi, et s'en écarter obligerait
    -- à reclasser à l'export.
    nature                 TEXT    NOT NULL,

    -- Swap, change à terme, option... Informatif : le formulaire ne demande
    -- pas le type de contrat, mais celui qui relit le registre en a besoin
    -- pour reconnaître la ligne qu'il a saisie.
    type_contrat           TEXT,

    devise                 TEXT    NOT NULL DEFAULT 'XOF',

    -- Le notionnel porte la colonne (b) de l'EP11, le coût de remplacement la
    -- colonne (a). Ce dernier est la valeur de marché du contrat lorsqu'elle
    -- est en faveur de l'établissement ; une valeur négative ne se déclare pas,
    -- d'où le plancher à zéro pose par la couche applicative.
    montant_notionnel      REAL    NOT NULL DEFAULT 0,
    cout_remplacement      REAL    NOT NULL DEFAULT 0,

    date_conclusion        TEXT,

    -- L'échéance, et non une tranche de durée figée. Les trois lignes de
    -- chaque bloc de l'EP11 se lisent en durée RESIDUELLE : un contrat à
    -- sept ans conclu il y a trois ans se déclare aujourd'hui sur la ligne
    -- « > 1 an jusqu'à 5 ans ». Stocker la tranche l'aurait gelée au jour de
    -- la saisie, et la déclaration aurait vieilli sans qu'on le voie.
    date_echeance          TEXT    NOT NULL,

    commentaire            TEXT,
    cree_le                TEXT    NOT NULL,
    modifie_le             TEXT    NOT NULL
);

-- L'export parcourt le registre par nature puis par échéance : c'est l'ordre
-- dans lequel l'EP11 range ses quinze lignes.
CREATE INDEX IF NOT EXISTS idx_derives_nature_echeance
    ON derives (nature, date_echeance);
