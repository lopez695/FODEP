import 'dart:math' as math;

class BacktestResult {
  final DateTime date;
  final double varForecast;
  final double actualPnl;
  final bool exception;
  final double confidence;
  final int horizonDays;

  const BacktestResult({
    required this.date,
    required this.varForecast,
    required this.actualPnl,
    required this.exception,
    required this.confidence,
    required this.horizonDays,
  });
}

class BacktestSummary {
  final int totalObservations;
  final int nbExceptions;
  final double exceptionRate;
  final double expectedExceptions;
  final double confidence;
  final BacktestZone zone;
  final String zoneLabel;
  final List<Map<String, dynamic>> calculationJournal;

  const BacktestSummary({
    required this.totalObservations,
    required this.nbExceptions,
    required this.exceptionRate,
    required this.expectedExceptions,
    required this.confidence,
    required this.zone,
    required this.zoneLabel,
    required this.calculationJournal,
  });
}

enum BacktestZone { green, yellow, red }

class ValidationEntry {
  final DateTime timestamp;
  final String validator;
  final String action;
  final String comment;
  final Map<String, dynamic> metadata;

  const ValidationEntry({
    required this.timestamp,
    required this.validator,
    required this.action,
    required this.comment,
    required this.metadata,
  });
}

class CalculationAuditEntry {
  final DateTime timestamp;
  final String service;
  final String operation;
  final Map<String, dynamic> inputSummary;
  final Map<String, dynamic> outputSummary;
  final String hash;
  final Duration executionTime;

  const CalculationAuditEntry({
    required this.timestamp,
    required this.service,
    required this.operation,
    required this.inputSummary,
    required this.outputSummary,
    required this.hash,
    required this.executionTime,
  });
}

class GovernanceReport {
  final BacktestSummary? lastBacktest;
  final List<BacktestResult> backtestHistory;
  final List<ValidationEntry> validations;
  final List<CalculationAuditEntry> auditTrail;
  final Map<String, dynamic> modelValidationStatus;
  final List<Map<String, dynamic>> calculationJournal;

  const GovernanceReport({
    this.lastBacktest,
    required this.backtestHistory,
    required this.validations,
    required this.auditTrail,
    required this.modelValidationStatus,
    required this.calculationJournal,
  });
}

class BacktestingService {
  final List<BacktestResult> _history = [];
  final List<ValidationEntry> _validations = [];
  final List<CalculationAuditEntry> _auditTrail = [];
  final Map<String, dynamic> _modelStatus = {
    'historical_var': {'validated': false, 'lastValidation': null},
    'parametric_var': {'validated': false, 'lastValidation': null},
    'monte_carlo_var': {'validated': false, 'lastValidation': null},
    'stress_testing': {'validated': false, 'lastValidation': null},
    'rate_risk': {'validated': false, 'lastValidation': null},
    'fx_risk': {'validated': false, 'lastValidation': null},
    'equity_risk': {'validated': false, 'lastValidation': null},
  };

  static final BacktestingService instance = BacktestingService._();
  BacktestingService._();

  BacktestSummary runBacktest({
    required List<double> varForecasts,
    required List<double> actualPnls,
    required double confidence,
    int horizonDays = 1,
  }) {
    final journal = <Map<String, dynamic>>[];
    final minLen = math.min(varForecasts.length, actualPnls.length);
    journal.add({
      'etape': 'Backtesting',
      'description': 'Comparaison VaR vs P&L réalisés sur $minLen observations',
      'confidence': confidence,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final results = <BacktestResult>[];
    var exceptions = 0;
    for (var i = 0; i < minLen; i++) {
      final isException = actualPnls[i] < -varForecasts[i];
      if (isException) exceptions++;
      results.add(BacktestResult(
        date: DateTime.now().subtract(Duration(days: minLen - i)),
        varForecast: varForecasts[i],
        actualPnl: actualPnls[i],
        exception: isException,
        confidence: confidence,
        horizonDays: horizonDays,
      ));
    }

    _history.addAll(results);

    final totalObs = results.length;
    final exceptionRate = totalObs > 0 ? exceptions / totalObs : 0.0;
    final expectedExceptions = (1 - confidence) * totalObs;

    BacktestZone zone;
    String zoneLabel;
    if (totalObs <= 250) {
      if (exceptions <= 4) {
        zone = BacktestZone.green;
        zoneLabel = 'Verte (Modèle valide)';
      } else if (exceptions <= 9) {
        zone = BacktestZone.yellow;
        zoneLabel = 'Orange (Surveillance renforcée)';
      } else {
        zone = BacktestZone.red;
        zoneLabel = 'Rouge (Modèle invalide)';
      }
    } else if (totalObs <= 500) {
      if (exceptions <= 6) {
        zone = BacktestZone.green;
        zoneLabel = 'Verte (Modèle valide)';
      } else if (exceptions <= 11) {
        zone = BacktestZone.yellow;
        zoneLabel = 'Orange (Surveillance renforcée)';
      } else {
        zone = BacktestZone.red;
        zoneLabel = 'Rouge (Modèle invalide)';
      }
    } else {
      if (exceptions <= 10) {
        zone = BacktestZone.green;
        zoneLabel = 'Verte (Modèle valide)';
      } else if (exceptions <= 20) {
        zone = BacktestZone.yellow;
        zoneLabel = 'Orange (Surveillance renforcée)';
      } else {
        zone = BacktestZone.red;
        zoneLabel = 'Rouge (Modèle invalide)';
      }
    }

    journal.add({
      'etape': 'Résultat backtest',
      'totalObservations': totalObs,
      'exceptions': exceptions,
      'exceptionRate': exceptionRate,
      'expectedExceptions': expectedExceptions,
      'zone': zoneLabel,
      'regle': 'Bâle II/III - zones de backtesting',
    });

    return BacktestSummary(
      totalObservations: totalObs,
      nbExceptions: exceptions,
      exceptionRate: exceptionRate,
      expectedExceptions: expectedExceptions,
      confidence: confidence,
      zone: zone,
      zoneLabel: zoneLabel,
      calculationJournal: journal,
    );
  }

  void addValidation({
    required String validator,
    required String action,
    required String comment,
    Map<String, dynamic>? metadata,
  }) {
    _validations.add(ValidationEntry(
      timestamp: DateTime.now(),
      validator: validator,
      action: action,
      comment: comment,
      metadata: metadata ?? {},
    ));
  }

  void validateModel(String modelName) {
    if (_modelStatus.containsKey(modelName)) {
      _modelStatus[modelName] = {
        'validated': true,
        'lastValidation': DateTime.now().toIso8601String(),
      };
    }
  }

  CalculationAuditEntry addAuditEntry({
    required String service,
    required String operation,
    required Map<String, dynamic> inputSummary,
    required Map<String, dynamic> outputSummary,
  }) {
    final entry = CalculationAuditEntry(
      timestamp: DateTime.now(),
      service: service,
      operation: operation,
      inputSummary: inputSummary,
      outputSummary: outputSummary,
      hash: _computeHash(inputSummary, outputSummary),
      executionTime: Duration.zero,
    );
    _auditTrail.add(entry);
    return entry;
  }

  GovernanceReport generateReport() {
    final journal = <Map<String, dynamic>>[];
    journal.add({
      'etape': 'Rapport de gouvernance',
      'timestamp': DateTime.now().toIso8601String(),
      'description': 'Synthèse des contrôles et validations',
    });

    return GovernanceReport(
      lastBacktest: _history.isEmpty
          ? null
          : BacktestSummary(
              totalObservations: _history.length,
              nbExceptions: _history.where((r) => r.exception).length,
              exceptionRate: _history.isEmpty
                  ? 0
                  : _history.where((r) => r.exception).length / _history.length,
              expectedExceptions: _history.isEmpty
                  ? 0
                  : (1 - (_history.first.confidence)) * _history.length,
              confidence: _history.isEmpty ? 0.99 : _history.first.confidence,
              zone: BacktestZone.green,
              zoneLabel: 'N/A',
              calculationJournal: [],
            ),
      backtestHistory: List.from(_history),
      validations: List.from(_validations),
      auditTrail: List.from(_auditTrail),
      modelValidationStatus: Map.from(_modelStatus),
      calculationJournal: journal,
    );
  }

  String _computeHash(Map<String, dynamic> input, Map<String, dynamic> output) {
    final combined = '$input|$output|${DateTime.now().millisecondsSinceEpoch}';
    var hash = 0;
    for (final codeUnit in combined.codeUnits) {
      hash = ((hash << 5) - hash) + codeUnit;
      hash &= hash;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
