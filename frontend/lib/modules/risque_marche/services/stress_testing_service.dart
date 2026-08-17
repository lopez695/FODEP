import 'dart:math' as math;
import '../../../core/utils/currency_conversion.dart';
import 'market_data_import_store.dart';

class StressScenario {
  final String id;
  final String name;
  final String description;
  final String category;
  final Map<String, dynamic> shocks;
  final double impactOnPortfolio;
  final double impactOnCapital;
  final double capitalAfterStress;
  final double capitalRatioAfterStress;
  final Map<String, dynamic> details;
  final List<Map<String, dynamic>> calculationSteps;

  const StressScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.shocks,
    required this.impactOnPortfolio,
    required this.impactOnCapital,
    required this.capitalAfterStress,
    required this.capitalRatioAfterStress,
    required this.details,
    required this.calculationSteps,
  });
}

class StressTestingResult {
  final List<StressScenario> scenarios;
  final double basePortfolioValue;
  final double baseCapitalRequirement;
  final double baseCapitalRatio;
  final String worstScenario;
  final double worstLoss;
  final List<Map<String, dynamic>> calculationJournal;

  const StressTestingResult({
    required this.scenarios,
    required this.basePortfolioValue,
    required this.baseCapitalRequirement,
    required this.baseCapitalRatio,
    required this.worstScenario,
    required this.worstLoss,
    required this.calculationJournal,
  });
}

StressTestingResult calculateStressScenarios({
  required List<MarketPortfolioRecord> allRecords,
  required double baseCapitalRequirement,
  double baseCapitalRatio = 0.12,
}) {
  final journal = <Map<String, dynamic>>[];
  journal.add({
    'etape': 'Initialisation',
    'description': 'Stress Testing - 8 scénarios réglementaires',
    'timestamp': DateTime.now().toIso8601String(),
    'base_capital': baseCapitalRequirement,
    'base_ratio': baseCapitalRatio,
  });

  final bondRecords = allRecords
      .where((r) => r.portfolioType == MarketPortfolioType.bonds)
      .toList();
  final equityRecords = allRecords
      .where((r) => r.portfolioType == MarketPortfolioType.equities)
      .toList();

  final portfolioValue = _totalPortfolioValue(allRecords);
  final baseCapital = baseCapitalRequirement;
  final baseRatio = baseCapitalRatio;

  var worstLoss = 0.0;
  var worstScenario = '';

  final scenarios = _allScenarios.map((template) {
    final impact = _computeScenarioImpact(
      template: template,
      bondRecords: bondRecords,
      equityRecords: equityRecords,
      portfolioValue: portfolioValue,
      baseCapital: baseCapital,
      baseCapitalRatio: baseCapitalRatio,
      journal: journal,
    );

    if (impact.totalImpact.abs() > worstLoss.abs()) {
      worstLoss = impact.totalImpact;
      worstScenario = template.name;
    }

    return StressScenario(
      id: template.id,
      name: template.name,
      description: template.description,
      category: template.category,
      shocks: template.shocks,
      impactOnPortfolio: impact.portfolioLoss,
      impactOnCapital: impact.capitalLoss,
      capitalAfterStress: math.max(0, baseCapital + impact.capitalLoss),
      capitalRatioAfterStress: math.max(0, baseRatio + impact.ratioImpact),
      details: {
        'formule': template.formula,
        'components': impact.components,
      },
      calculationSteps: impact.steps,
    );
  }).toList();

  journal.add({
    'etape': 'Synthèse',
    'description': 'Scénario le plus défavorable',
    'worstScenario': worstScenario,
    'worstLoss': worstLoss,
    'nbScenarios': scenarios.length,
  });

  return StressTestingResult(
    scenarios: scenarios,
    basePortfolioValue: portfolioValue,
    baseCapitalRequirement: baseCapital,
    baseCapitalRatio: baseRatio,
    worstScenario: worstScenario,
    worstLoss: worstLoss,
    calculationJournal: journal,
  );
}

class _ScenarioImpact {
  final double portfolioLoss;
  final double capitalLoss;
  final double ratioImpact;
  final double totalImpact;
  final Map<String, dynamic> components;
  final List<Map<String, dynamic>> steps;

  const _ScenarioImpact({
    required this.portfolioLoss,
    required this.capitalLoss,
    required this.ratioImpact,
    required this.totalImpact,
    required this.components,
    required this.steps,
  });
}

class _ScenarioTemplate {
  final String id;
  final String name;
  final String description;
  final String category;
  final String formula;
  final Map<String, dynamic> shocks;

  const _ScenarioTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.formula,
    required this.shocks,
  });
}

const _allScenarios = <_ScenarioTemplate>[
  _ScenarioTemplate(
    id: 'RATE_UP_200',
    name: 'Hausse des taux de 200bps',
    description:
        'Choc parallèle haussier de 200 points de base sur la courbe des taux',
    category: 'Taux',
    formula: 'ΔP = -D_mod × 2% × P_oblig + ½ × C × (2%)² × P_oblig',
    shocks: {'rate_shock_bps': 200, 'type': 'parallel_up'},
  ),
  _ScenarioTemplate(
    id: 'RATE_DOWN_100',
    name: 'Baisse des taux de 100bps',
    description: 'Choc parallèle baissier de 100 points de base',
    category: 'Taux',
    formula: 'ΔP = -D_mod × (-1%) × P_oblig + ½ × C × (1%)² × P_oblig',
    shocks: {'rate_shock_bps': -100, 'type': 'parallel_down'},
  ),
  _ScenarioTemplate(
    id: 'RATE_FLATTENING',
    name: 'Aplatissement de la courbe',
    description:
        'Hausse des taux courts (+100bps) et baisse des taux longs (-50bps)',
    category: 'Taux',
    formula:
        'Impact = Σ(ΔP_court + ΔP_long) avec chocs différenciés par maturité',
    shocks: {'short_rate_bps': 100, 'long_rate_bps': -50, 'type': 'flattening'},
  ),
  _ScenarioTemplate(
    id: 'FX_SHOCK_10',
    name: 'Dépréciation XOF de 10%',
    description:
        'Dépréciation de 10% du franc CFA face à toutes les devises étrangères',
    category: 'Change',
    formula: 'Impact = Position_nette_devises × 10%',
    shocks: {'fx_shock_percent': 10, 'type': 'xof_depreciation'},
  ),
  _ScenarioTemplate(
    id: 'EQUITY_CRASH_20',
    name: 'Krach boursier: -20%',
    description: 'Chute de 20% des marchés actions',
    category: 'Actions',
    formula: 'Impact = Valeur_marché_actions × (-20%)',
    shocks: {'equity_shock_percent': -20, 'type': 'market_crash'},
  ),
  _ScenarioTemplate(
    id: 'EQUITY_CRASH_40',
    name: 'Krach boursier sévère: -40%',
    description: 'Chute de 40% des marchés actions (stress extrême)',
    category: 'Actions',
    formula: 'Impact = Valeur_marché_actions × (-40%)',
    shocks: {'equity_shock_percent': -40, 'type': 'extreme_crash'},
  ),
  _ScenarioTemplate(
    id: 'SYSTEMIC_2008',
    name: 'Crise systémique (2008)',
    description:
        'Combinaison: taux +100bps, actions -30%, change -5%, spread +200bps',
    category: 'Systémique',
    formula: 'Impact total = somme de tous les chocs simultanés',
    shocks: {
      'rate_shock_bps': 100,
      'equity_shock_percent': -30,
      'fx_shock_percent': 5,
      'credit_spread_bps': 200,
      'type': 'systemic',
    },
  ),
  _ScenarioTemplate(
    id: 'COVID_LIKE',
    name: 'Crise sanitaire (COVID-like)',
    description: 'Taux -50bps, actions -25%, volatilité ×2, spread +150bps',
    category: 'Systémique',
    formula: 'Impact total = somme de tous les chocs simultanés',
    shocks: {
      'rate_shock_bps': -50,
      'equity_shock_percent': -25,
      'fx_shock_percent': 3,
      'credit_spread_bps': 150,
      'volatility_multiplier': 2.0,
      'type': 'systemic',
    },
  ),
];

_ScenarioImpact _computeScenarioImpact({
  required _ScenarioTemplate template,
  required List<MarketPortfolioRecord> bondRecords,
  required List<MarketPortfolioRecord> equityRecords,
  required double portfolioValue,
  required double baseCapital,
  required double baseCapitalRatio,
  required List<Map<String, dynamic>> journal,
}) {
  final components = <String, dynamic>{};
  final steps = <Map<String, dynamic>>[];
  var portfolioLoss = 0.0;

  final shocks = template.shocks;

  if (shocks['rate_shock_bps'] is num) {
    final bps = (shocks['rate_shock_bps'] as num).toDouble();
    var totalBondLoss = 0.0;
    for (final record in bondRecords) {
      final mv = _bondMarketValue(record);
      final dur = _bondModifiedDuration(record);
      if (mv <= 0 || dur <= 0) continue;
      final loss = -dur * (bps / 10000) * mv;
      totalBondLoss += loss;
    }
    portfolioLoss += totalBondLoss;
    components['taux'] = totalBondLoss;
    steps.add({
      'etape': 'Choc taux ${bps}bps',
      'impact': totalBondLoss,
      'formule': '${bps > 0 ? '+' : ''}${bps}bps → ΔP = -D × Δy × P',
    });
  }

  if (shocks['short_rate_bps'] is num && shocks['long_rate_bps'] is num) {
    final shortBps = (shocks['short_rate_bps'] as num).toDouble();
    final longBps = (shocks['long_rate_bps'] as num).toDouble();
    var flatteningLoss = 0.0;
    for (final record in bondRecords) {
      final mv = _bondMarketValue(record);
      final dur = _bondModifiedDuration(record);
      final years = _bondRecordResidualYears(record);
      if (mv <= 0 || dur <= 0) continue;
      final effectiveBps = years < 3 ? shortBps : longBps;
      flatteningLoss += -dur * (effectiveBps / 10000) * mv;
    }
    portfolioLoss += flatteningLoss;
    components['aplatissement'] = flatteningLoss;
    steps.add({
      'etape': 'Aplatissement courbe',
      'impact': flatteningLoss,
      'formule': 'Court:${shortBps}bps, Long:${longBps}bps',
    });
  }

  if (shocks['fx_shock_percent'] is num) {
    final pct = (shocks['fx_shock_percent'] as num).toDouble() / 100;
    var totalFxLoss = 0.0;
    final netByCurrency = <String, double>{};
    for (final record in bondRecords.followedBy(equityRecords)) {
      final currency = normalizeCurrencyCode(record.currency);
      if (currency.isEmpty || currency == 'XOF') continue;
      final amount = math.max(0.0, record.valuationAmount).toDouble();
      if (amount <= 0) continue;
      netByCurrency.update(currency, (v) => v + amount, ifAbsent: () => amount);
    }
    for (final net in netByCurrency.values) {
      totalFxLoss += net * pct;
    }
    portfolioLoss += totalFxLoss;
    components['change'] = totalFxLoss;
    steps.add({
      'etape': 'Choc change ${shocks['fx_shock_percent']}%',
      'impact': totalFxLoss,
    });
  }

  if (shocks['equity_shock_percent'] is num) {
    final pct = (shocks['equity_shock_percent'] as num).toDouble() / 100;
    var totalEquityLoss = 0.0;
    for (final record in equityRecords) {
      final mv = math.max(0.0, record.marketValue).toDouble();
      if (mv <= 0) continue;
      totalEquityLoss += mv * pct;
    }
    portfolioLoss += totalEquityLoss;
    components['actions'] = totalEquityLoss;
    steps.add({
      'etape': 'Choc actions ${shocks['equity_shock_percent']}%',
      'impact': totalEquityLoss,
    });
  }

  if (shocks['credit_spread_bps'] is num) {
    final bps = (shocks['credit_spread_bps'] as num).toDouble();
    var totalSpreadLoss = 0.0;
    for (final record in bondRecords) {
      final mv = _bondMarketValue(record);
      final dur = _bondModifiedDuration(record);
      if (mv <= 0 || dur <= 0) continue;
      final loss = -dur * (bps / 10000) * mv;
      totalSpreadLoss += loss;
    }
    portfolioLoss += totalSpreadLoss;
    components['spread'] = totalSpreadLoss;
    steps.add({
      'etape': 'Choc spread ${bps}bps',
      'impact': totalSpreadLoss,
    });
  }

  final totalImpact = portfolioLoss;

  journal.add({
    'etape': template.name,
    'description': template.description,
    'impact': totalImpact,
  });

  return _ScenarioImpact(
    portfolioLoss: portfolioLoss,
    capitalLoss: baseCapital * (totalImpact / math.max(1, portfolioValue)),
    ratioImpact: (totalImpact / math.max(1, portfolioValue)) * baseCapitalRatio,
    totalImpact: totalImpact,
    components: components,
    steps: steps,
  );
}

double _totalPortfolioValue(List<MarketPortfolioRecord> records) {
  return records.fold<double>(0, (sum, r) {
    if (r.portfolioType == MarketPortfolioType.bonds) {
      return sum + _bondMarketValue(r);
    }
    return sum + math.max(0.0, r.marketValue).toDouble();
  });
}

double _bondMarketValue(MarketPortfolioRecord record) {
  if (_bondIsMaturedAtAnalysisDate(record)) return 0;
  if (record.presentValue > 0) return record.presentValue;
  return math.max(0.0, record.valuationAmount).toDouble();
}

double _bondModifiedDuration(MarketPortfolioRecord record) {
  final years = _bondRecordResidualYears(record);
  if (years <= 0) return 0;
  final frequency = math.max(1, record.couponPaymentsPerYear);
  final nominal = record.nominalUnit > 0 ? record.nominalUnit : 1;
  final redemption = nominal;
  final periods = math.max(1, (years * frequency).ceil());
  final annualYield = record.yieldToMaturity > 0
      ? _rateFraction(record.yieldToMaturity)
      : _rateFraction(record.coupon);
  if (annualYield <= 0) return 0;
  final periodicBase = 1 + annualYield / frequency;
  final couponCF = _rateFraction(record.coupon) * nominal / frequency;

  var macaulayNum = 0.0;
  var pv = 0.0;
  for (var p = 1; p <= periods; p++) {
    final t = math.min(p / frequency, years);
    final cf = couponCF + (p == periods ? redemption : 0);
    if (cf <= 0) continue;
    final d = math.pow(periodicBase, p);
    if (d <= 0) continue;
    final dcf = cf / d;
    pv += dcf;
    macaulayNum += t * dcf;
  }
  if (pv <= 0) return 0;
  final macaulay = macaulayNum / pv;
  return macaulay / periodicBase;
}

double _bondRecordResidualYears(MarketPortfolioRecord record) {
  final months = record.residualMaturityMonths;
  return months > 0 ? months / 12 : 0;
}

bool _bondIsMaturedAtAnalysisDate(MarketPortfolioRecord record) {
  final maturityDate = record.maturityDate;
  if (maturityDate == null) return false;
  return !DateTime(maturityDate.year, maturityDate.month, maturityDate.day)
      .isAfter(record.resolvedAnalysisDate);
}

double _rateFraction(double raw) {
  if (!raw.isFinite) return 0;
  return raw.abs() > 1 ? raw / 100 : raw;
}
