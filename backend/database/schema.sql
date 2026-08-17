CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS metadonnees_app (
    cle TEXT PRIMARY KEY,
    valeur TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS historique_imports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_source TEXT NOT NULL,
    nom_source TEXT,
    importe_le TEXT NOT NULL,
    total_lignes INTEGER NOT NULL DEFAULT 0,
    lignes_importees INTEGER NOT NULL DEFAULT 0,
    lignes_rejetees INTEGER NOT NULL DEFAULT 0,
    statut TEXT NOT NULL,
    details_json TEXT
);

CREATE TABLE IF NOT EXISTS journal_operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_entite TEXT NOT NULL,
    entite_id TEXT,
    operation TEXT NOT NULL,
    payload_json TEXT,
    cree_le TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS contreparties (
    id TEXT PRIMARY KEY,
    nom TEXT NOT NULL,
    pays TEXT NOT NULL,
    notation_pays TEXT NOT NULL DEFAULT 'Non noté',
    categorie_standard TEXT NOT NULL,
    categorie_prudentielle TEXT NOT NULL,
    notation TEXT NOT NULL,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS expositions (
    id TEXT PRIMARY KEY,
    contrepartie_id TEXT NOT NULL,
    type_prudentiel TEXT NOT NULL DEFAULT 'e',
    date_analyse TEXT NOT NULL,
    date_octroi TEXT,
    date_echeance TEXT,
    montant_brut REAL NOT NULL CHECK(montant_brut >= 0),
    devise TEXT NOT NULL DEFAULT 'XOF',
    statut TEXT NOT NULL DEFAULT 'Active',
    crm_existe INTEGER NOT NULL DEFAULT 0,
    crm_type TEXT NOT NULL DEFAULT 'Aucune',
    crm_mode TEXT NOT NULL DEFAULT 'Aucune',
    crm_libelle TEXT NOT NULL DEFAULT 'Aucune',
    crm_couverture_pct REAL NOT NULL DEFAULT 0 CHECK(crm_couverture_pct >= 0 AND crm_couverture_pct <= 1),
    ponderation_initiale REAL NOT NULL DEFAULT 0 CHECK(ponderation_initiale >= 0),
    ponderation_finale REAL NOT NULL DEFAULT 0 CHECK(ponderation_finale >= 0),
    ead REAL NOT NULL DEFAULT 0 CHECK(ead >= 0),
    rwa REAL NOT NULL DEFAULT 0 CHECK(rwa >= 0),
    capital REAL NOT NULL DEFAULT 0 CHECK(capital >= 0),
    jours_impayes INTEGER NOT NULL DEFAULT 0 CHECK(jours_impayes >= 0),
    statut_prudentiel TEXT NOT NULL DEFAULT 'saine',
    declassement_manuel INTEGER NOT NULL DEFAULT 0,
    declassement_motif TEXT,
    declassement_le TEXT,
    commentaire TEXT,
    champs_source_json TEXT NOT NULL DEFAULT '{}',
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL,
    FOREIGN KEY(contrepartie_id) REFERENCES contreparties(id) ON DELETE CASCADE
);

-- Suivi mensuel des versements (une ligne par exposition et par mois)
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

-- Sous-entités MERISE par type prudentiel (relation 1:0-1 avec expositions)

CREATE TABLE IF NOT EXISTS exposition_souveraine (
    exposition_id TEXT PRIMARY KEY,
    cas_particulier TEXT NOT NULL DEFAULT '',
    ponderation_zero_preferentiel INTEGER NOT NULL DEFAULT 0,
    oce_etabli INTEGER NOT NULL DEFAULT 0,
    oce_note TEXT NOT NULL DEFAULT '',
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_organisme_public (
    exposition_id TEXT PRIMARY KEY,
    cas_uemoa_fcfa INTEGER,
    activite_non_publique INTEGER,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_bmd (
    exposition_id TEXT PRIMARY KEY,
    cas_haute_qualite INTEGER,
    cas_uemoa_fcfa INTEGER,
    criteres_uemoa_satisfaits INTEGER,
    cas_institution_listee_fcfa INTEGER,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_banque (
    exposition_id TEXT PRIMARY KEY,
    cas_institution TEXT,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_clientele_detail (
    exposition_id TEXT PRIMARY KEY,
    criteres_eligibilite_satisfaits INTEGER,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_immo_residentiel (
    exposition_id TEXT PRIMARY KEY,
    eligible INTEGER,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_immo_commercial (
    exposition_id TEXT PRIMARY KEY,
    eligible INTEGER,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_souffrance (
    exposition_id TEXT PRIMARY KEY,
    ponderation_initiale REAL CHECK(ponderation_initiale IS NULL OR ponderation_initiale >= 0),
    immo_residentiel_en_defaut INTEGER,
    provision_au_moins_vingt_pct INTEGER,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_entreprise (
    exposition_id TEXT PRIMARY KEY,
    depasse_seuil_degradation_bceao INTEGER,
    procedure_prudentielle INTEGER,
    sfi_hors_loi_bancaire INTEGER,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_autre_actif (
    exposition_id TEXT PRIMARY KEY,
    type_actif TEXT,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_hors_bilan_detail (
    exposition_id TEXT PRIMARY KEY,
    niveau_risque TEXT,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exposition_risque_eleve (
    exposition_id TEXT PRIMARY KEY,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS crm_financee (
    exposition_id TEXT PRIMARY KEY,
    valeur_collateral REAL NOT NULL DEFAULT 0,
    devise_collateral TEXT NOT NULL DEFAULT 'XOF',
    type_collateral TEXT NOT NULL DEFAULT 'Liquidités dans la même devise',
    type_emetteur TEXT NOT NULL DEFAULT '',
    notation_emetteur TEXT NOT NULL DEFAULT '',
    tranche_maturite TEXT NOT NULL DEFAULT '<=1 an',
    convertible_indice_principal INTEGER NOT NULL DEFAULT 1,
    opcvm_decote_max REAL NOT NULL DEFAULT 0.30,
    elements_panier_json TEXT NOT NULL DEFAULT '[]',
    decote_change REAL NOT NULL DEFAULT 0,
    decote REAL NOT NULL DEFAULT 0,
    devise_exposition TEXT NOT NULL DEFAULT 'XOF',
    ponderation REAL NOT NULL DEFAULT 0,
    collateral_eligible INTEGER NOT NULL DEFAULT 1,
    motif_ineligibilite TEXT NOT NULL DEFAULT '',
    he REAL NOT NULL DEFAULT 0,
    hc REAL NOT NULL DEFAULT 0,
    hfx REAL NOT NULL DEFAULT 0,
    eva REAL NOT NULL DEFAULT 0,
    cva REAL NOT NULL DEFAULT 0,
    ead_apres_crm_financee REAL NOT NULL DEFAULT 0,
    rwa_final REAL NOT NULL DEFAULT 0,
    gain_crm REAL NOT NULL DEFAULT 0,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS crm_non_financee (
    exposition_id TEXT PRIMARY KEY,
    nom_garant TEXT NOT NULL DEFAULT '',
    categorie_garant TEXT NOT NULL DEFAULT '',
    notation_garant TEXT NOT NULL DEFAULT '',
    pays_garant TEXT NOT NULL DEFAULT '',
    notation_pays_garant TEXT NOT NULL DEFAULT '',
    ponderation_pays_garant REAL NOT NULL DEFAULT 0,
    ponderation_garant REAL NOT NULL DEFAULT 0,
    taux_couverture REAL NOT NULL DEFAULT 0,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS engagements_hors_bilan (
    id TEXT PRIMARY KEY,
    contrepartie_id TEXT NOT NULL,
    date_analyse TEXT NOT NULL,
    type_engagement TEXT NOT NULL,
    montant_nominal REAL NOT NULL,
    ccf REAL NOT NULL DEFAULT 1,
    ead REAL NOT NULL DEFAULT 0,
    ponderation REAL NOT NULL DEFAULT 0,
    rwa REAL NOT NULL DEFAULT 0,
    capital REAL NOT NULL DEFAULT 0,
    commentaire TEXT,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL,
    FOREIGN KEY(contrepartie_id) REFERENCES contreparties(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS crm_garanties (
    id TEXT PRIMARY KEY,
    exposition_id TEXT NOT NULL,
    nom_garant TEXT NOT NULL,
    categorie_garant TEXT NOT NULL,
    notation_garant TEXT NOT NULL,
    montant_couverture REAL NOT NULL,
    type_garantie TEXT NOT NULL,
    type_scenario TEXT NOT NULL,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL,
    FOREIGN KEY(exposition_id) REFERENCES expositions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS baremes_ponderation (
    id TEXT PRIMARY KEY,
    segment TEXT NOT NULL,
    notation TEXT NOT NULL,
    ponderation REAL NOT NULL,
    approche TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS baremes_ccf (
    id TEXT PRIMARY KEY,
    type_engagement TEXT NOT NULL,
    ccf REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS references_notation (
    id TEXT PRIMARY KEY,
    libelle TEXT NOT NULL,
    description TEXT NOT NULL,
    ordre_tri INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS references_pays_souverains (
    pays TEXT PRIMARY KEY,
    notation_souveraine TEXT NOT NULL,
    ponderation REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS rapports (
    id TEXT PRIMARY KEY,
    cree_le TEXT NOT NULL,
    periode TEXT NOT NULL,
    type_rapport TEXT NOT NULL,
    devise TEXT NOT NULL,
    perimetre_exposition TEXT NOT NULL,
    inclure_graphe_categorie INTEGER NOT NULL DEFAULT 1,
    inclure_graphe_notation INTEGER NOT NULL DEFAULT 1,
    chemin_export_pdf TEXT NOT NULL,
    chemin_export_excel TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS lignes_rapport (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rapport_id TEXT NOT NULL,
    ordre_ligne INTEGER NOT NULL,
    source TEXT NOT NULL,
    element_id TEXT NOT NULL,
    contrepartie TEXT NOT NULL,
    montant REAL NOT NULL,
    ead REAL NOT NULL,
    rwa REAL NOT NULL,
    capital REAL NOT NULL,
    FOREIGN KEY(rapport_id) REFERENCES rapports(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_contreparties_nom ON contreparties(nom);
CREATE INDEX IF NOT EXISTS idx_contreparties_pays ON contreparties(pays);
CREATE INDEX IF NOT EXISTS idx_contreparties_categorie ON contreparties(categorie_standard);
CREATE INDEX IF NOT EXISTS idx_contreparties_prudentielle ON contreparties(categorie_prudentielle);
CREATE INDEX IF NOT EXISTS idx_contreparties_notation ON contreparties(notation);
CREATE INDEX IF NOT EXISTS idx_expositions_date_analyse ON expositions(date_analyse);
CREATE INDEX IF NOT EXISTS idx_expositions_statut ON expositions(statut);
CREATE INDEX IF NOT EXISTS idx_expositions_devise ON expositions(devise);
CREATE INDEX IF NOT EXISTS idx_expositions_crm_mode ON expositions(crm_mode);
CREATE INDEX IF NOT EXISTS idx_expositions_contrepartie ON expositions(contrepartie_id);
CREATE INDEX IF NOT EXISTS idx_expositions_type_prudentiel ON expositions(type_prudentiel);
CREATE INDEX IF NOT EXISTS idx_exp_souveraine ON exposition_souveraine(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_organisme_public ON exposition_organisme_public(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_bmd ON exposition_bmd(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_banque ON exposition_banque(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_clientele_detail ON exposition_clientele_detail(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_immo_residentiel ON exposition_immo_residentiel(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_immo_commercial ON exposition_immo_commercial(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_souffrance ON exposition_souffrance(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_entreprise ON exposition_entreprise(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_autre_actif ON exposition_autre_actif(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_hors_bilan_detail ON exposition_hors_bilan_detail(exposition_id);
CREATE INDEX IF NOT EXISTS idx_exp_risque_eleve ON exposition_risque_eleve(exposition_id);
CREATE INDEX IF NOT EXISTS idx_eng_hb_contrepartie ON engagements_hors_bilan(contrepartie_id);
CREATE INDEX IF NOT EXISTS idx_eng_hb_type ON engagements_hors_bilan(type_engagement);
CREATE INDEX IF NOT EXISTS idx_crm_garanties_exposition ON crm_garanties(exposition_id);
CREATE INDEX IF NOT EXISTS idx_baremes_ponderation_segment ON baremes_ponderation(segment, notation);
CREATE INDEX IF NOT EXISTS idx_baremes_ccf_type ON baremes_ccf(type_engagement);
CREATE INDEX IF NOT EXISTS idx_references_notation_ordre ON references_notation(ordre_tri);
CREATE INDEX IF NOT EXISTS idx_lignes_rapport ON lignes_rapport(rapport_id, ordre_ligne);


-- =======================================================================
-- TABLES AJOUTÉES POUR LE CALCUL RÉEL DES FONDS PROPRES ET RATIOS (BCEAO)
-- =======================================================================

CREATE TABLE IF NOT EXISTS fonds_propres (
    id TEXT PRIMARY KEY,
    date_analyse TEXT NOT NULL,
    capital_ordinaire REAL NOT NULL DEFAULT 0,
    reserves REAL NOT NULL DEFAULT 0,
    resultats_report REAL NOT NULL DEFAULT 0,
    resultat_eligible REAL NOT NULL DEFAULT 0,
    deductions_prud_cet1 REAL NOT NULL DEFAULT 0,
    instruments_at1 REAL NOT NULL DEFAULT 0,
    primes_emission_at1 REAL NOT NULL DEFAULT 0,
    deductions_prud_at1 REAL NOT NULL DEFAULT 0,
    dettes_subordonnees_t2 REAL NOT NULL DEFAULT 0,
    provisions_generales_t2 REAL NOT NULL DEFAULT 0,
    deductions_prud_t2 REAL NOT NULL DEFAULT 0,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS risque_operationnel (
    id TEXT PRIMARY KEY,
    date_analyse TEXT NOT NULL,
    produit_brut_annee_1 REAL NOT NULL DEFAULT 0,
    produit_brut_annee_2 REAL NOT NULL DEFAULT 0,
    produit_brut_annee_3 REAL NOT NULL DEFAULT 0,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS risque_marche (
    id TEXT PRIMARY KEY,
    date_analyse TEXT NOT NULL,
    position_nette_change REAL NOT NULL DEFAULT 0,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_fonds_propres_date ON fonds_propres(date_analyse);
CREATE INDEX IF NOT EXISTS idx_risque_op_date ON risque_operationnel(date_analyse);
CREATE INDEX IF NOT EXISTS idx_risque_marche_date ON risque_marche(date_analyse);

