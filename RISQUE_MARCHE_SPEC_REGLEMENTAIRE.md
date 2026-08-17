# Spécification réglementaire — Module Risque de Marché

**Base réglementaire** : Dispositif prudentiel applicable aux établissements de crédit et aux
compagnies financières de l'UMOA — **Titre VI, Art. 316 à 442** (Instruction n°026-11-2016, BCEAO).
**Document pédagogique de référence** : *Market Risk #8 — La vue prudentielle* (Heymanns Inc.).

> Devises gérées par l'application : **XOF, EUR, USD** (XAF/FCFA repliés sur XOF).
> Toutes les positions en devises sont converties en FCFA au **cours comptant** (Art. 352, 397, 411, 415).

---

## 1. Chaîne de transformation prudentielle

```
Position de marché
   → Mesure du risque (par catégorie)
   → Exigence de fonds propres
   → RWA Marché  (= Exigence × 12,5)
   → Ratio de solvabilité (= Fonds Propres / RWA Total ≥ 8,5 %)
```

| Étape | Formule | Article | Code |
|-------|---------|---------|------|
| Exigence globale marché | `Exigence Taux + Actions + Change + Produits` | 318-319 | `MarketPrudentialCapitalResult.capitalRequirement` |
| RWA Marché | `Exigence × 12,5` | 319 (1/0,08) | `MarketPrudentialCapitalResult.marketRwa` |
| Ratio de solvabilité | `Fonds Propres / RWA Total` | Titre II/III | `checkUemoaCapitalLimit` |
| Seuil minimum UMOA | **8,5 %** | doc #8 §5.3 | `minimumRatio = 0.085` |

> ⚠️ Le **8 %** ne sert qu'au facteur de conversion 12,5 (= 1/0,08). Le **seuil de conformité**
> du ratio de solvabilité dans l'UMOA est **8,5 %** (hors coussins Bâle III additionnels).

---

## 2. Mapping article → calcul → code → écran

Fichier de calcul principal : `frontend/lib/modules/risque_marche/services/market_data_import_store.dart`
Présentation : `uemoa_prudential_service.dart` (journal) → écran `_CalculPrudentielWorkspace` /
onglet « Pilotage des risques ».

### 2.1 Risque de taux d'intérêt (Art. 349-394)

`Exigence Taux = Risque Spécifique + Risque Général`

**Risque spécifique** (Art. 353-359, Tableau 16) — `_marketInterestRateSpecificRisk`
| Catégorie | Pondération | Code |
|-----------|-------------|------|
| État UMOA libellé/financé FCFA | **0 %** (Art. 356) | `uemoaSovereignXof` |
| Souverain AAA→A- | 0 % | `_getSpecificRiskWeight` |
| Souverain / éligible A+→BBB- | 0,25 % (<6m) / 1 % (6-24m) / 1,6 % (>24m) | idem |
| BB+→B- | 8 % | idem |
| < B- | 12 % | idem |
| Sans notation | 8 % à 12 % | idem |
| Autres émetteurs (non éligibles) | traitement entreprises approche standard crédit (Art. 357, Titre IV) — **8 %** par défaut | `otherDebt` |

**Risque général** (Art. 360-379, Tableaux 17-18) — `_marketInterestRateGeneralRisk`
Méthode fondée sur les échéances, **par devise** :
1. Ventilation en tranches (Tableau 17, pondération selon coupon ≥/< 3 %) — `_getGeneralRiskWeight`
2. Compensation **verticale** : 10 % de la position appariée par tranche (Art. 371)
3. Compensation **horizontale** : intra-zone 40/30/30 %, inter-zones adjacentes 40 %, zones extrêmes 100 % (Tableau 18) — `_marketMatchMaturityZones`
4. Exigence position nette résiduelle (Art. 379)

### 2.2 Risque sur actions (Art. 395-405)

`Exigence Actions = Risque Spécifique + Risque Général` — `_marketEquityRiskMeasure`

| Composante | Formule | Article | Clé d'agrégation |
|------------|---------|---------|------------------|
| Spécifique | **8 %** (ou 4 %) × Σ \|position nette **par émetteur**\| | 398-399 | `issuerAnalysisKey` |
| Général | **8 %** × Σ \|position nette **par marché** national/régional\| | 400-401 | `marketCountryIso3` (défaut : devise) |

> Option **4 %** pour le risque spécifique (portefeuille liquide et bien diversifié, Art. 399) :
> paramètre `equityPortfolioLiquidAndDiversified` de `calculateMarketPrudentialCapital`
> (désactivé par défaut ; nécessite validation Commission Bancaire et un toggle UI).

### 2.3 Risque de change (Art. 406-417)

`Exigence Change = 8 % × Position Nette Globale` — `_marketForeignExchangeRisk`

- Position nette par devise = Σ actifs − passifs (au comptant + à terme) (Art. 408)
- **Position Nette Globale = MAX(Σ positions longues, Σ positions courtes)** + or (Art. 416)
- Conversion FCFA au cours comptant (Art. 415) — `_marketForeignExchangeGlobalNetPosition`
- Or : traité comme une devise (Art. 406, 412) — non présent (hors périmètre 3 devises)
- **Exemption** (Art. 327) : volume < 100 % FP **et** position nette < 2 % FP —
  `assessMarketRiskExemptions` (à câbler aux données bilan/FP)

### 2.4 Risque sur produits de base (Art. 418-425)

`Exigence Produits = 15 % × |Position nette| + 3 % × Position brute` (par produit) — `_marketCommodityPositionMeasure`
- Compensation entre sous-catégories si corrélation ≥ 0,9 (Art. 423) — non implémentée

### 2.5 Options (Art. 426-443)

Approche simplifiée (achat seul) ou **delta-plus** (delta/gamma/vega).
**Non implémenté** — hors périmètre v1.

---

## 3. État de conformité

| Catégorie | Statut | Note |
|-----------|--------|------|
| Chaîne FP → RWA → ratio | ✅ Conforme | facteur 12,5 ; seuil 8,5 % |
| Change | ✅ Conforme | MAX(long, court) × 8 % |
| Produits de base | ✅ Conforme | 15 % net + 3 % brut |
| Taux — risque général | ✅ Conforme | échéancier + zones + compensations |
| Taux — risque spécifique | ✅ Conforme | Tableau 16 ; « Autres » = 8 % (Art. 357) |
| Actions | ✅ Conforme | spécifique par émetteur, général par marché ; option 4 % |
| Portefeuille négociation vs bancaire | ✅ Conforme | taux/actions sur le trading book (intention comptable) ; change sur tout l'établissement (Art. 406) |
| Exemptions (Art. 326-327) | 🟡 Fonction disponible | `assessMarketRiskExemptions` ; à câbler aux entrées bilan/FP |
| Options (Art. 426-443) | ⛔ Non implémenté | delta-plus (nécessite un modèle de données options) |

---

## 4. Limitations connues / refinements futurs

1. ✅ **Séparation portefeuille de négociation / bancaire** (Art. 321) — implémentée via
   l'intention comptable (`isTradingBook` : Trading/HFT/FVTPL = négociation ; HTM/AFS = bancaire ;
   intention inconnue = incluse par prudence). Taux et actions restreints au trading book.
2. 🟡 **Exemptions de calcul** (Art. 326-327) — `assessMarketRiskExemptions` disponible ; reste à
   câbler les entrées (actif total, hors-bilan, dérivés, fonds propres) depuis le reste de l'app,
   puis à exposer le résultat (et éventuellement neutraliser les charges exonérées).
3. 🟡 **Risque actions spécifique à 4 %** (Art. 399) — paramètre disponible ; reste à exposer un
   toggle UI (sous approbation Commission Bancaire).
4. ⛔ **Options** : méthode delta-plus (sensibilités grecques) — nécessite un modèle de données
   options (strike, volatilité, grecques) absent de l'import actuel.
5. ⛔ **Sous-calibrage « Autres titres »** (Art. 357) selon la table entreprises du Titre IV —
   8 % conservateur conservé (un raffinement risquerait de dégrader la précision).
6. `equity_risk_service.dart` est un calculateur actions **secondaire** (dashboard) ; la référence
   prudentielle est `calculateMarketPrudentialCapital` dans `market_data_import_store.dart`.
