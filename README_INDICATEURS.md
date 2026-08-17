# Guide des Indicateurs Prudentiels & Risques (Risk Management)

**Auteur :** Équipe IT Finance  
**Référentiel :** Dispositif Prudentiel BCEAO / UMOA (Bâle III adapté)  

---

## Introduction

Ce document présente l'ensemble des indicateurs calculés et suivis dans l'application **Risk Management**. 
Chaque métrique est décomposée de manière claire en 3 axes :
1. **À quoi ça sert ?** (Définition financière et rôle)
2. **Comment c'est calculé ?** (Formule réglementaire)
3. **De quoi avons-nous besoin ?** (Données d'entrée nécessaires)

---

## 1. Fonds Propres Réglementaires & Ratios Prudentiels

### 1.1 Fonds Propres Effectifs (FPE)
- **À quoi ça sert ?** Mesure la totalité des ressources financières permanentes de la banque destinées à absorber d'éventuelles pertes.
- **Comment c'est calculé ?**  
  FPE = Tier 1 (Capital de base) + Tier 2 (Complémentaire)  
  *Le Tier 1 regroupe le CET1 (capital social, réserves) et l'AT1. Le Tier 2 inclut les dettes subordonnées et provisions.*
- **De quoi a-t-on besoin ?** Capital social, réserves réglementaires, report à nouveau, résultat éligible, emprunts subordonnés et déductions prudentielles.

### 1.2 Ratio CET1 (Common Equity Tier 1)
- **À quoi ça sert ?** Mesure la couverture des risques uniquement par les fonds propres de la plus haute qualité (actions ordinaires et réserves), capables d'absorber les pertes en continuité d'exploitation.
- **Comment c'est calculé ?**  
  Ratio CET1 = CET1 / RWA Total  
  *Seuil réglementaire Pilier 1 : 5.0% | Seuil cible avec Coussin de conservation : 7.5%*
- **De quoi a-t-on besoin ?** Capital ordinaire, réserves légales, report à nouveau, résultat éligible, déductions CET1 et RWA Total.

### 1.3 Ratio Tier 1 (Capital de Base)
- **À quoi ça sert ?** Évalue la solvabilité fondamentale de l'établissement en incluant le CET1 et les instruments de fonds propres additionnels de catégorie 1 (AT1).
- **Comment c'est calculé ?**  
  Ratio Tier 1 = Tier 1 / RWA Total  
  *Seuil réglementaire Pilier 1 : 6.0% | Seuil cible avec Coussin de conservation : 8.5%*
- **De quoi a-t-on besoin ?** Fonds propres CET1, instruments additionnels AT1 (actions de préférence...) et RWA Total.

### 1.4 Ratio de Solvabilité Globale (CAR - Capital Adequacy Ratio)
- **À quoi ça sert ?** Vérifie que la banque possède un niveau de capital total (FPE) suffisant pour couvrir l'ensemble de ses risques (Crédit, Marché, Opérationnel).
- **Comment c'est calculé ?**  
  Ratio Solvabilité = Fonds Propres Effectifs (FPE) / RWA Total  
  *Seuil réglementaire Pilier 1 : 9.0% | Seuil cible avec Coussin de conservation : 11.5%*
- **De quoi a-t-on besoin ?** Fonds Propres Effectifs (FPE) et montant total des RWA (Crédit + Marché + Opérationnel).

### 1.5 Ratio de Levier
- **À quoi ça sert ?** Mesure de sécurité non basée sur le risque pour éviter un surendettement excessif au bilan et hors-bilan.
- **Comment c'est calculé ?**  
  Ratio Levier = Tier 1 / Expositions Totales (non pondérées)  
  *Seuil réglementaire minimal : 3.0%*
- **De quoi a-t-on besoin ?** Capital Tier 1 et total des expositions brutes bilan + équivalents crédit hors-bilan.

---

## 2. Risque de Crédit & Actifs Pondérés (RWA)

### 2.1 Exposition au Défaut (EAD - Exposure at Default)
- **À quoi ça sert ?** Mesure le montant total du crédit auquel la banque est réellement exposée au moment du défaut.
- **Comment c'est calculé ?**  
  EAD Bilan = Encours Brut au Bilan  
  EAD Hors-Bilan = Nominal x CCF (Facteur de conversion : 0%, 20%, 50%, 100%)  
  EAD Total = EAD Bilan + EAD Hors-Bilan
- **De quoi a-t-on besoin ?** Encours comptable brut au bilan, nominal hors-bilan, type d'engagement.

### 2.2 Actifs Pondérés par le Risque de Crédit (RWA Crédit)
- **À quoi ça sert ?** Ajuste le montant de l'exposition au niveau de risque et de solvabilité de l'emprunteur. Dénominateur principal des ratios de solvabilité.
- **Comment c'est calculé ?**  
  RWA Crédit = EAD x Pondération (%)  
  *La pondération dépend de la classe de contrepartie (Souverain, Banque, PME...) et de la notation (AAA à < B-).*
- **De quoi a-t-on besoin ?** EAD, catégorie prudentielle, notation externe d'agence ou statut non noté.

### 2.3 Exigence de Fonds Propres Crédit (Capital Requis)
- **À quoi ça sert ?** Représente la réserve obligatoire de fonds propres en valeur monétaire (XOF) nécessaire pour couvrir le portefeuille de prêt.
- **Comment c'est calculé ?**  
  Capital Requis Crédit = RWA Crédit x 9.0%  
  *Seuil légal BCEAO : 9.0% (11.5% avec coussin).*
- **De quoi a-t-on besoin ?** RWA Crédit total du portefeuille.

### 2.4 Atténuation du Risque de Crédit (CRM) & Risque Résiduel
- **À quoi ça sert ?** Mesure la réduction d'exigence de fonds propres permise par l'obtention de garanties éligibles (hypothèques, cautions, avals).
- **Comment c'est calculé ?**  
  Couverture CRM (%) = Couverture / Exposition Brute  
  Risque Résiduel = max(0, Exposition Brute - Couverture CRM)
- **De quoi a-t-on besoin ?** Type de garantie, valeur d'expertise, décotes réglementaires (Haircuts) et notation du garant.

### 2.5 Taux de Défaut & Créances Souffrance (NPL)
- **À quoi ça sert ?** Détecte la dégradation de la qualité des crédits et la dépréciation des créances.
- **Comment c'est calculé ?**  
  Taux de Défaut = Encours en Défaut (>= 90 jours) / Exposition Brute  
  Taux de Couverture NPL = Provisions NPL / Encours NPL x 100
- **De quoi a-t-on besoin ?** Statut prudentiel des lignes (impayés >= 90j), encours dépréciés, provisions individuelles.

---

## 3. Risque Opérationnel

### 3.1 Business Indicator Component (BIC / CRR3 - Méthode Principale)
- **À quoi ça sert ?** Évalue les fonds propres requis selon le volume d'activité consolidé (ILDC, SC, FC).
- **Comment c'est calculé ?**  
  BI = ILDC + SC + FC  
  BIC = Application de taux marginaux (12%, 15%, 18%) sur BI  
  RWA Opérationnel = BIC x 11.111
- **De quoi a-t-on besoin ?** 12 postes du compte de résultat sur 3 ans.

### 3.2 Approche Indicateur de Base (AIB - Repli BCEAO)
- **À quoi ça sert ?** Méthode forfaitaire de repli basée sur le Produit Net Bancaire (PNB).
- **Comment c'est calculé ?**  
  Capital AIB = 15% x Moyenne(PNB > 0 sur 3 ans)  
  RWA AIB = Capital AIB x 11.111
- **De quoi a-t-on besoin ?** PNB annuel des 3 derniers exercices.

### 3.3 Approche Standardisée par Lignes de Métier (AS)
- **À quoi ça sert ?** Pondère le PNB selon le profil de risque propre à chaque ligne de métier (Banque de détail, Banque d'investissement, Paiements...).
- **Comment c'est calculé ?**  
  Capital AS = Somme(PNB_i x Beta_i)  
  *Beta_i = Facteur réglementaire par métier (12%, 15%, 18%).*
- **De quoi a-t-on besoin ?** Ventilation du PNB par ligne d'activité réglementaire.

### 3.4 Suivi des Pertes Opérationnelles & Recouvrements
- **À quoi ça sert ?** Comptabilise l'impact financier réel des incidents (fraudes, pannes, litiges).
- **Comment c'est calculé ?**  
  Perte Nette = Perte Brute - Recouvrements  
  Taux de Recouvrement = Recouvrements / Perte Brute x 100
- **De quoi a-t-on besoin ?** Base d'incidents déclarés, pertes brutes et indemnisations d'assurance.

### 3.5 Cartographie des Risques & Scoring du Risque Résiduel
- **À quoi ça sert ?** Évalue l'exposition nette de la banque après prise en compte de la qualité du contrôle interne.
- **Comment c'est calculé ?**  
  Risque Brut = Probabilité (1-5) x Impact (1-5)  
  Risque Résiduel = Risque Brut / Efficacité du Contrôle Interne
- **De quoi a-t-on besoin ?** Évaluation Fréquence/Gravité et score d'efficacité des contrôles.

### 3.6 Indicateurs Clés de Risque (KRI) & Taux de Conformité
- **À quoi ça sert ?** Alerte de manière précoce sur la dérive des processus et mesure le suivi des plans d'action.
- **Comment c'est calculé ?**  
  KRI Taux d'Erreur = Incidents du Mois / Total Incidents  
  Taux de Conformité = Points Conformes / Total Points Contrôlés x 100
- **De quoi a-t-on besoin ?** Relevé mensuel des métriques KRI et résultats des contrôles permanents.

---

## 4. Risque de Marché

### 4.1 Exigence Globale de Fonds Propres & RWA Marché
- **À quoi ça sert ?** Agrège l'ensemble des charges de capital réglementaire au titre des risques de taux, d'actions et de change.
- **Comment c'est calculé ?**  
  Exigence Marché = Exigence Taux + Actions + Change  
  RWA Marché = Exigence Marché x 11.111
- **De quoi a-t-on besoin ?** Positions de change par devise, portefeuille de titres de transaction (obligations, actions).

### 4.2 Risque de Change (Position Nette Globale FX)
- **À quoi ça sert ?** Couvre le risque de perte lié aux variations des cours des devises étrangères au bilan et au hors-bilan.
- **Comment c'est calculé ?**  
  Position Nette Globale = MAX(Somme Positions Longues, Somme Positions Courtes)  
  Exigence Change = Position Nette Globale x 8.0%  
  RWA Change = Exigence Change x 11.111
- **De quoi a-t-on besoin ?** Actifs/passifs en devises (au comptant & à terme), cours de change du jour (USD, EUR...).

### 4.3 Risque de Taux d'Intérêt (Portefeuille Titres / Obligations)
- **À quoi ça sert ?** Protège contre la dépréciation des obligations et bons du Trésor suite à une hausse des taux d'intérêt.
- **Comment c'est calculé ?**  
  Exigence Taux = Risque Spécifique (pondération émetteur Tableau 16) + Risque Général (méthode par échéances)
- **De quoi a-t-on besoin ?** Titres de transaction, maturité résiduelle, coupon, courbe de taux UMOA / BEAC.

### 4.4 Risque sur Actions
- **À quoi ça sert ?** Couvre la baisse de la valeur marchande des actions et titres de propriété négociés sur les marchés.
- **Comment c'est calculé ?**  
  Risque Spécifique = 8% x Somme(|Pos. Net par émetteur|)  
  Risque Général = 8% x Somme(|Pos. Net par marché|)
- **De quoi a-t-on besoin ?** Positions acheteuses/vendeuses par émetteur, cours boursiers (BRVM...).

---

## 5. Concentration, Grands Risques & Dashboard de Pilotage

### 5.1 Grands Risques BCEAO (Plafond de 25% des Fonds Propres)
- **À quoi ça sert ?** Limite l'exposition maximale de la banque sur une seule contrepartie ou groupe d'emprunteurs liés.
- **Comment c'est calculé ?**  
  Ratio Grand Risque = EAD Contrepartie / Fonds Propres Effectifs (FPE)  
  *Seuil de déclaration obligatoire : &ge; 10.0% des FPE | Limite réglementaire maximale : 25.0% des FPE.*
- **De quoi a-t-on besoin ?** EAD par contrepartie/groupe lié, montant des FPE.

### 5.2 Indice de Concentration HHI (Herfindahl-Hirschman Index)
- **À quoi ça sert ?** Mesure la qualité de la diversification du portefeuille (par secteur, zone géographique ou contrepartie).
- **Comment c'est calculé ?**  
  HHI = Somme(Part_i)²   où   Part_i = Exposition_i / Exposition Totale  
  *HHI < 0.15 : Faible concentration | 0.15 à 0.25 : Modérée | > 0.25 : Forte concentration (Alerte).*
- **De quoi a-t-on besoin ?** Encours bruts répartis par secteur, pays et groupe client.

### 5.3 Système d'Alertes d'Incidents Critiques (Tableau de Bord)

| Indicateur d'Alerte | Seuil de Déclenchement Automatique | Rôle & Impact Business | Action Corrective Recommandée |
|---|:---:|---|---|
| **Taux de Défaut Élevé** | Taux &ge; 5.0% | Dégradation de la qualité des crédits. | Revue des comités & provisionnement. |
| **Concentration Contrepartie** | Part &ge; 35.0% du RWA | Dépendance excessive vis-à-vis d'un groupe. | Syndication & gel des lignes. |
| **Dépassement Grand Risque** | Encours &ge; 25.0% des FPE | Non-conformité réglementaire BCEAO. | Réduction immédiate des autorisations. |
| **Concentration Sectorielle** | HHI > 0.25 | Vulnerabilité à un choc sectoriel. | Rééquilibrage de la politique d'octroi. |

---

## 6. Synthèse des Ratios Réglementaires BCEAO

| Indicateur | Formule | Pilier 1 (Legal) | Coussin Conservation | Cible Globale |
|---|---|:---:|:---:|:---:|
| **Ratio CET1** | CET1 / RWA Total | **5.0%** | +2.5% | **7.5%** |
| **Ratio Tier 1** | Tier 1 / RWA Total | **6.0%** | +2.5% | **8.5%** |
| **Ratio Solvabilité** | FPE / RWA Total | **9.0%** | +2.5% | **11.5%** |
| **Ratio de Levier** | Tier 1 / Expositions Totales | **3.0%** | — | **3.0%** |

---
*Documentation - Risk Management - Conforme au Dispositif Prudentiel BCEAO / UMOA.*
