-- Migration 024 : S'assurer que les 8 définitions KRI sont présentes
-- INSERT OR IGNORE : sans effet si la ligne existe déjà

INSERT OR IGNORE INTO ro_kri_definitions (id, nom, unite, formule, seuil_alerte, seuil_critique, sens, frequence) VALUES
    ('kri-01', 'Turnover du personnel',          '%',      '(Départs période / Effectif moyen) × 100',                  15,  30,  'superieur',  'Mensuel'),
    ('kri-02', 'Taux d''absentéisme',             '%',      '(Jours absence / Jours travaillés théoriques) × 100',       8,   16,  'superieur',  'Mensuel'),
    ('kri-03', 'Heures de formation par employé', 'Heures', 'Total heures formation / Effectif total',                   20,  10,  'inferieur',  'Trimestriel'),
    ('kri-04', 'Nombre d''incidents IT',          'Nombre', 'Compteur incidents système',                                3,   6,   'superieur',  'Mensuel'),
    ('kri-05', 'Délai moyen de résolution',       'Jours',  'MOYENNE(Date_clôture - Date_ouverture)',                    10,  20,  'superieur',  'Mensuel'),
    ('kri-06', 'Taux d''erreurs de traitement',   '%',      '(Transactions erronées / Transactions totales) × 100',     2,   4,   'superieur',  'Mensuel'),
    ('kri-07', 'Taux de satisfaction client',     '%',      '(Notes >= 4 / Total réponses) × 100',                      80,  60,  'inferieur',  'Trimestriel'),
    ('kri-08', 'Nombre de contrôles non conformes','Nombre','NB.SI(Résultat_contrôle = Non-conforme)',                   2,   4,   'superieur',  'Mensuel');
