import 'dart:math' as math;
import 'market_data_import_store.dart';

enum VarEngine { historical, parametric, monteCarlo }

class VarResult {
  final VarEngine engine;
  final double confidence;
  final int horizonDays;
  final double varValue;
  final double expectedShortfall;
  final double portfolioValue;
  final Map<String, dynamic> details;
  final List<Map<String, dynamic>> calculationJournal;

  const VarResult({
    required this.engine,
    required this.confidence,
    required this.horizonDays,
    required this.varValue,
    required this.expectedShortfall,
    required this.portfolioValue,
    required this.details,
    required this.calculationJournal,
  });
}

class HistoricalVarInput {
  final List<double> historicalReturns;
  final double portfolioValue;

  const HistoricalVarInput({
    required this.historicalReturns,
    required this.portfolioValue,
  });
}

class ParametricVarInput {
  final double portfolioValue;
  final double annualVolatility;
  final double modifiedDuration;
  final double expectedReturn;
  final double riskFreeRate;

  const ParametricVarInput({
    required this.portfolioValue,
    required this.annualVolatility,
    required this.modifiedDuration,
    required this.expectedReturn,
    required this.riskFreeRate,
  });
}

class MonteCarloVarInput {
  final double portfolioValue;
  final double annualVolatility;
  final double expectedReturn;
  final int numSimulations;
  final double modifiedDuration;
  final List<MarketPortfolioRecord> bondRecords;
  final List<MarketPortfolioRecord> equityRecords;

  const MonteCarloVarInput({
    required this.portfolioValue,
    required this.annualVolatility,
    required this.expectedReturn,
    this.numSimulations = 10000,
    this.modifiedDuration = 0,
    this.bondRecords = const [],
    this.equityRecords = const [],
  });
}

class VarEngineResult {
  final List<VarResult> results;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> calculationJournal;

  const VarEngineResult({
    required this.results,
    required this.summary,
    required this.calculationJournal,
  });
}

// ============ HISTORICAL VAR ============

VarEngineResult calculateHistoricalVar({
  required HistoricalVarInput input,
  List<double> confidences = const [0.95, 0.99],
  List<int> horizons = const [1, 10],
}) {
  final journal = <Map<String, dynamic>>[];
  journal.add({
    'etape': 'Initialisation',
    'description':
        'VaR Historique - ${input.historicalReturns.length} rendements historiques',
    'timestamp': DateTime.now().toIso8601String(),
    'formule': 'VaR_{hist}(α) = -percentile(R_{hist}, 1-α) × P',
    'formule_es': 'ES_α = -E[R | R ≤ -VaR_α] × P',
  });

  var hasData =
      input.historicalReturns.length >= 20 && input.portfolioValue > 0;
  final results = <VarResult>[];

  for (final conf in confidences) {
    for (final horizon in horizons) {
      final z = _normalQuantile(conf);
      final timeScale = math.sqrt(math.max(1, horizon));
      final varSteps = <Map<String, dynamic>>[];

      if (!hasData) {
        results.add(VarResult(
          engine: VarEngine.historical,
          confidence: conf,
          horizonDays: horizon,
          varValue: 0,
          expectedShortfall: 0,
          portfolioValue: input.portfolioValue,
          details: {'note': 'Données historiques insuffisantes'},
          calculationJournal: journal,
        ));
        continue;
      }

      final allReturns = List<double>.from(input.historicalReturns)..sort();
      final varIndex = ((1 - conf) * allReturns.length).ceil() - 1;
      final boundedIndex = varIndex.clamp(0, allReturns.length - 1);
      final historicalVar =
          -allReturns[boundedIndex] * input.portfolioValue * timeScale;

      varSteps.add({
        'etape': 'Tri des rendements',
        'rendements_tries': allReturns.take(5).toList(),
        'index_percentile': boundedIndex,
        'rendement_seuil': allReturns[boundedIndex],
      });

      final esReturns =
          allReturns.where((r) => r <= allReturns[boundedIndex]).toList();
      var es = 0.0;
      if (esReturns.isNotEmpty) {
        es = -(esReturns.reduce((a, b) => a + b) / esReturns.length) *
            input.portfolioValue *
            timeScale;
      }

      varSteps.add({
        'etape': 'Expected Shortfall',
        'nb_observations': esReturns.length,
        'moyenne_extreme': esReturns.isEmpty
            ? 0
            : esReturns.reduce((a, b) => a + b) / esReturns.length,
        'formule_es': 'ES($conf) = -moyenne(R ≤ -VaR) × P × √T',
      });

      journal.add({
        'etape': 'Résultat Histo $conf ${horizon}j',
        'confidence': conf,
        'horizon': horizon,
        'zScore': z,
        'varValue': historicalVar,
        'expectedShortfall': es,
        'nbObservations': allReturns.length,
        'timeScale': timeScale,
      });

      results.add(VarResult(
        engine: VarEngine.historical,
        confidence: conf,
        horizonDays: horizon,
        varValue: historicalVar,
        expectedShortfall: es,
        portfolioValue: input.portfolioValue,
        details: {
          'observations': allReturns.length,
          'sorted_returns_sample': allReturns.take(10).toList(),
          'percentile_index': boundedIndex,
          'threshold_return': allReturns[boundedIndex],
          'es_observations': esReturns.length,
          'es_mean_return': esReturns.isEmpty
              ? 0
              : esReturns.reduce((a, b) => a + b) / esReturns.length,
          'time_scale': timeScale,
          'z_score': z,
          'formule_var': 'VaR_{hist}(α) = -percentile(R, 1-α) × P × √T',
          'formule_es': 'ES(α) = -E[R | R ≤ q_{1-α}] × P × √T',
        },
        calculationJournal: journal,
      ));
    }
  }

  return VarEngineResult(
    results: results,
    summary: _buildSummary(results),
    calculationJournal: journal,
  );
}

// ============ PARAMETRIC VAR ============

VarEngineResult calculateParametricVar({
  required ParametricVarInput input,
  List<double> confidences = const [0.95, 0.99],
  List<int> horizons = const [1, 10],
}) {
  final journal = <Map<String, dynamic>>[];
  journal.add({
    'etape': 'Initialisation',
    'description': 'VaR Paramétrique (Variance-Covariance)',
    'timestamp': DateTime.now().toIso8601String(),
    'formule': 'VaR_{param}(α) = Z_α × σ × P × √T',
    'formule_es': 'ES(α) = φ(Z_α) / (1-α) × σ × P × √T',
  });

  final hasData = input.portfolioValue > 0 && input.annualVolatility > 0;
  final results = <VarResult>[];

  for (final conf in confidences) {
    for (final horizon in horizons) {
      final z = _normalQuantile(conf);
      final timeScale = math.sqrt(math.max(1, horizon));
      final dailyVol = _normalizedVol(input.annualVolatility) / math.sqrt(252);
      final sensMultiple = math.max(
          1.0, input.modifiedDuration > 0 ? input.modifiedDuration : 1.0);
      final lossStdDev =
          dailyVol * sensMultiple * input.portfolioValue * timeScale;

      if (!hasData) {
        results.add(VarResult(
          engine: VarEngine.parametric,
          confidence: conf,
          horizonDays: horizon,
          varValue: 0,
          expectedShortfall: 0,
          portfolioValue: input.portfolioValue,
          details: {'note': 'Données insuffisantes'},
          calculationJournal: journal,
        ));
        continue;
      }

      final varValue = math.max(0.0, z * lossStdDev);
      final es = _normalPdf(z) / math.max(0.0001, 1.0 - conf) * lossStdDev;

      journal.add({
        'etape': 'Résultat Param $conf ${horizon}j',
        'zScore': z,
        'dailyVol': dailyVol,
        'lossStdDev': lossStdDev,
        'varValue': varValue,
        'expectedShortfall': es,
        'timeScale': timeScale,
      });

      results.add(VarResult(
        engine: VarEngine.parametric,
        confidence: conf,
        horizonDays: horizon,
        varValue: varValue,
        expectedShortfall: es,
        portfolioValue: input.portfolioValue,
        details: {
          'z_score': z,
          'daily_volatility': dailyVol,
          'annual_volatility': _normalizedVol(input.annualVolatility),
          'loss_std_dev': lossStdDev,
          'time_scale': timeScale,
          'sensitivity_multiplier': sensMultiple,
          'formule_var': 'VaR(α) = Z_α × σ_j × S × P × √T',
          'formule_es': 'ES(α) = φ(Z_α) / (1-α) × σ_j × P × √T',
          'formule_z': 'Z_95 = 1.645, Z_99 = 2.326',
        },
        calculationJournal: journal,
      ));
    }
  }

  return VarEngineResult(
    results: results,
    summary: _buildSummary(results),
    calculationJournal: journal,
  );
}

// ============ MONTE CARLO VAR ============

VarEngineResult calculateMonteCarloVar({
  required MonteCarloVarInput input,
  List<double> confidences = const [0.95, 0.99],
  List<int> horizons = const [1, 10],
}) {
  final journal = <Map<String, dynamic>>[];
  journal.add({
    'etape': 'Initialisation',
    'description': 'VaR Monte-Carlo - ${input.numSimulations} simulations',
    'timestamp': DateTime.now().toIso8601String(),
    'formule':
        'Simulation de GBM: S_t = S_0 × exp((μ - σ²/2) × Δt + σ × √Δt × ε)',
  });

  final hasData = input.portfolioValue > 0 &&
      input.annualVolatility > 0 &&
      input.numSimulations > 0;
  final rng = math.Random(42);
  final results = <VarResult>[];

  for (final conf in confidences) {
    for (final horizon in horizons) {
      if (!hasData) {
        results.add(VarResult(
          engine: VarEngine.monteCarlo,
          confidence: conf,
          horizonDays: horizon,
          varValue: 0,
          expectedShortfall: 0,
          portfolioValue: input.portfolioValue,
          details: {'note': 'Données insuffisantes'},
          calculationJournal: journal,
        ));
        continue;
      }

      final vol = _normalizedVol(input.annualVolatility);
      final mu = _rateToDecimal(input.expectedReturn);
      final dt = math.max(1, horizon) / 252.0;
      final drift = (mu - 0.5 * vol * vol) * dt;
      const riskFactors = 3;

      final scenarios = List<double>.generate(input.numSimulations, (_) {
        var totalReturn = 0.0;
        for (var f = 0; f < riskFactors; f++) {
          final eps = _boxMuller(rng);
          totalReturn += drift + vol * math.sqrt(dt) * eps;
        }
        return totalReturn / riskFactors;
      })
        ..sort();

      final varIndex = ((1 - conf) * scenarios.length).ceil() - 1;
      final boundedIndex = varIndex.clamp(0, scenarios.length - 1);
      final scenarioLosses =
          scenarios.map((r) => -r * input.portfolioValue).toList()..sort();
      final mcVar = math.max(0.0, scenarioLosses[boundedIndex]);

      final esScenarios = scenarioLosses
          .where((l) => l >= scenarioLosses[boundedIndex])
          .toList();
      final mcEs = esScenarios.isEmpty
          ? 0.0
          : esScenarios.reduce((a, b) => a + b) / esScenarios.length;

      journal.add({
        'etape': 'Résultat MC $conf ${horizon}j',
        'simulations': input.numSimulations,
        'drift': drift,
        'volatility': vol,
        'dt': dt,
        'varValue': mcVar,
        'expectedShortfall': mcEs,
        'nbLossScenarios': esScenarios.length,
      });

      results.add(VarResult(
        engine: VarEngine.monteCarlo,
        confidence: conf,
        horizonDays: horizon,
        varValue: mcVar,
        expectedShortfall: mcEs,
        portfolioValue: input.portfolioValue,
        details: {
          'num_simulations': input.numSimulations,
          'risk_factors': riskFactors,
          'drift': drift,
          'volatility': vol,
          'dt': dt,
          'seed': 42,
          'var_index': boundedIndex,
          'es_count': esScenarios.length,
          'formule': 'GBM: S_t = S_0 × exp((μ - σ²/2)Δt + σ√Δt × ε)',
          'distribution': 'Normale (Box-Muller)',
        },
        calculationJournal: journal,
      ));
    }
  }

  return VarEngineResult(
    results: results,
    summary: _buildSummary(results),
    calculationJournal: journal,
  );
}

// ============ COMPARATIVE VAR ============

class VarComparisonResult {
  final VarResult historical;
  final VarResult parametric;
  final VarResult monteCarlo;
  final Map<String, dynamic> comparison;
  final List<Map<String, dynamic>> calculationJournal;

  const VarComparisonResult({
    required this.historical,
    required this.parametric,
    required this.monteCarlo,
    required this.comparison,
    required this.calculationJournal,
  });
}

VarComparisonResult compareVarMethods({
  required HistoricalVarInput historicalInput,
  required ParametricVarInput parametricInput,
  required MonteCarloVarInput monteCarloInput,
  double confidence = 0.99,
  int horizonDays = 1,
}) {
  final histResult = calculateHistoricalVar(
    input: historicalInput,
    confidences: [confidence],
    horizons: [horizonDays],
  );
  final paramResult = calculateParametricVar(
    input: parametricInput,
    confidences: [confidence],
    horizons: [horizonDays],
  );
  final mcResult = calculateMonteCarloVar(
    input: monteCarloInput,
    confidences: [confidence],
    horizons: [horizonDays],
  );

  final histVar = histResult.results.firstOrNull;
  final paramVar = paramResult.results.firstOrNull;
  final mcVar = mcResult.results.firstOrNull;

  final comparison = <String, dynamic>{
    'confidence': confidence,
    'horizon_days': horizonDays,
    'historical_var': histVar?.varValue ?? 0,
    'parametric_var': paramVar?.varValue ?? 0,
    'monte_carlo_var': mcVar?.varValue ?? 0,
    'historical_es': histVar?.expectedShortfall ?? 0,
    'parametric_es': paramVar?.expectedShortfall ?? 0,
    'monte_carlo_es': mcVar?.expectedShortfall ?? 0,
    'note': 'La VaR historique est la référence réglementaire Bâle II/III. '
        'La VaR paramétrique surestime en distributions non-normales. '
        'Monte-Carlo capture les non-linéarités (options, convexité).',
  };

  return VarComparisonResult(
    historical: histVar ??
        VarResult(
          engine: VarEngine.historical,
          confidence: confidence,
          horizonDays: horizonDays,
          varValue: 0,
          expectedShortfall: 0,
          portfolioValue: monteCarloInput.portfolioValue,
          details: {},
          calculationJournal: [],
        ),
    parametric: paramVar ??
        VarResult(
          engine: VarEngine.parametric,
          confidence: confidence,
          horizonDays: horizonDays,
          varValue: 0,
          expectedShortfall: 0,
          portfolioValue: parametricInput.portfolioValue,
          details: {},
          calculationJournal: [],
        ),
    monteCarlo: mcVar ??
        VarResult(
          engine: VarEngine.monteCarlo,
          confidence: confidence,
          horizonDays: horizonDays,
          varValue: 0,
          expectedShortfall: 0,
          portfolioValue: monteCarloInput.portfolioValue,
          details: {},
          calculationJournal: [],
        ),
    comparison: comparison,
    calculationJournal: [
      ...histResult.calculationJournal,
      ...paramResult.calculationJournal,
      ...mcResult.calculationJournal,
    ],
  );
}

// ============ UTILITY FUNCTIONS ============

Map<String, dynamic> _buildSummary(List<VarResult> results) {
  final byConf = <double, List<VarResult>>{};
  for (final r in results) {
    byConf.putIfAbsent(r.confidence, () => []).add(r);
  }
  final summary = <String, dynamic>{};
  for (final entry in byConf.entries) {
    summary['conf_${(entry.key * 100).toInt()}'] = {
      for (final r in entry.value) '${r.horizonDays}j': r.varValue,
    };
  }
  return summary;
}

double _normalQuantile(double confidence) {
  if (confidence >= 0.989) return 2.3263;
  if (confidence >= 0.974) return 1.96;
  return 1.6449;
}

double _normalPdf(double value) {
  return math.exp(-0.5 * value * value) / math.sqrt(2 * math.pi);
}

double _normalizedVol(double value) {
  final resolved = _rateToDecimal(value).abs();
  if (!resolved.isFinite || resolved == 0) return 0.000001;
  return resolved.clamp(0.000001, 5.0);
}

double _rateToDecimal(double value) {
  if (!value.isFinite) return 0;
  return value.abs() > 1 ? value / 100 : value;
}

double _boxMuller(math.Random rng) {
  final u1 = rng.nextDouble();
  final u2 = rng.nextDouble();
  return math.sqrt(-2 * math.log(u1 + 1e-10)) * math.cos(2 * math.pi * u2);
}
