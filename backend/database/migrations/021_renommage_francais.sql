-- Migration 021 : renommage complet de la base de données en français.
-- Tables et colonnes passent de l'anglais au français.
-- Les repositories utilisent des alias AS dans les SELECT pour
-- préserver les noms Python/API (aucune modification du code applicatif
-- côté clés de dictionnaires).

-- ── 1. Renommage des tables ──────────────────────────────────────────────────

ALTER TABLE app_metadata              RENAME TO metadonnees_app;
ALTER TABLE counterparties            RENAME TO contreparties;
ALTER TABLE exposures                 RENAME TO expositions;
ALTER TABLE exposure_sovereign        RENAME TO exposition_souveraine;
ALTER TABLE exposure_public_body      RENAME TO exposition_organisme_public;
ALTER TABLE exposure_bmd              RENAME TO exposition_bmd;
ALTER TABLE exposure_bank             RENAME TO exposition_banque;
ALTER TABLE exposure_enterprise       RENAME TO exposition_entreprise;
ALTER TABLE exposure_retail           RENAME TO exposition_clientele_detail;
ALTER TABLE exposure_residential_mortgage    RENAME TO exposition_immo_residentiel;
ALTER TABLE exposure_commercial_real_estate  RENAME TO exposition_immo_commercial;
ALTER TABLE exposure_defaulted        RENAME TO exposition_souffrance;
ALTER TABLE exposure_high_risk        RENAME TO exposition_risque_eleve;
ALTER TABLE exposure_other_asset      RENAME TO exposition_autre_actif;
ALTER TABLE exposure_off_balance_detail     RENAME TO exposition_hors_bilan_detail;
ALTER TABLE crm_financed              RENAME TO crm_financee;
ALTER TABLE crm_non_financed          RENAME TO crm_non_financee;
ALTER TABLE crm_guarantees            RENAME TO crm_garanties;
ALTER TABLE off_balance_commitments   RENAME TO engagements_hors_bilan;
ALTER TABLE risk_weight_references    RENAME TO baremes_ponderation;
ALTER TABLE ccf_references            RENAME TO baremes_ccf;
ALTER TABLE rating_references         RENAME TO references_notation;
ALTER TABLE sovereign_country_references    RENAME TO references_pays_souverains;
ALTER TABLE reports                   RENAME TO rapports;
ALTER TABLE report_lines              RENAME TO lignes_rapport;
ALTER TABLE import_runs               RENAME TO historique_imports;
ALTER TABLE operation_history         RENAME TO journal_operations;

-- ── 2. Renommage des colonnes : contreparties ────────────────────────────────

ALTER TABLE contreparties RENAME COLUMN name             TO nom;
ALTER TABLE contreparties RENAME COLUMN country          TO pays;
ALTER TABLE contreparties RENAME COLUMN country_rating   TO notation_pays;
ALTER TABLE contreparties RENAME COLUMN category_standard    TO categorie_standard;
ALTER TABLE contreparties RENAME COLUMN category_prudential  TO categorie_prudentielle;
ALTER TABLE contreparties RENAME COLUMN rating           TO notation;
ALTER TABLE contreparties RENAME COLUMN created_at       TO cree_le;
ALTER TABLE contreparties RENAME COLUMN updated_at       TO modifie_le;

-- ── 3. Renommage des colonnes : expositions ──────────────────────────────────

ALTER TABLE expositions RENAME COLUMN counterparty_id       TO contrepartie_id;
ALTER TABLE expositions RENAME COLUMN prudential_type        TO type_prudentiel;
ALTER TABLE expositions RENAME COLUMN analysis_date          TO date_analyse;
ALTER TABLE expositions RENAME COLUMN grant_date             TO date_octroi;
ALTER TABLE expositions RENAME COLUMN maturity_date          TO date_echeance;
ALTER TABLE expositions RENAME COLUMN gross_amount           TO montant_brut;
ALTER TABLE expositions RENAME COLUMN currency               TO devise;
ALTER TABLE expositions RENAME COLUMN status                 TO statut;
ALTER TABLE expositions RENAME COLUMN crm_exists             TO crm_existe;
ALTER TABLE expositions RENAME COLUMN crm_label              TO crm_libelle;
ALTER TABLE expositions RENAME COLUMN crm_coverage_percent   TO crm_couverture_pct;
ALTER TABLE expositions RENAME COLUMN original_rw            TO ponderation_initiale;
ALTER TABLE expositions RENAME COLUMN final_rw               TO ponderation_finale;
ALTER TABLE expositions RENAME COLUMN comment                TO commentaire;
ALTER TABLE expositions RENAME COLUMN source_fields_json     TO champs_source_json;
ALTER TABLE expositions RENAME COLUMN created_at             TO cree_le;
ALTER TABLE expositions RENAME COLUMN updated_at             TO modifie_le;

-- ── 4. Renommage des colonnes : sous-tables de type ─────────────────────────

ALTER TABLE exposition_souveraine RENAME COLUMN exposure_id              TO exposition_id;
ALTER TABLE exposition_souveraine RENAME COLUMN special_case             TO cas_particulier;
ALTER TABLE exposition_souveraine RENAME COLUMN preferential_zero_weight TO ponderation_zero_preferentiel;
ALTER TABLE exposition_souveraine RENAME COLUMN oce_established          TO oce_etabli;

ALTER TABLE exposition_organisme_public RENAME COLUMN exposure_id           TO exposition_id;
ALTER TABLE exposition_organisme_public RENAME COLUMN uemoa_fcfa_case       TO cas_uemoa_fcfa;
ALTER TABLE exposition_organisme_public RENAME COLUMN non_public_activity   TO activite_non_publique;

ALTER TABLE exposition_bmd RENAME COLUMN exposure_id                  TO exposition_id;
ALTER TABLE exposition_bmd RENAME COLUMN high_quality_case            TO cas_haute_qualite;
ALTER TABLE exposition_bmd RENAME COLUMN uemoa_fcfa_case              TO cas_uemoa_fcfa;
ALTER TABLE exposition_bmd RENAME COLUMN uemoa_criteria_satisfied     TO criteres_uemoa_satisfaits;
ALTER TABLE exposition_bmd RENAME COLUMN listed_institution_fcfa_case TO cas_institution_listee_fcfa;

ALTER TABLE exposition_banque RENAME COLUMN exposure_id      TO exposition_id;
ALTER TABLE exposition_banque RENAME COLUMN institution_case TO cas_institution;

ALTER TABLE exposition_entreprise RENAME COLUMN exposure_id                          TO exposition_id;
ALTER TABLE exposition_entreprise RENAME COLUMN exceeds_bceao_degradation_threshold TO depasse_seuil_degradation_bceao;
ALTER TABLE exposition_entreprise RENAME COLUMN prudential_procedure                 TO procedure_prudentielle;
ALTER TABLE exposition_entreprise RENAME COLUMN investment_firm_without_banking_law  TO sfi_hors_loi_bancaire;

ALTER TABLE exposition_clientele_detail RENAME COLUMN exposure_id                    TO exposition_id;
ALTER TABLE exposition_clientele_detail RENAME COLUMN eligibility_criteria_satisfied TO criteres_eligibilite_satisfaits;

ALTER TABLE exposition_immo_residentiel RENAME COLUMN exposure_id TO exposition_id;

ALTER TABLE exposition_immo_commercial RENAME COLUMN exposure_id TO exposition_id;

ALTER TABLE exposition_souffrance RENAME COLUMN exposure_id                          TO exposition_id;
ALTER TABLE exposition_souffrance RENAME COLUMN initial_risk_weight                  TO ponderation_initiale;
ALTER TABLE exposition_souffrance RENAME COLUMN residential_mortgage_in_default      TO immo_residentiel_en_defaut;
ALTER TABLE exposition_souffrance RENAME COLUMN provision_at_least_twenty_percent    TO provision_au_moins_vingt_pct;

ALTER TABLE exposition_autre_actif RENAME COLUMN exposure_id  TO exposition_id;
ALTER TABLE exposition_autre_actif RENAME COLUMN asset_type   TO type_actif;

ALTER TABLE exposition_hors_bilan_detail RENAME COLUMN exposure_id  TO exposition_id;
ALTER TABLE exposition_hors_bilan_detail RENAME COLUMN risk_level   TO niveau_risque;

ALTER TABLE exposition_risque_eleve RENAME COLUMN exposure_id TO exposition_id;

-- ── 5. Renommage des colonnes : CRM ─────────────────────────────────────────

ALTER TABLE crm_financee RENAME COLUMN exposure_id            TO exposition_id;
ALTER TABLE crm_financee RENAME COLUMN collateral_value       TO valeur_collateral;
ALTER TABLE crm_financee RENAME COLUMN collateral_currency    TO devise_collateral;
ALTER TABLE crm_financee RENAME COLUMN collateral_type        TO type_collateral;
ALTER TABLE crm_financee RENAME COLUMN issuer_type            TO type_emetteur;
ALTER TABLE crm_financee RENAME COLUMN issuer_rating          TO notation_emetteur;
ALTER TABLE crm_financee RENAME COLUMN maturity_bucket        TO tranche_maturite;
ALTER TABLE crm_financee RENAME COLUMN convertible_main_index TO convertible_indice_principal;
ALTER TABLE crm_financee RENAME COLUMN opcvm_highest_haircut  TO opcvm_decote_max;
ALTER TABLE crm_financee RENAME COLUMN basket_items_json      TO elements_panier_json;
ALTER TABLE crm_financee RENAME COLUMN fx_haircut             TO decote_change;
ALTER TABLE crm_financee RENAME COLUMN haircut                TO decote;
ALTER TABLE crm_financee RENAME COLUMN exposure_currency      TO devise_exposition;
ALTER TABLE crm_financee RENAME COLUMN risk_weight            TO ponderation;
ALTER TABLE crm_financee RENAME COLUMN ineligibility_reason   TO motif_ineligibilite;
ALTER TABLE crm_financee RENAME COLUMN ead_after_financed_crm TO ead_apres_crm_financee;
ALTER TABLE crm_financee RENAME COLUMN crm_gain               TO gain_crm;

ALTER TABLE crm_non_financee RENAME COLUMN exposure_id              TO exposition_id;
ALTER TABLE crm_non_financee RENAME COLUMN guarantor_name           TO nom_garant;
ALTER TABLE crm_non_financee RENAME COLUMN guarantor_category       TO categorie_garant;
ALTER TABLE crm_non_financee RENAME COLUMN guarantor_rating         TO notation_garant;
ALTER TABLE crm_non_financee RENAME COLUMN guarantor_country        TO pays_garant;
ALTER TABLE crm_non_financee RENAME COLUMN guarantor_country_rating TO notation_pays_garant;
ALTER TABLE crm_non_financee RENAME COLUMN guarantor_country_rw     TO ponderation_pays_garant;
ALTER TABLE crm_non_financee RENAME COLUMN guarantor_rw             TO ponderation_garant;
ALTER TABLE crm_non_financee RENAME COLUMN coverage_percent         TO taux_couverture;

ALTER TABLE crm_garanties RENAME COLUMN exposure_id      TO exposition_id;
ALTER TABLE crm_garanties RENAME COLUMN guarantor_name   TO nom_garant;
ALTER TABLE crm_garanties RENAME COLUMN guarantor_category TO categorie_garant;
ALTER TABLE crm_garanties RENAME COLUMN guarantor_rating TO notation_garant;
ALTER TABLE crm_garanties RENAME COLUMN coverage_amount  TO montant_couverture;
ALTER TABLE crm_garanties RENAME COLUMN guarantee_type   TO type_garantie;
ALTER TABLE crm_garanties RENAME COLUMN scenario_type    TO type_scenario;
ALTER TABLE crm_garanties RENAME COLUMN created_at       TO cree_le;
ALTER TABLE crm_garanties RENAME COLUMN updated_at       TO modifie_le;

-- ── 6. Renommage des colonnes : engagements hors bilan ───────────────────────

ALTER TABLE engagements_hors_bilan RENAME COLUMN counterparty_id  TO contrepartie_id;
ALTER TABLE engagements_hors_bilan RENAME COLUMN analysis_date    TO date_analyse;
ALTER TABLE engagements_hors_bilan RENAME COLUMN engagement_type  TO type_engagement;
ALTER TABLE engagements_hors_bilan RENAME COLUMN nominal_amount   TO montant_nominal;
ALTER TABLE engagements_hors_bilan RENAME COLUMN risk_weight      TO ponderation;
ALTER TABLE engagements_hors_bilan RENAME COLUMN comment          TO commentaire;
ALTER TABLE engagements_hors_bilan RENAME COLUMN created_at       TO cree_le;
ALTER TABLE engagements_hors_bilan RENAME COLUMN updated_at       TO modifie_le;

-- ── 7. Renommage des colonnes : référentiels ─────────────────────────────────

ALTER TABLE baremes_ponderation RENAME COLUMN rating      TO notation;
ALTER TABLE baremes_ponderation RENAME COLUMN risk_weight TO ponderation;
ALTER TABLE baremes_ponderation RENAME COLUMN approach    TO approche;

ALTER TABLE baremes_ccf RENAME COLUMN engagement_type TO type_engagement;

ALTER TABLE references_notation RENAME COLUMN label      TO libelle;
ALTER TABLE references_notation RENAME COLUMN sort_order TO ordre_tri;

ALTER TABLE references_pays_souverains RENAME COLUMN country          TO pays;
ALTER TABLE references_pays_souverains RENAME COLUMN sovereign_rating TO notation_souveraine;
ALTER TABLE references_pays_souverains RENAME COLUMN risk_weight      TO ponderation;

-- ── 8. Renommage des colonnes : rapports ─────────────────────────────────────

ALTER TABLE rapports RENAME COLUMN created_at              TO cree_le;
ALTER TABLE rapports RENAME COLUMN period                  TO periode;
ALTER TABLE rapports RENAME COLUMN report_type             TO type_rapport;
ALTER TABLE rapports RENAME COLUMN currency                TO devise;
ALTER TABLE rapports RENAME COLUMN exposure_scope          TO perimetre_exposition;
ALTER TABLE rapports RENAME COLUMN include_category_chart  TO inclure_graphe_categorie;
ALTER TABLE rapports RENAME COLUMN include_rating_chart    TO inclure_graphe_notation;
ALTER TABLE rapports RENAME COLUMN export_pdf_path         TO chemin_export_pdf;
ALTER TABLE rapports RENAME COLUMN export_excel_path       TO chemin_export_excel;

ALTER TABLE lignes_rapport RENAME COLUMN report_id    TO rapport_id;
ALTER TABLE lignes_rapport RENAME COLUMN line_order   TO ordre_ligne;
ALTER TABLE lignes_rapport RENAME COLUMN item_id      TO element_id;
ALTER TABLE lignes_rapport RENAME COLUMN counterparty TO contrepartie;
ALTER TABLE lignes_rapport RENAME COLUMN amount       TO montant;

-- ── 9. Renommage des colonnes : historique et journal ────────────────────────

ALTER TABLE historique_imports RENAME COLUMN source_type      TO type_source;
ALTER TABLE historique_imports RENAME COLUMN source_name      TO nom_source;
ALTER TABLE historique_imports RENAME COLUMN imported_at      TO importe_le;
ALTER TABLE historique_imports RENAME COLUMN total_rows       TO total_lignes;
ALTER TABLE historique_imports RENAME COLUMN imported_rows    TO lignes_importees;
ALTER TABLE historique_imports RENAME COLUMN rejected_rows    TO lignes_rejetees;
ALTER TABLE historique_imports RENAME COLUMN status           TO statut;

ALTER TABLE journal_operations RENAME COLUMN entity_type  TO type_entite;
ALTER TABLE journal_operations RENAME COLUMN entity_id    TO entite_id;
ALTER TABLE journal_operations RENAME COLUMN created_at   TO cree_le;

ALTER TABLE metadonnees_app RENAME COLUMN key   TO cle;
ALTER TABLE metadonnees_app RENAME COLUMN value TO valeur;

-- ── 10. Recréation des index avec les nouveaux noms ──────────────────────────
-- (Les index existants sont supprimés automatiquement lors du RENAME TABLE
--  en SQLite >= 3.26.0 et recréés ici avec les noms cohérents.)

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
