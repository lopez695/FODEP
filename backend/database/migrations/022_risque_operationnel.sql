-- Migration 022 : Tables du module Risque Opérationnel

CREATE TABLE IF NOT EXISTS ro_incidents (
    id TEXT PRIMARY KEY,
    reference TEXT NOT NULL,
    date_occurrence TEXT NOT NULL,
    description TEXT NOT NULL,
    ligne_metier TEXT NOT NULL,
    type_evenement TEXT NOT NULL,
    cause_racine TEXT NOT NULL DEFAULT '',
    perte_brute REAL NOT NULL DEFAULT 0,
    perte_recuperee REAL NOT NULL DEFAULT 0,
    statut TEXT NOT NULL DEFAULT 'Ouvert',
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ro_kri_definitions (
    id TEXT PRIMARY KEY,
    nom TEXT NOT NULL,
    unite TEXT NOT NULL,
    formule TEXT NOT NULL DEFAULT '',
    seuil_alerte REAL NOT NULL,
    seuil_critique REAL NOT NULL,
    sens TEXT NOT NULL DEFAULT 'superieur',
    frequence TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ro_kri_valeurs (
    id TEXT PRIMARY KEY,
    kri_id TEXT NOT NULL REFERENCES ro_kri_definitions(id),
    date_mesure TEXT NOT NULL,
    valeur REAL NOT NULL,
    commentaire TEXT NOT NULL DEFAULT '',
    cree_le TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ro_risques (
    id TEXT PRIMARY KEY,
    nom TEXT NOT NULL,
    categorie TEXT NOT NULL,
    ligne_metier TEXT NOT NULL,
    probabilite INTEGER NOT NULL DEFAULT 1,
    impact INTEGER NOT NULL DEFAULT 1,
    controle_existant TEXT NOT NULL DEFAULT '',
    efficacite_controle INTEGER NOT NULL DEFAULT 3,
    plan_action_ref TEXT NOT NULL DEFAULT '',
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ro_controles (
    id TEXT PRIMARY KEY,
    reference TEXT NOT NULL,
    perimetre TEXT NOT NULL,
    type_controle TEXT NOT NULL,
    frequence TEXT NOT NULL,
    date_dernier_test TEXT NOT NULL DEFAULT '',
    resultat TEXT NOT NULL DEFAULT 'En cours',
    points_conformes INTEGER NOT NULL DEFAULT 0,
    points_controles INTEGER NOT NULL DEFAULT 0,
    non_conformites TEXT NOT NULL DEFAULT '',
    validateur TEXT NOT NULL DEFAULT '',
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ro_plans_action (
    id TEXT PRIMARY KEY,
    reference TEXT NOT NULL,
    titre TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    type_action TEXT NOT NULL DEFAULT 'Corrective',
    source TEXT NOT NULL DEFAULT 'Incident',
    source_ref TEXT NOT NULL DEFAULT '',
    responsable TEXT NOT NULL DEFAULT '',
    date_debut TEXT NOT NULL DEFAULT '',
    date_echeance TEXT NOT NULL DEFAULT '',
    priorite TEXT NOT NULL DEFAULT 'Moyenne',
    statut TEXT NOT NULL DEFAULT 'A faire',
    avancement INTEGER NOT NULL DEFAULT 0,
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ro_historique (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date_evenement TEXT NOT NULL,
    utilisateur TEXT NOT NULL DEFAULT 'Système',
    menu TEXT NOT NULL,
    type_action TEXT NOT NULL,
    element TEXT NOT NULL DEFAULT '',
    ancienne_valeur TEXT NOT NULL DEFAULT '',
    nouvelle_valeur TEXT NOT NULL DEFAULT '',
    commentaire TEXT NOT NULL DEFAULT ''
);

INSERT OR IGNORE INTO ro_kri_definitions (id, nom, unite, formule, seuil_alerte, seuil_critique, sens, frequence) VALUES
    ('kri-01', 'Turnover du personnel', '%', '(Départs période / Effectif moyen) × 100', 15, 30, 'superieur', 'Mensuel'),
    ('kri-02', 'Taux d''absentéisme', '%', '(Jours absence / Jours travaillés théoriques) × 100', 8, 16, 'superieur', 'Mensuel'),
    ('kri-03', 'Heures de formation par employé', 'Heures', 'Total heures formation / Effectif total', 20, 10, 'inferieur', 'Trimestriel'),
    ('kri-04', 'Nombre d''incidents IT', 'Nombre', 'Compteur incidents système', 3, 6, 'superieur', 'Mensuel'),
    ('kri-05', 'Délai moyen de résolution', 'Jours', 'MOYENNE(Date_clôture - Date_ouverture)', 10, 20, 'superieur', 'Mensuel'),
    ('kri-06', 'Taux d''erreurs de traitement', '%', '(Transactions erronées / Transactions totales) × 100', 2, 4, 'superieur', 'Mensuel'),
    ('kri-07', 'Taux de satisfaction client', '%', '(Notes ≥ 4 / Total réponses) × 100', 80, 60, 'inferieur', 'Trimestriel'),
    ('kri-08', 'Nombre de contrôles non conformes', 'Nombre', 'NB.SI(Résultat_contrôle = "Non-conforme")', 2, 4, 'superieur', 'Mensuel');
