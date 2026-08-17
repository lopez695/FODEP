# 🚀 Quick Reference - Risque de Change Module

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│        FxRiskAnalysisScreen                      │
│   (Interface Utilisateur Complète)              │
└──────────────────┬──────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
┌──────────────────┐  ┌─────────────────────┐
│   KPI Section    │  │  Security Tables    │
│  (4 cartes)      │  │  + Currency Summary │
│                  │  │  + Prudential Calc  │
└──────────────────┘  └─────────────────────┘
        │                     │
        └──────────┬──────────┘
                   │
        ┌──────────▼──────────┐
        │                     │
        ▼                     ▼
┌──────────────────────────────────────────┐
│  FxSecurityAnalysisService               │
│  - analyzePortfolio()                    │
│  - _analyzeSecurities()                  │
│  - _aggregateByCurrency()                │
│  - _calculateGlobalMetrics()             │
└──────────┬───────────────────────────────┘
           │
        ┌──┴──┐
        │     │
        ▼     ▼
    ┌────────────────────────┐
    │  Models & Data         │
    │ ┌────────────────────┐ │
    │ │FxSecurityAnalysis  │ │
    │ │FxCurrencyExposure  │ │
    │ │FxRiskAnalysisResult│ │
    │ └────────────────────┘ │
    └────────────────────────┘
```

## Key Classes

### FxSecurityAnalysis
**Purpose:** Individual security FX impact analysis

```dart
final security = FxSecurityAnalysis(
  titleId: 'US_TREAS_001',
  titleName: 'Obligation Trésor US',
  currency: 'USD',
  initialValue: 100000000,
  currentValue: 102000000,
  initialRate: 580.0,
  currentRate: 625.0,
  quantity: 1.0,
  acquisitionDate: DateTime(2023, 6, 17),
  analysisDate: DateTime.now(),
);

// Access calculations
print(security.fxGainLoss);              // FX Gain/Loss in XOF
print(security.currencyVariationPercent); // Currency variation %
print(security.positionType);            // long/short/neutral
print(security.status);                  // favorable/unfavorable/stable
```

### FxCurrencyExposure
**Purpose:** Aggregate exposure per currency

```dart
final exposure = FxCurrencyExposure(
  currency: 'USD',
  totalLongExposure: 123456789,
  totalShortExposure: 0,
  netExposure: 123456789,
  securitiesCount: 2,
);

print(exposure.positionType);   // long/short/neutral
print(exposure.absoluteNetExposure);
```

### FxRiskAnalysisResult
**Purpose:** Complete analysis result with all levels

```dart
final result = FxRiskAnalysisResult(
  securities: [...],
  currencyExposures: [...],
  totalExposure: 265432109,
  globalFxGainLoss: 1234567,
  totalLongPositions: 265432109,
  totalShortPositions: 0,
  globalNetPosition: 265432109,
  capitalRequirement: 21234568,  // 8% of global net
  rwaChange: 265432100,           // 12.5x capital req
);
```

## Service API

### Main Method: analyzePortfolio()

```dart
final service = FxSecurityAnalysisService();

final result = service.analyzePortfolio(
  records: List<MarketPortfolioRecord>,
  analysisDate: DateTime.now(),
  exchangeRates: {
    'USD': 625.0,
    'EUR': 680.0,
  }, // Optional - uses registry if not provided
);
```

### Quick Demo Data
```dart
final demoResult = FxSecurityAnalysisService.createDemoData();
```

## Screen Usage

### Simple Integration
```dart
// Use demo data
FxRiskAnalysisScreen()

// Or pass analysis result
FxRiskAnalysisScreen(initialData: analysisResult)
```

### With Real Portfolio
```dart
Future<void> showFxAnalysis(BuildContext context) async {
  // 1. Get portfolio
  final records = await getPortfolioRecords();
  
  // 2. Analyze
  final service = FxSecurityAnalysisService();
  final result = service.analyzePortfolio(
    records: records,
    analysisDate: DateTime.now(),
  );
  
  // 3. Show screen
  if (context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FxRiskAnalysisScreen(initialData: result),
      ),
    );
  }
}
```

## Display Sections

### Section 1: Securities Table (Tableau Principal)
Shows impact of FX fluctuations on each security

**Columns:**
- Titre | Devise | Val. Initiale | Val. Actuelle
- Taux Init. | Taux Act. | Var. Dev. (%) | Gain/Perte Change
- Position | Statut

### Section 2: Currency Aggregation (Synthèse par Devise)
Summary by currency

**Columns:**
- Devise | Exp. Longue | Exp. Courte | Exp. Nette
- Position | Titres

### Section 3: Prudential Summary (Synthèse Réglementaire)
BCEAO calculations

**Metrics:**
- Positions Longues = SUM(long exposures)
- Positions Courtes = SUM(short exposures)
- Position Nette Globale = MAX(long, short)
- Exigence FP Change = Global_Net × 8%
- RWA Change = ExigenceFP × 12.5

## Calculations Reference

### Currency Variation
```
Variation(%) = ((Taux_Actuel - Taux_Initial) / Taux_Initial) × 100
```

### FX Gain/Loss
```
GainLoss = (Current_Value × Current_Rate) - (Initial_Value × Initial_Rate)
```

### Position Type Detection
```
IF quantity > 0  THEN Long
IF quantity < 0  THEN Short
IF quantity = 0  THEN Neutral
```

### Status Determination
```
IF GainLoss > 0.01      THEN Favorable (🟢)
IF GainLoss < -0.01     THEN Unfavorable (🔴)
ELSE                    THEN Stable (⚪)
```

### BCEAO Capital Requirement
```
GlobalNetPosition = MAX(TotalLong, TotalShort)
CapitalRequirement = GlobalNetPosition × 0.09
RWAChange = CapitalRequirement × 12.5
```

## Color Scheme

| Color | Usage | RGB |
|-------|-------|-----|
| 🔵 Blue | Primary/Branding | #2563EB |
| 🟢 Green | Favorable/Long | #10B981 |
| 🔴 Red | Unfavorable/Short | #EF4444 |
| 🟠 Orange | Warning/Info | #F59E0B |
| ⚫ Gray | Neutral/Muted | #6B7280 |

## Error Handling

```dart
try {
  final result = service.analyzePortfolio(
    records: records,
    analysisDate: date,
  );
} catch (e) {
  print('Error analyzing portfolio: $e');
  // Fallback to demo data
  showDialog(context: context, builder: ...) 
}
```

## Performance Notes

- ✅ Optimized for thousands of securities
- ✅ Lazy loading of tables
- ✅ Efficient aggregation algorithms
- ✅ Minimal memory footprint

## Customization

### Colors
Edit at top of `fx_risk_analysis_screen.dart`:
```dart
const Color _fxPrimary = Color(0xFF2563EB);
const Color _fxSuccess = Color(0xFF10B981);
```

### Exchange Rates
Pass custom rates to analyzePortfolio():
```dart
final result = service.analyzePortfolio(
  records: records,
  analysisDate: date,
  exchangeRates: {
    'USD': 630.0,  // Custom rate
    'EUR': 690.0,
  },
);
```

## Testing

### Verify Data
```dart
final result = FxSecurityAnalysisService.createDemoData();
assert(result.securities.length == 4);
assert(result.currencyExposures.length == 2);
assert(result.capitalRequirement > 0);
```

### Flutter Analyze
```bash
flutter analyze lib/modules/risque_marche/
```

## Files Summary

| File | Lines | Purpose |
|------|-------|---------|
| fx_security_analysis.dart | 440 | Data models |
| fx_security_analysis_service.dart | 380 | Business logic |
| fx_risk_analysis_screen.dart | 850+ | UI components |
| FX_RISK_ANALYSIS_GUIDE.md | 350+ | Detailed guide |

---

**Last Updated:** June 17, 2024
**Status:** ✅ Production Ready
