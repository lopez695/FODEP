# Modèles d'import — Outil RWA

Quatre classeurs Excel prêts à importer, remplis de données fictives mais
réalistes d'une banque universelle de l'UMOA (« Banque Continentale de
l'Union »), arrêtées au **30 juin 2026**.

Chaque fichier respecte exactement les conditions d'import de l'outil : noms
de feuilles, libellés de colonnes et valeurs autorisées proviennent des listes
d'options du code (validateur backend et dialogues d'import Flutter).

| # | Fichier | Écran | Lignes de données |
|---|---------|-------|-------------------|
| 1 | `1_modele_import_risque_marche.xlsx` | Risque de Marché → Importer données de marché | 700 obligations + 300 actions |
| 2 | `2_modele_import_risque_operationnel.xlsx` | Risque Opérationnel → Importer pertes / Importer BIC | 1 000 incidents + 3 exercices |
| 3 | `3_modele_import_risque_credit.xlsx` | Expositions → Importation de données | 1 000 expositions + 223 CRM |
| 4 | `4_modele_import_fonds_propres.xlsx` | Tableau de bord → Importer les fonds propres | 11 postes |

Chaque classeur contient une feuille **Notice** décrivant son contenu. Elle
n'est lue par aucun import.

## Résultat visé au tableau de bord

Les encours sont dimensionnés pour obtenir une répartition équilibrée du RWA,
avec des fonds propres qui couvrent l'exigence avec une marge de gestion.

| Poste | RWA | Part |
|---|---:|---:|
| Risque de crédit | 536,33 Md FCFA | **65,0 %** |
| Risque de marché | 206,28 Md FCFA | **25,0 %** |
| Risque opérationnel | 82,51 Md FCFA | **10,0 %** |
| **RWA total** | **825,12 Md FCFA** | 100 % |

| Fonds propres | Montant | Ratio |
|---|---:|---:|
| CET1 | 87,42 Md FCFA | 10,60 % |
| AT1 | 5,90 Md FCFA | — |
| Tier 1 | 93,32 Md FCFA | 11,31 % |
| Tier 2 | 13,95 Md FCFA | — |
| **Fonds propres globaux** | **107,27 Md FCFA** | **13,00 %** |

Minimum réglementaire 9 %, porté à 11,5 % coussin de conservation compris : la
banque conserve donc environ 1,5 point de marge.

Ces chiffres ne sont pas une projection : ils sont obtenus en rejouant le
chemin d'import réel du backend sur une copie de la base, puis en lisant le
tableau de bord (`charger_dans_la_base.py`).

## Ordre d'import

Les fonds propres étant calibrés sur les RWA des trois autres modules,
importez-les en dernier : **marché → opérationnel → crédit → fonds propres**.

## 1. Risque de marché

Feuilles `Saisir donnée` (obligations) et `Actions`. Les deux étant présentes,
l'écran bascule automatiquement sur le périmètre « Portefeuille complet ».

- Émetteurs souverains UEMOA, multilatéraux (BOAD, BAD, BID) et entreprises
  cotées ; bons et obligations du Trésor, sukuk, emprunts obligataires.
- L'**intention comptable** pilote le périmètre prudentiel : seules les lignes
  de négociation entrent dans l'exigence taux et actions, le risque de change
  portant lui sur l'ensemble des positions. Le portefeuille de transaction
  représente 40 % des obligations et 55 % des actions — une banque très active
  sur le marché secondaire régional, ce qu'exige la cible de 25 %.
- Encours obligataire 673,18 Md FCFA, valorisation actions 69,03 Md FCFA.
- Exigence de fonds propres 16,50 Md FCFA (taux 6,82 + actions 5,87 +
  change 3,82), soit un RWA marché de 206,28 Md FCFA.

⚠️ Les lignes en EUR et USD ne sont converties correctement que si les taux de
change courants sont renseignés sur l'écran Risque de Change : à défaut,
l'outil applique un taux de 1 et sous-estime ces positions.

## 2. Risque opérationnel

Un seul fichier alimente les deux imports du module ; chaque dialogue ignore
les feuilles qui ne le concernent pas.

- Feuille `Incidents` : 1 000 pertes du 02/01/2023 au 30/06/2026, réparties sur
  les 8 lignes de métier et les 6 types d'événement, sévérité log-normale
  (beaucoup de petits sinistres, quelques dossiers majeurs). Perte brute
  cumulée 17,02 Md FCFA.
- Feuilles `2023`, `2024`, `2025` : les 14 postes de l'indicateur d'activité,
  au format Poste / Valeur. Pour ajouter un exercice, dupliquez un onglet et
  renommez-le avec l'année.
- BI moyen 3 ans = 55,01 Md FCFA (tranche 1) → BIC = 6,60 Md FCFA →
  REA CRR3 = 82,51 Md FCFA.

Le risque opérationnel sert d'**ancrage** au calibrage : son RWA découle de
l'indicateur d'activité, qu'on ne peut pas gonfler sans rendre le compte de
résultat invraisemblable. Les portefeuilles de crédit et de marché sont
dimensionnés autour de lui pour atteindre 65 % et 25 %.

## 3. Risque de crédit

Feuilles `Template données`, `CRM_non_financee` et `CRM_financée`.

- 1 000 expositions réparties sur les 11 catégories prudentielles (a) à (k),
  encours brut 693,21 Md FCFA, EAD 727,60 Md FCFA, RWA 536,33 Md FCFA.
- Créances en souffrance : 59,7 Md FCFA, soit 8,6 % de l'encours brut, avec
  provisions, jours d'impayés (≥ 90) et pondération initiale avant défaut.
- 223 techniques de réduction du risque : 111 garanties personnelles et 112
  sûretés financières, le garant retenu étant cohérent avec la taille et la
  nature de l'exposition couverte.
- Environ 9 % de l'encours est libellé en EUR ou USD. **Les montants sont
  exprimés dans la devise de la ligne**, jamais en contre-valeur FCFA :
  l'outil convertit lui-même au moment d'agréger.
- Aucune colonne calculée n'est fournie (pondération, EAD, RWA, capital) :
  l'outil recalcule tout à l'import avec le moteur de la saisie manuelle.

Ventilation obtenue en rejouant le moteur de calcul du backend (montants en
contre-valeur FCFA) :

| Catégorie | Lignes | Brut (Md) | RWA (Md) | Densité |
|---|---:|---:|---:|---:|
| Entreprises | 210 | 294,9 | 348,6 | 118 % |
| Créances en souffrance | 60 | 59,7 | 62,7 | 105 % |
| Autres actifs | 45 | 66,9 | 44,3 | 66 % |
| Institutions financières | 40 | 38,2 | 32,2 | 84 % |
| Prêts garantis par l'immo C | 40 | 26,7 | 22,1 | 83 % |
| Organismes pub. hors Adm c | 22 | 34,7 | 10,0 | 29 % |
| Clientèle de détail | 455 | 11,8 | 9,6 | 82 % |
| Souverains | 30 | 132,0 | 2,6 | 2 % |
| Prêts garantis par l'immo R | 85 | 4,7 | 2,2 | 47 % |
| Créances à risque élevé | 5 | 1,4 | 2,0 | 142 % |
| Expositions sur les BMD | 8 | 22,2 | 0,0 | 0 % |

Les densités supérieures à 100 % viennent de la composante hors bilan, comptée
dans le RWA mais pas dans l'encours brut.

## 4. Fonds propres

Feuille `Fonds propres`, 11 postes au format Groupe / Poste / Valeur. L'import
remplace intégralement les fonds propres enregistrés (photo unique, pas de
dimension exercice).

Structure retenue : 81,5 % CET1, 5,5 % AT1, 13,0 % Tier 2 — une capitalisation
très majoritairement en fonds propres de base, comme les banques de la zone.

## Correction apportée au backend

`app/dashboard/services.py` retenait `ofr_crr3` comme RWA opérationnel. Or
`ofr_crr3` est l'**exigence de fonds propres**, déjà nette du multiplicateur
réglementaire ; le tableau de bord lui réappliquait ensuite les 9 % du ratio,
divisant l'exigence opérationnelle par 12,5. Le risque opérationnel
s'affichait à 0,0 % du RWA total.

La ligne retient désormais `rea_crr3` (= OFR × 12,5), soit la même convention
que la synthèse du module Risque Opérationnel (`apr = rea_crr3`) et que le
risque de marché (`rwa_marche = capital requis × 12,5`).

## Régénérer et vérifier

```bash
python modeles_import/generer_modeles.py      # produit les quatre classeurs
python modeles_import/verifier_modeles.py     # rejoue les contrôles d'import
python modeles_import/charger_dans_la_base.py # simule le chargement complet
```

`generer_modeles.py` résout par itérations les facteurs d'échelle du crédit et
du marché jusqu'à atteindre les parts visées (`POIDS_CIBLES`), puis calibre les
fonds propres sur le RWA total obtenu.

`charger_dans_la_base.py` travaille par défaut sur une **copie** de la base et
affiche le tableau de bord obtenu, sans rien modifier. L'option
`--base-reelle` écrit dans la base de l'outil après sauvegarde horodatée.

Les tirages sont pilotés par des graines fixes : deux exécutions produisent des
fichiers identiques.

| Module | Rôle |
|---|---|
| `_referentiels.py` | Listes de valeurs autorisées et en-têtes attendus |
| `_styles.py` | Mise en forme commune aux quatre classeurs |
| `gen_credit.py` / `gen_marche.py` / `gen_op.py` / `gen_fp.py` | Génération d'un modèle |
| `calc_marche.py` | Portage Python des règles d'exigence de fonds propres marché |
| `generer_modeles.py` | Calibrage des trois risques et production des fichiers |
| `verifier_modeles.py` | Contrôles d'import (validateur backend + logique des dialogues) |
| `charger_dans_la_base.py` | Chargement complet et restitution du tableau de bord |
