-- Migration 023 : Index pour le module Risque Opérationnel
CREATE INDEX IF NOT EXISTS idx_ro_incidents_statut ON ro_incidents(statut);
CREATE INDEX IF NOT EXISTS idx_ro_incidents_ligne_metier ON ro_incidents(ligne_metier);
CREATE INDEX IF NOT EXISTS idx_ro_incidents_date ON ro_incidents(date_occurrence DESC);
CREATE INDEX IF NOT EXISTS idx_ro_incidents_reference ON ro_incidents(reference);
CREATE INDEX IF NOT EXISTS idx_ro_kri_valeurs_kri_id ON ro_kri_valeurs(kri_id);
CREATE INDEX IF NOT EXISTS idx_ro_kri_valeurs_date ON ro_kri_valeurs(date_mesure DESC);
CREATE INDEX IF NOT EXISTS idx_ro_risques_categorie ON ro_risques(categorie);
CREATE INDEX IF NOT EXISTS idx_ro_risques_ligne_metier ON ro_risques(ligne_metier);
CREATE INDEX IF NOT EXISTS idx_ro_controles_type ON ro_controles(type_controle);
CREATE INDEX IF NOT EXISTS idx_ro_plans_action_statut ON ro_plans_action(statut);
CREATE INDEX IF NOT EXISTS idx_ro_plans_action_priorite ON ro_plans_action(priorite);
CREATE INDEX IF NOT EXISTS idx_ro_historique_menu ON ro_historique(menu);
CREATE INDEX IF NOT EXISTS idx_ro_historique_date ON ro_historique(date_evenement DESC);
