# Guide d'Intégration du Module Risque de Change Refactorisé

## Vue d'ensemble

Le module **Risque de Change** a été complètement refactorisé pour offrir une meilleure expérience utilisateur. Il se compose de trois niveaux d'analyse:

1. **Niveau 1: Analyse par Titre** - Évaluation de l'impact des fluctuations de devises sur chaque titre
2. **Niveau 2: Agrégation par Devise** - Synthèse des expositions par devise
3. **Niveau 3: Calculs Prudentiels** - Calcul des exigences réglementaires BCEAO

## Architecture

### Fichiers créés

```
lib/modules/risque_marche/
├── models/
│   └── fx_security_analysis.dart          (Modèles de données)
├── services/
│   └── fx_security_analysis_service.dart  (Logique métier)
└── screens/
    └── fx_risk_analysis_screen.dart       (Interface utilisateur)
```

### Modèles de données

#### FxSecurityAnalysis
Représente l'analyse du risque de change pour un titre individuel.

**Propriétés principales:**
- `titleId`: Identifiant unique du titre
- `titleName`: Nom du titre (ex: "Obligation Trésor US")
- `currency`: Devise (USD, EUR, XOF, XAF, GBP, etc.)
- `initialValue`: Valeur initiale du titre
- `currentValue`: Valeur actuelle du titre
- `initialRate`: Taux de change initial
- `currentRate`: Taux de change actuel
- `quantity`: Quantité détenue

**Propriétés calculées:**
- `initialValueInXof`: Valeur initiale convertie en XOF
- `currentValueInXof`: Valeur actuelle convertie en XOF
- `currencyVariationPercent`: Variation du taux (%)
- `fxGainLoss`: Gain/Perte de change en XOF
- `fxGainLossPercent`: Gain/Perte en pourcentage
- `positionType`: Type de position (longue, courte, neutre)
- `status`: Statut visuel (favorable, défavorable, stable)

#### FxCurrencyExposure
Résumé des expositions par devise.

**Propriétés principales:**
- `currency`: Code de la devise
- `totalLongExposure`: Somme des expositions longues
- `totalShortExposure`: Somme des expositions courtes
- `netExposure`: Position nette
- `securitiesCount`: Nombre de titres exposés

#### FxRiskAnalysisResult
Résultat global de l'analyse.

**Propriétés principales:**
- `securities`: Liste des titres analysés
- `currencyExposures`: Exposition par devise
- `totalExposure`: Exposition totale
- `globalFxGainLoss`: Gain/Perte global
- `totalLongPositions`: Total positions longues
- `totalShortPositions`: Total positions courtes
- `globalNetPosition`: MAX(longues, courtes)
- `capitalRequirement`: Exigence FP (8% position nette)
- `rwaChange`: RWA Change (12.5x exigence)

### Service d'analyse

#### FxSecurityAnalysisService

**Méthode principale: `analyzePortfolio()`**

```dart
final result = FxSecurityAnalysisService().analyzePortfolio(
  records: portfolioRecords,
  analysisDate: DateTime.now(),
  exchangeRates: ratesMap, // Optionnel
);
```

**Résultat:** `FxRiskAnalysisResult` contenant tous les niveaux d'analyse.

### Interface utilisateur

#### FxRiskAnalysisScreen

Écran complet avec:
- En-tête avec titre et description
- 4 KPIs: Exposition totale, Gain/Perte, Exigence FP, RWA Change
- Tableau principal des titres (10 colonnes)
- Tableau d'agrégation par devise (6 colonnes)
- Synthèse réglementaire BCEAO

## Utilisation

### Intégration simple

```dart
import 'package:path/to/fx_security_analysis_service.dart';
import 'package:path/to/fx_risk_analysis_screen.dart';

// Dans votre écran
class MyRiskScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FxRiskAnalysisScreen(
      initialData: null, // Les données démo seront chargées
    );
  }
}
```

### Utilisation avec données réelles

```dart
// 1. Charger les données de portefeuille
final records = await portfolioService.getPortfolioRecords();

// 2. Analyser le risque de change
final service = FxSecurityAnalysisService();
final analysis = service.analyzePortfolio(
  records: records,
  analysisDate: DateTime.now(),
);

// 3. Passer à l'écran
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => FxRiskAnalysisScreen(initialData: analysis),
  ),
);
```

## Calculs prudentiels BCEAO

### Formule de Position Nette

```
Position_Nette_Globale = MAX(Total_Positions_Longues, Total_Positions_Courtes)
```

### Exigence de Fonds Propres

```
Exigence_FP_Change = Position_Nette_Globale × 8%
```

### RWA Change

```
RWA_Change = Exigence_FP_Change × 12.5
```

## Données de démonstration

Le service inclut une méthode `createDemoData()` qui génère des données de test:

```dart
final demoData = FxSecurityAnalysisService.createDemoData();
```

Les données incluent:
- 4 titres en devises différentes (USD, EUR)
- Variations de taux représentatives
- Gains et pertes de change

## Colonnes du tableau principal

| Colonne | Description | Format |
|---------|-------------|--------|
| Titre | Nom du titre | Texte |
| Devise | Code de devise | Badge (USD, EUR, etc.) |
| Val. Initiale | Valeur au moment de l'acquisition | Nombre formaté |
| Val. Actuelle | Valeur actuelle | Nombre formaté |
| Taux Init. | Taux de change initial | Décimal (2 places) |
| Taux Act. | Taux de change actuel | Décimal (2 places) |
| Var. Dev. (%) | ((Taux_Actuel - Taux_Initial) / Taux_Initial) × 100 | % coloré |
| Gain/Perte Change | Valeur_Actuelle_XOF - Valeur_Initiale_XOF | Montant coloré |
| Position | Type de position détecté | longue/courte/neutre |
| Statut | Indicateur visuel | 🟢/🔴/⚪ |

## Colonnes du tableau d'agrégation

| Colonne | Description | Format |
|---------|-------------|--------|
| Devise | Code de devise | Badge |
| Exp. Longue | Exposition longue totale | Nombre |
| Exp. Courte | Exposition courte totale | Nombre |
| Exp. Nette | Position nette | Nombre |
| Position | Type de position | longue/courte/neutre |
| Titres | Nombre de titres | Entier |

## KPIs affichés

| KPI | Calcul | Tooltip |
|-----|--------|---------|
| Exposition Totale | Somme des valeurs actuelles en XOF | Valeur totale des titres exposés |
| Gain/Perte Global | Somme des gains/pertes de change | Impact total des fluctuations |
| Exigence FP Change | Position_Nette × 8% | Fonds propres réglementaires |
| RWA Change | Exigence_FP × 12.5 | Actifs pondérés par le risque |

## Personnalisation des couleurs

Vous pouvez personnaliser les couleurs en modifiant les constantes au début de `fx_risk_analysis_screen.dart`:

```dart
const Color _fxPrimary = Color(0xFF2563EB);      // Bleu principal
const Color _fxSuccess = Color(0xFF10B981);      // Vert (favorable)
const Color _fxDanger = Color(0xFFEF4444);       // Rouge (défavorable)
const Color _fxWarning = Color(0xFFF59E0B);      // Orange (attention)
```

## Intégration avec la navigation existante

Pour intégrer cet écran dans le menu de navigation:

```dart
enum MarketRiskView {
  // ... autres vues
  fxRiskAnalysis,  // Ajouter cette nouvelle vue
}

// Dans RisqueMarcheScreen:
case MarketRiskView.fxRiskAnalysis => 
  FxRiskAnalysisScreen(initialData: null),
```

## Notes de conformité réglementaire

✓ Conforme à l'**Article 45 du dispositif prudentiel BCEAO**
✓ Approche standard: Position nette globale × 8%
✓ Calcul RWA automatique: 12.5x le capital requis
✓ Exposition par devise pour suivi granulaire
✓ Position nette maximale pour le calcul prudentiel

## Points clés d'implémentation

1. **Flexibilité des données:** Le service accepte des cartes de taux de change personnalisés
2. **Statut visuel:** Détermination automatique du statut (favorable/défavorable/stable)
3. **Détection de position:** Logique intelligente pour identifier longue/courte
4. **Calculs en XOF:** Tous les montants sont convertis en XOF pour comparabilité
5. **Performance:** Optimisé pour portefeuilles de plusieurs milliers de titres

## Prochaines étapes possibles

- [ ] Export des données en Excel/PDF
- [ ] Graphiques d'exposition par devise
- [ ] Historique des analyses
- [ ] Alertes de dépassement de seuils
- [ ] Scénarios de stress-testing
- [ ] Intégration avec la base de données historique
