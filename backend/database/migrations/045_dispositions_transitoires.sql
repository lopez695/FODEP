-- Dispositions transitoires sur les fonds propres (état EP04).
--
-- Bâle III a rendu inadmissibles certains éléments de fonds propres au
-- 1er janvier 2018, et les retire progressivement : un taux, appliqué chaque
-- année au stock de l'époque, dit combien on peut encore en compter. L'EP04
-- porte ce calcul, et quatre de ses lignes retombent dans l'EP03 — FPI07 pour
-- le CET1, FPI25 pour l'AT1, FPI33 et FPI34 pour le T2.
--
-- L'application n'en tenait aucune trace. Trois clés de l'EP03
-- (`fpi07_transitoire`, `fpi25_transitoire`, `fpi33_transitoire`) étaient lues
-- sur la table `fonds_propres`, qui ne les a jamais portées : elles valaient
-- zéro à chaque export. L'EP04 partait donc à zéro lui aussi, ce qui affirme
-- que l'établissement ne détient aucun instrument en retrait progressif.
--
-- Un exercice, un enregistrement : le stock de référence est celui du
-- 1er janvier 2018, mais le montant encore en circulation change chaque année,
-- et le taux de retrait avec lui. Une déclaration reprise deux ans plus tard
-- doit retrouver les chiffres de son millésime, pas ceux d'aujourd'hui.
--
-- Le taux de retrait ne figure pas ici : la BCEAO l'imprime sur le formulaire
-- (ligne DT001, cellule verrouillée), et l'export l'y relit. Le recopier en
-- base en ferait une seconde source, qu'une nouvelle version du formulaire
-- ferait diverger sans que rien ne le signale.

CREATE TABLE IF NOT EXISTS dispositions_transitoires (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    exercice INTEGER NOT NULL,

    -- ─── Bloc A : retrait progressif des éléments de CET1 ────────────────
    -- Le capital social libéré (FPI01) n'est pas ici : il est déjà déclaré
    -- sur l'EP03, et l'export le reporte. Le redemander exposerait à deux
    -- réponses différentes à la même question.

    -- (c) DT002 — part du capital social non admissible au 1er janvier 2018,
    -- primes d'émission comprises.
    part_capital_non_admissible        REAL NOT NULL DEFAULT 0,
    -- (d) DT003 — provisions réglementées non admissibles.
    provisions_reglementees            REAL NOT NULL DEFAULT 0,
    -- (e) DT004 — fonds affectés non admissibles.
    fonds_affectes                     REAL NOT NULL DEFAULT 0,
    -- (h) DT007 — montant réel encore en circulation à la date de déclaration.
    -- C'est lui qui plafonne la reconnaissance avec (g) : FPI07 = min(g, h).
    cet1_en_circulation                REAL NOT NULL DEFAULT 0,

    -- Ce que deviennent ces éléments : reclassés en AT1, reclassés en T2 (avec
    -- son détail en trois lignes, que le formulaire introduit par « dont »), ou
    -- exclus des fonds propres.
    cet1_eligible_at1                  REAL NOT NULL DEFAULT 0,
    cet1_eligible_t2_autres            REAL NOT NULL DEFAULT 0,
    cet1_eligible_t2_provisions        REAL NOT NULL DEFAULT 0,
    cet1_eligible_t2_fonds_affectes    REAL NOT NULL DEFAULT 0,
    cet1_exclu                         REAL NOT NULL DEFAULT 0,

    -- ─── Bloc B : retrait progressif des éléments de T2 ──────────────────
    -- (j) DT010 — dettes subordonnées en circulation au 1er janvier 2018,
    -- après amortissement s'il y a lieu.
    dettes_subordonnees_2018           REAL NOT NULL DEFAULT 0,
    -- (k) DT011 — la part non admissible de ces dettes.
    part_dettes_non_admissible         REAL NOT NULL DEFAULT 0,
    -- (l) DT012 — écarts de réévaluation.
    ecarts_reevaluation                REAL NOT NULL DEFAULT 0,
    -- (m) DT013 — autres éléments de T2 non admissibles.
    autres_t2_non_admissibles          REAL NOT NULL DEFAULT 0,
    -- (p) DT016 — montant réel encore en circulation, après amortissement
    -- jusqu'à la date de déclaration. Plafonne avec (o) : FPI34 = min(o, p).
    t2_en_circulation                  REAL NOT NULL DEFAULT 0,

    commentaire                        TEXT,
    cree_le                            TEXT NOT NULL,
    modifie_le                         TEXT NOT NULL
);

-- Un exercice, un enregistrement : c'est ce qui en fait un historique plutôt
-- qu'une pile de corrections, comme pour les fonds propres.
CREATE UNIQUE INDEX IF NOT EXISTS idx_dispositions_transitoires_exercice
    ON dispositions_transitoires (exercice);
