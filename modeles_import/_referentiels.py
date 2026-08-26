# -*- coding: utf-8 -*-
"""Référentiels partagés par les générateurs de modèles d'import.

Toutes les valeurs listées ici proviennent des listes d'options reconnues par
l'outil (backend/database/services/excel_import_service.py, les dialogues
d'import Flutter) : une valeur choisie ici est donc toujours acceptée à
l'import.
"""

from __future__ import annotations

# ── Banque fictive support des jeux de données ──────────────────────────────
BANQUE = "Banque Continentale de l'Union (BCU)"
DATE_ANALYSE = "2026-06-30"

# ── Crédit : feuille « Template données » ───────────────────────────────────
CATEGORIES = {
    "a": "Souverains",
    "b": "Organismes pub. hors Adm c",
    "c": "Expositions sur les BMD",
    "d": "Institutions financières",
    "e": "Entreprises",
    "f": "Clientèle de détail",
    "g": "Prêts garantis par l'immo R",
    "h": "Prêts garantis par l'immo C",
    "i": "Créances en souffrance",
    "j": "Créances à risque élevé",
    "k": "Autres actifs",
}

NOTATIONS = (
    "AAA", "AA+", "AA", "AA-", "A+", "A", "A-",
    "BBB+", "BBB", "BBB-", "BB+", "BB", "BB-",
    "B+", "B", "B-", "< B-", "Non noté",
)

NOTATIONS_CRM_FINANCEE = (
    "AAA", "AA+", "AA", "AA-", "A+", "A", "A-",
    "BBB+", "BBB", "BBB-", "BB+", "BB", "BB-",
    "< B-", "Non noté",
)

DEVISES = ("XOF", "EUR", "USD")

TYPES_CRM = ("Aucune", "CRM financee", "CRM non financee")

NIVEAUX_RISQUE_HB = (
    "Risque faible", "Risque mineur", "Risque moyen",
    "Risque élevé", "Risque très élevé",
)

STATUTS_GESTION = (
    "Active", "En recouvrement", "Restructurée",
    "Contentieux", "Clôturée",
)

TYPES_AUTRES_ACTIFS = (
    "Encaisse",
    "Valeurs assimilées à l’encaisse, y compris l’or",
    "Valeurs à l’encaissement avec crédit immédiat",
    "Participations non significatives non déduites des fonds propres",
    "Immobilisations corporelles",
    # Ces deux natures ne changent pas la pondération des corporelles, mais
    # elles seules renseignent l'EP36 (limite RA009) et le poste IM011 de
    # l'EP3M. Absentes d'ici, aucun fichier d'exemple ne les contenait, et ces
    # deux états sortaient vides des jeux de démonstration.
    "Immobilisations hors exploitation",
    "Immobilisations incorporelles",
    "Autres actifs divers",
    "Engagements en actions non déduits",
    "Expositions sur entreprises financières non soumises à une réglementation équivalente UMOA",
    "Autres éléments d’actifs non définis",
    "Participations significatives et impôts différés actifs non déduits",
    "Expositions sur établissements non conformes aux ratios de solvabilité",
)

CAS_SOUVERAIN_UEMOA = (
    "Expositions sur États de l’UEMOA et démembrements libellées et financées en FCFA"
)
CAS_SOUVERAIN_BCEAO = "Expositions sur BCEAO libellées et financées en FCFA"
CAS_SOUVERAIN_AUCUN = "Aucun de ces cas"
CAS_SOUVERAIN_ORG = ("UEMOA", "CEDEAO", "UA", "UE", "ONU", "BRI", "FMI", "BCE", "FGD-UMOA")

CAS_ORGANISME_PUBLIC = (
    "Organisme public standard (selon notation)",
    "Organisme public UEMOA libellé en FCFA (préférentiel 20%)",
    "Activité commerciale / non publique (traité comme entreprise)",
)

CAS_BMD = (
    "BMD standard (selon notation)",
    "BMD haute qualité / soutien fort (pondération 0%)",
    "BMD institution listée BCEAO en FCFA (BIRD, BAD, BOAD... 0%)",
    "BMD UEMOA en FCFA conforme aux critères (20%)",
)

CAS_INSTITUTION_BANCAIRE = (
    "equivalent_umoa_rules",
    "weak_prudential_case",
    "eligible_categories_case",
)

CAS_CREANCE_SOUFFRANCE = (
    "Prêt immobilier résidentiel en défaut (Provisions >= 20%) — 50%",
    "Prêt immobilier résidentiel en défaut (Provisions < 20%) — 100%",
    "Autre créance en défaut (Provisions >= 20%) — 100%",
    "Autre créance en défaut (Provisions < 20%) — 150%",
)

REGIMES_PRUDENTIELS = (
    "Standard (aucun traitement particulier)",
    "Souverain UEMOA en FCFA (pondération 0 %)",
    "Organisme public UEMOA en FCFA (pondération 20 %)",
    "Organisme public - Activité commerciale (traité comme entreprise)",
    "BMD liste officielle BCEAO (BIRD, BAD, BOAD... pondération 0 %)",
    "BMD haute qualité / soutien fort (pondération 0 %)",
    "BMD UEMOA en FCFA (pondération 20 %)",
    "Banque - Établissement de crédit agréé UEMOA",
    "Banque - Faible qualité prudentielle",
    "Clientèle de détail - Critères d'éligibilité respectés (pondération 75 %)",
    "Immobilier résidentiel - Prêt éligible avec hypothèque 1er rang (pondération 35 %)",
    "Immobilier commercial - Prêt éligible (pondération 50 %)",
    "Défaut - Prêt immobilier résidentiel (Provisions >= 20%) — pondération 50 %",
    "Défaut - Prêt immobilier résidentiel (Provisions < 20%) — pondération 100 %",
    "Défaut - Autre créance en souffrance (Provisions >= 20%) — pondération 100 %",
    "Défaut - Autre créance en souffrance (Provisions < 20%) — pondération 150 %",
    "Entreprise - Portefeuille dégradé (seuil BCEAO dépassé -> pondération 150 %)",
    "Entreprise - Procédure prudentielle (pondération 150 %)",
    "Entreprise d'investissement non soumise à la loi bancaire (pondération 100 %)",
)

PONDERATIONS_AVANT_DEFAUT = (0.2, 0.35, 0.5, 0.75, 1.0, 1.5, 2.5)

CATEGORIES_GARANT = (
    "Souverains", "Organismes pub. hors Adm c", "Expositions sur les BMD",
    "Institutions financières", "Entreprises", "Clientèle de détail",
    "Autres actifs",
)

TYPES_EMETTEUR_CRM = ("emprunteur souverain", "autre émetteur")

MATURITES_CRM = ("<=1 an", "1-3 ans", "3-5 ans", "5-10 ans", ">10 ans")

TYPES_COLLATERAL = (
    "Liquidités dans la même devise",
    "Liquidités dans une devise différente",
    "Or",
    "Titre de dette souverain",
    "Titre non noté émis par un État de l UMOA",
    "Titre de dette émis par un autre émetteur",
    "Titre garanti par un agent agréé par la BRVM",
    "Titre bancaire non noté",
    "Action de l indice BRVM 10",
    "Action d un indice principal reconnu",
    "Autre action cotée à la BRVM ou sur une bourse reconnue",
    "Obligation convertible en action",
    "OPCVM / FI",
    "Panier d actifs",
    "Autre sûreté non éligible",
)

# ── Pays (libellés exacts du référentiel de l'outil, sans accent) ───────────
PAYS_UEMOA = (
    "Cote d'Ivoire", "Senegal", "Benin", "Burkina Faso",
    "Mali", "Niger", "Togo", "Guinee-Bissau",
)
PAYS_HORS_UEMOA = (
    "France", "Maroc", "Nigeria", "Ghana", "Cameroun", "Etats-Unis",
    "Tunisie", "Afrique du Sud", "Chine", "Emirats arabes unis",
)

# Notation externe retenue pour chaque pays (fictive mais plausible).
NOTATION_PAYS = {
    "Cote d'Ivoire": "BB",
    "Senegal": "B+",
    "Benin": "BB-",
    "Burkina Faso": "Non noté",
    "Mali": "Non noté",
    "Niger": "Non noté",
    "Togo": "B",
    "Guinee-Bissau": "Non noté",
    "France": "AA-",
    "Maroc": "BBB-",
    "Nigeria": "B-",
    "Ghana": "< B-",
    "Cameroun": "B-",
    "Etats-Unis": "AA+",
    "Tunisie": "< B-",
    "Afrique du Sud": "BB-",
    "Chine": "A+",
    "Emirats arabes unis": "AA",
}

# ── Risque opérationnel ─────────────────────────────────────────────────────
LIGNES_METIER = (
    "Financement d'entreprise",
    "Activités de marché",
    "Banque de détail",
    "Banque commerciale",
    "Paiements et règlements",
    "Fonctions d'agent",
    "Gestion d'actifs",
    "Courtage de détail",
)

TYPES_EVENEMENT = ("Interne", "Externe", "Processus", "Système", "Personnel", "Juridique")

CAUSES_RACINE = (
    "Erreur humaine", "Défaillance système", "Processus inadéquat",
    "Fraude interne", "Fraude externe", "Événement externe", "Non définie",
)

STATUTS_INCIDENT = ("Ouvert", "En cours", "Résolu", "Clôturé")

BIC_POSTES = (
    "Intérêts perçus",
    "Intérêts versés",
    "Dividendes perçus",
    "Trésorerie & Banques centrales",
    "Créances sur Étab. de crédit",
    "Créances clientèle (brut)",
    "Provisions sur créances",
    "Autres produits d'exploitation",
    "Autres charges d'exploitation",
    "Commissions perçues",
    "Commissions versées",
    "Résultat net Ptf négociation",
    "Résultat net Ptf bancaire",
    "PNB (BIA — si non calculé automatiquement)",
)

# ── Fonds propres ───────────────────────────────────────────────────────────
FP_POSTES = (
    ("CET1", "Capital ordinaire"),
    ("CET1", "Réserves"),
    ("CET1", "Résultats en report"),
    ("CET1", "Résultat éligible"),
    ("CET1", "Réduction prudentielle (CET1)"),
    ("AT1", "Instruments additionnels (AT1)"),
    ("AT1", "Primes d'émission (AT1)"),
    ("AT1", "Réduction prudentielle (AT1)"),
    ("Tier 2", "Dettes subordonnées (Tier 2)"),
    ("Tier 2", "Provisions générales (Tier 2)"),
    ("Tier 2", "Réduction prudentielle (Tier 2)"),
)

# ── Marché : en-têtes exigés par l'import (ordre du modèle) ────────────────
ENTETES_OBLIGATIONS = [
    "ID Titre", "Date d'analyse", "Pays émetteur", "Zone",
    "Type d'instrument", "Code type d'instrument", "Emetteur",
    "Mode de Placement", "Notation externe_S&P", "Notation externe_Moody's",
    "Notation externe_Fitch", "La pire notation externe", "Notation Interne",
    "Intention comptable", "Classification des titres", "Date d'émission",
    "Devise", "Valeur nominale unitaire", "quantités", "Capital initial",
    "Prix d'émission", "Prime d'émission", "Prix de remboursement",
    "Prime de remboursement", "Date d'échéance", "Coupon (%)",
    "Profil d'amortissement", "Fréquence de paiement des intérêts",
    "Maturité (mois)", "Maturité résiduelle (mois)",
]

ENTETES_ACTIONS = [
    "ID Instrument", "Type d'instrument", "Émetteur / Société", "Secteur",
    "Pays / marché", "Bourse", "Devise", "Intention comptable", "Quantité",
    "Prix d'acquisition", "Cours actuel", "Bêta",
    "Volatilité annualisée (%)", "Rendement dividende (%)",
    "Liquide et diversifié (Oui/Non)",
]

# Taux de conversion vers le XOF utilisés par l'outil.
TAUX_XOF = {"XOF": 1.0, "EUR": 655.957, "USD": 607.0}
