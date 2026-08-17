// Service d'analyse des donnees RWA et des regles prudentielles.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../crm/models/crm_models.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../expositions/models/exposition_models.dart';
import '../models/analyse_models.dart';

class AnalyseService {
  const AnalyseService(this.api);

  final RwaApiService api;

  Future<AnalyseData> fetchAnalyseData() async {
    final dashboard = await api.fetchDashboard();
    final exposures = await api.fetchExpositionsModule();
    final crm = await api.fetchCrmModule();
    final regulatoryReport = _runRegulatoryEngine(
      dashboard: dashboard,
      exposures: exposures,
      crm: crm,
    );

    final qualityScore = _calculatePortfolioQuality(
      dashboard.ratingDistribution,
      exposures.exposures.length,
    );
    final concentrationLevel = _calculateConcentration(
      dashboard.rwaCategoryDistribution,
      dashboard.countryDistribution,
    );
    final crmCoverage = crm.summary.averageCoverage;
    final reductionPotential = _calculateRwaReductionPotential(crm.summary);
    final sectorDistribution = dashboard.rwaCategoryDistribution;
    final ratingDistribution = dashboard.ratingDistribution;
    final rwaEvolution = _generateRwaEvolution(dashboard.rwaProjection);
    final rwaVariation = rwaEvolution.length >= 2
        ? _safeRatio(
            rwaEvolution.last.value - rwaEvolution.first.value,
            rwaEvolution.first.value,
          )
        : 0.0;
    final capitalMetric = dashboard.metrics.firstWhere(
      (m) => m.key == 'capital',
      orElse: () => const DashboardMetric(
        key: 'capital',
        label: 'Capital',
        value: 0,
        variation: '0%',
        trend: [],
      ),
    );
    final lowRatedExposure = _calculateLowRatedExposure(ratingDistribution);
    final topRiskExposures = _identifyTopRiskExposures(
      dashboard.portfolioOverview,
    );

    return AnalyseData(
      regulatoryReport: regulatoryReport,
      portfolioQualityScore: qualityScore,
      qualityTrend: 'stable',
      concentrationLevel: concentrationLevel,
      concentrationTrend: concentrationLevel > 0.30 ? 'up' : 'stable',
      crmCoverageRatio: crmCoverage,
      crmTrend: crmCoverage >= 0.50 ? 'up' : 'stable',
      rwaReductionPotential: reductionPotential,
      sectorDistribution: sectorDistribution,
      sectorInsights: _generateSectorInsights(sectorDistribution),
      ratingDistribution: ratingDistribution,
      ratingInsights: _generateRatingInsights(ratingDistribution),
      topConcentration: _findTopConcentration(sectorDistribution),
      lowRatedExposure: lowRatedExposure,
      weightedAverageRating: _calculateWeightedAverageRating(
        ratingDistribution,
      ),
      rwaEvolution: rwaEvolution,
      rwaVariation: rwaVariation,
      currentCapital: capitalMetric.value,
      prudentialAlerts: _generatePrudentialAlerts(
        dashboard,
        regulatoryReport,
        concentrationLevel,
        lowRatedExposure,
      ),
      topRiskExposures: topRiskExposures,
      recommendations: _generateRecommendations(
        concentrationLevel,
        lowRatedExposure,
        crmCoverage,
        reductionPotential,
        topRiskExposures,
        regulatoryReport,
      ),
    );
  }

  RegulatoryAnalysisReport _runRegulatoryEngine({
    required DashboardSnapshot dashboard,
    required ExposureModuleData exposures,
    required CrmModuleData crm,
  }) {
    const zone = RegulatoryZone.uemoa;
    final thresholds = _thresholdsFor(zone);
    final now = DateTime.now();
    // RWA réels calculés par le backend - mêmes métriques que le tableau de
    // bord (rwa_credit / rwa_market / rwa_op / rwa). Plus aucune estimation :
    // ce module affichait auparavant un RWA marché forfaitaire (5 % du
    // crédit) et un RWA opérationnel heuristique, en contradiction avec les
    // valeurs affichées partout ailleurs dans l'application.
    final creditRwa =
        _metricValue(dashboard, 'rwa_credit', fallback: _totalRwa(dashboard));
    final marketRwa = _metricValue(dashboard, 'rwa_market');
    final operationalRwa = _metricValue(dashboard, 'rwa_op');
    final allRwa = _metricValue(
      dashboard,
      'rwa',
      fallback: creditRwa + marketRwa + operationalRwa,
    );
    final requiredCapital = allRwa * thresholds.fpeTarget;
    final economicCapital = allRwa * (thresholds.fpeTarget + 0.015);
    // Fonds propres réels (panneau « Fonds propres réglementaires ») ; à
    // défaut, reconstruction depuis les ratios réels du tableau de bord -
    // jamais de coefficients inventés (l'ancien moteur posait
    // FPE = capital × 1,32, Tier 1 = 91 % et CET1 = 84 % des FPE).
    final fp = dashboard.fondsPropres;
    final fpe = (fp?.totalFp ?? 0) > 0
        ? fp!.totalFp
        : _metricValue(dashboard, 'solvabilite') * allRwa;
    final tier1 = (fp?.tier1 ?? 0) > 0
        ? fp!.tier1
        : _metricValue(dashboard, 'tier1_ratio') * allRwa;
    final cet1 = (fp?.cet1 ?? 0) > 0
        ? fp!.cet1
        : _metricValue(dashboard, 'cet1_ratio') * allRwa;
    final cet1Ratio = _safeRatio(cet1, allRwa);
    final tier1Ratio = _safeRatio(tier1, allRwa);
    final fpeRatio = _safeRatio(fpe, allRwa);
    final conservation = _conservationRequirement(cet1Ratio, thresholds);
    // Chocs de stress standard appliqués au ratio de solvabilité RÉEL
    // (hypothèses de scénario : -220 pb macro, -380 pb idiosyncratique,
    // -520 pb combiné).
    final stressMacro = fpeRatio - 0.022;
    final stressIdiosyncratic = fpeRatio - 0.038;
    final stressCombined = fpeRatio - 0.052;
    // Grands risques : mêmes règles que le tableau de bord (exposition
    // nette rapportée aux fonds propres effectifs, souverains exclus,
    // seuil 10 % - liste déjà établie par le backend), et non plus une
    // approximation en RWA rapportés au Tier 1.
    final largeRisks = dashboard.grandsRisques;
    final largestExposure = largeRisks.isEmpty
        ? null
        : largeRisks.reduce((a, b) => a.fpRatio >= b.fpRatio ? a : b);
    final largeRiskRatio = (largestExposure?.fpRatio ?? 0) / 100;
    final topSector = _topDistribution(dashboard.rwaCategoryDistribution);
    final operationalShare = _safeRatio(operationalRwa, allRwa);
    final capitalGap = fpe - requiredCapital;
    final irrbbRatio = _estimateIrrbbShockRatio(dashboard);

    final diagnostics = <RegulatoryDiagnostic>[
      _ratioDiagnostic(
        ruleReference: 'Art. 91 / 103 (UEMOA)',
        label: 'CET1',
        currentRatio: cet1Ratio,
        threshold: thresholds.cet1Target,
      ),
      _ratioDiagnostic(
        ruleReference: 'Art. 91 / 103 (UEMOA)',
        label: 'Tier 1',
        currentRatio: tier1Ratio,
        threshold: thresholds.tier1Target,
      ),
      _ratioDiagnostic(
        ruleReference: 'Art. 103 (UEMOA)',
        label: 'solvabilite FPE',
        currentRatio: fpeRatio,
        threshold: thresholds.fpeTarget,
      ),
      RegulatoryDiagnostic(
        ruleReference: 'Tableau 1 Art. 96 (UEMOA)',
        threshold: conservation.minimumRetention,
        currentValue: conservation.distributableRatio,
        gap: conservation.distributableRatio - conservation.minimumRetention,
        message:
            'Votre ratio CET1 est de ${_pct(cet1Ratio)}. Vous etes dans la tranche ${conservation.bandLabel}; conservation minimale: ${_pct(conservation.minimumRetention)} des benefices distribuables.',
        severity: conservation.minimumRetention >= 1
            ? 'CRITICAL'
            : conservation.minimumRetention >= 0.8
                ? 'HIGH'
                : 'MEDIUM',
      ),
      _ratioDiagnostic(
        ruleReference: 'Art. 544-545 (UEMOA)',
        label: 'solvabilite post-stress macro',
        currentRatio: stressMacro,
        threshold: thresholds.fpeMinimum,
      ),
      _ratioDiagnostic(
        ruleReference: 'Art. 544-545 (UEMOA)',
        label: 'solvabilite post-stress idiosyncratique',
        currentRatio: stressIdiosyncratic,
        threshold: thresholds.fpeMinimum,
      ),
      _ratioDiagnostic(
        ruleReference: 'Art. 544-545 (UEMOA)',
        label: 'solvabilite post-stress combine',
        currentRatio: stressCombined,
        threshold: thresholds.fpeMinimum,
      ),
      _ratioDiagnostic(
        ruleReference: 'Art. 451 (UEMOA)',
        label: largestExposure?.counterparty ?? 'plus grande exposition',
        currentRatio: largeRiskRatio,
        threshold: thresholds.largeRiskLimit,
        higherIsBad: true,
      ),
      RegulatoryDiagnostic(
        ruleReference: 'Art. 538 (UEMOA)',
        threshold: 0.15,
        currentValue: irrbbRatio,
        gap: 0.15 - irrbbRatio,
        message:
            'Un choc de taux de +200 bps entrainerait une baisse estimee de valeur economique egale a ${_pct(irrbbRatio)} du Tier 1.',
        severity: irrbbRatio > 0.15 ? 'HIGH' : 'LOW',
      ),
    ];

    final rootCauses = <String>[
      if (topSector != null)
        'Hausse et concentration des RWA de credit sur ${topSector.label} (${_pct(topSector.percentage)} du RWA credit).',
      'Le risque de credit represente ${_pct(_safeRatio(creditRwa, allRwa))} des RWA totaux.',
      if (operationalShare > 0.09)
        'Le risque operationnel pese ${_pct(operationalShare)}, au-dessus du repere de gestion de 9%.',
      if (dashboard.rwaProjection.length >= 2)
        'La projection RWA montre une variation de ${_pct(_safeRatio(dashboard.rwaProjection.last.value - dashboard.rwaProjection.first.value, dashboard.rwaProjection.first.value))}.',
      if (largeRisks.isNotEmpty)
        '${largeRisks.length} contrepartie(s) depassent le seuil de grand risque de 10% des fonds propres effectifs.',
    ];

    final actions = <RegulatoryAction>[
      if (capitalGap < 0)
        RegulatoryAction(
          action:
              'Augmenter les FPE de ${formatCurrencyCompact(capitalGap.abs())} ou reduire les RWA de ${formatCurrencyCompact(capitalGap.abs() / thresholds.fpeTarget)}.',
          deadline: DateTime(now.year, now.month + 6, now.day),
          priority: 1,
        )
      else
        RegulatoryAction(
          action:
              'Preserver la marge de capital de ${formatCurrencyCompact(capitalGap)} avant toute distribution exceptionnelle.',
          deadline: DateTime(now.year, now.month + 3, now.day),
          priority: 2,
        ),
      RegulatoryAction(
        action:
            'Limiter la croissance du secteur ${topSector?.label ?? 'dominant'} et revoir les limites internes de concentration.',
        deadline: DateTime(now.year, now.month + 12, now.day),
        priority: largeRisks.isEmpty ? 3 : 1,
      ),
      RegulatoryAction(
        action:
            'Conserver ${_pct(conservation.minimumRetention)} des benefices distribuables; distribution maximale estimee: ${_pct(1 - conservation.minimumRetention)}.',
        deadline: DateTime(now.year, now.month + 1, now.day),
        priority: conservation.minimumRetention >= 0.8 ? 1 : 2,
      ),
      RegulatoryAction(
        action:
            'Tester un plan de resistance: macro ${_pct(stressMacro)}, idiosyncratique ${_pct(stressIdiosyncratic)}, combine ${_pct(stressCombined)}.',
        deadline: DateTime(now.year, now.month + 2, now.day),
        priority: stressCombined < thresholds.fpeMinimum ? 1 : 3,
      ),
    ];

    final cards = <RegulatoryAnalysisCard>[
      RegulatoryAnalysisCard(
        title: 'Adequation des fonds propres',
        ruleReference: 'Art. 91 / 103',
        status: _statusFromGap(fpeRatio - thresholds.fpeTarget),
        keyValue: _pct(fpeRatio),
        keyLabel: 'Ratio FPE',
        diagnostic:
            'Votre ratio FPE est de ${_pct(fpeRatio)} pour une cible UEMOA de ${_pct(thresholds.fpeTarget)}.',
        cause: rootCauses.first,
        recommendation: actions.first.action,
        icon: Icons.account_balance_rounded,
      ),
      RegulatoryAnalysisCard(
        title: 'Coussin de conservation',
        ruleReference: 'Art. 96',
        status: conservation.minimumRetention >= 0.8
            ? RegulatoryStatus.warning
            : RegulatoryStatus.green,
        keyValue: _pct(conservation.minimumRetention),
        keyLabel: 'Benefices a conserver',
        diagnostic:
            'Le CET1 de ${_pct(cet1Ratio)} positionne la banque dans la tranche ${conservation.bandLabel}.',
        cause:
            'Une distribution trop elevee reduirait le CET1 et durcirait les restrictions.',
        recommendation:
            'Limiter la distribution a ${_pct(1 - conservation.minimumRetention)} des benefices distribuables.',
        icon: Icons.shield_rounded,
      ),
      RegulatoryAnalysisCard(
        title: 'Stress-test',
        ruleReference: 'Art. 544-545',
        status: _statusFromGap(stressCombined - thresholds.fpeMinimum),
        keyValue: _pct(stressCombined),
        keyLabel: 'FPE stress combine',
        diagnostic:
            'Sous scenario combine, le ratio tomberait a ${_pct(stressCombined)}.',
        cause:
            'La sensibilite vient surtout des poches de credit concentrees et des RWA operationnels.',
        recommendation:
            'Construire un coussin additionnel de ${formatCurrencyCompact(math.max(0, thresholds.fpeTarget * allRwa - stressCombined * allRwa))}.',
        icon: Icons.thunderstorm_rounded,
      ),
      RegulatoryAnalysisCard(
        title: 'Grands risques',
        ruleReference: 'Art. 451',
        status: largeRiskRatio > thresholds.largeRiskLimit
            ? RegulatoryStatus.critical
            : largeRisks.isNotEmpty
                ? RegulatoryStatus.warning
                : RegulatoryStatus.green,
        keyValue: _pct(largeRiskRatio),
        keyLabel: largestExposure?.counterparty ?? 'Top client',
        diagnostic:
            '${largestExposure?.counterparty ?? 'La premiere contrepartie'} represente ${_pct(largeRiskRatio)} des fonds propres effectifs.',
        cause:
            '${largeRisks.length} contrepartie(s) atteignent au moins 10% des fonds propres effectifs.',
        recommendation:
            'Ramener la premiere exposition vers 15% du T1 sur 12 mois.',
        icon: Icons.center_focus_strong_rounded,
      ),
      RegulatoryAnalysisCard(
        title: 'IRRBB',
        ruleReference: 'Art. 538',
        status: irrbbRatio > 0.15
            ? RegulatoryStatus.warning
            : RegulatoryStatus.green,
        keyValue: _pct(irrbbRatio),
        keyLabel: 'Delta VE / T1',
        diagnostic: 'Le choc +200 bps est estime a ${_pct(irrbbRatio)} du T1.',
        cause:
            'Le proxy retient la part des expositions longues et la concentration credit.',
        recommendation:
            'Tester des swaps de taux ou augmenter la part des credits a taux variable.',
        icon: Icons.show_chart_rounded,
      ),
      RegulatoryAnalysisCard(
        title: 'Composition des RWA',
        ruleReference: 'Capital management',
        status: operationalShare > 0.10
            ? RegulatoryStatus.warning
            : RegulatoryStatus.green,
        keyValue: _pct(_safeRatio(creditRwa, allRwa)),
        keyLabel: 'Poids credit',
        diagnostic:
            'Credit ${_pct(_safeRatio(creditRwa, allRwa))}, marche ${_pct(_safeRatio(marketRwa, allRwa))}, operationnel ${_pct(operationalShare)}.',
        cause:
            'Le portefeuille reste pilote par le credit, avec un besoin de lecture capital par segment.',
        recommendation:
            'Prioriser les segments consommant le plus de RWA par unite de revenu.',
        icon: Icons.donut_small_rounded,
      ),
      RegulatoryAnalysisCard(
        title: 'Plan de capital',
        ruleReference: 'Art. 522-525',
        status: capitalGap < 0
            ? RegulatoryStatus.critical
            : capitalGap < requiredCapital * 0.09
                ? RegulatoryStatus.warning
                : RegulatoryStatus.green,
        keyValue: formatCurrencyCompact(capitalGap),
        keyLabel: 'Gap capital',
        diagnostic:
            'Capital disponible ${formatCurrencyCompact(fpe)} vs capital requis ${formatCurrencyCompact(requiredCapital)}.',
        cause:
            'La croissance projetee des RWA absorbe la generation interne de capital.',
        recommendation: actions.first.action,
        icon: Icons.fact_check_rounded,
      ),
    ];

    final alertTimeline = <RegulatoryAlertEvent>[
      for (var index = 0; index < cards.length; index++)
        if (cards[index].status != RegulatoryStatus.green)
          RegulatoryAlertEvent(
            date: now.subtract(Duration(days: index * 2)),
            title: cards[index].title,
            detail: cards[index].diagnostic,
            status: cards[index].status,
          ),
    ];

    final status = diagnostics.any((item) => item.severity == 'CRITICAL')
        ? RegulatoryStatus.critical
        : diagnostics.any(
            (item) => item.severity == 'HIGH' || item.severity == 'MEDIUM',
          )
            ? RegulatoryStatus.warning
            : RegulatoryStatus.green;

    return RegulatoryAnalysisReport(
      analysisId:
          'ANALYSE_REGLEMENTAIRE_${now.year}_Q${((now.month - 1) ~/ 3) + 1}',
      timestamp: now,
      regulatoryZone: zone,
      status: status,
      availableCapital: fpe,
      requiredCapital: requiredCapital,
      economicCapital: economicCapital,
      diagnostics: diagnostics,
      rootCauses: rootCauses,
      recommendations: actions,
      analysisCards: cards,
      alertTimeline: alertTimeline,
      consultantNarrative: _buildNarrative(
        fpeRatio: fpeRatio,
        thresholds: thresholds,
        capitalGap: capitalGap,
        topSector: topSector,
        largeRisks: largeRisks.length,
        conservation: conservation,
        exposureCount: exposures.exposures.length,
      ),
    );
  }

  double _calculatePortfolioQuality(
    List<DistributionEntry> ratings,
    int exposureCount,
  ) {
    if (ratings.isEmpty || exposureCount == 0) return 5.0;
    var score = 0.0;
    var totalWeight = 0.0;
    for (final entry in ratings) {
      final weight = entry.percentage;
      score += _ratingToScore(entry.label) * weight;
      totalWeight += weight;
    }
    return totalWeight > 0 ? score / totalWeight : 5.0;
  }

  double _ratingToScore(String rating) {
    final r = rating.toUpperCase();
    if (r.startsWith('AAA')) return 10.0;
    if (r.startsWith('AA')) return 9.0;
    if (r.startsWith('A')) return 7.5;
    if (r.startsWith('BBB')) return 6.0;
    if (r.startsWith('BB')) return 4.5;
    if (r.startsWith('B')) return 3.0;
    return 2.0;
  }

  double _calculateConcentration(
    List<DistributionEntry> categories,
    List<DistributionEntry> countries,
  ) {
    var hhi = 0.0;
    for (final entry in categories) {
      hhi += entry.percentage * entry.percentage;
    }
    for (final entry in countries) {
      hhi += entry.percentage * entry.percentage;
    }
    return (hhi / 2).clamp(0.0, 1.0).toDouble();
  }

  double _calculateRwaReductionPotential(CrmSummary crmSummary) {
    final observedSaving = crmSummary.totalRwaBefore - crmSummary.totalRwaAfter;
    return math.max(observedSaving, crmSummary.totalRwaAfter * 0.12);
  }

  List<String> _generateSectorInsights(List<DistributionEntry> distribution) {
    if (distribution.isEmpty) return const [];
    final sorted = List<DistributionEntry>.from(distribution)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
    final insights = <String>[];
    if (sorted.first.percentage > 0.4) {
      insights.add(
        'Forte concentration sur ${sorted.first.label} (${_pct(sorted.first.percentage)})',
      );
    }
    if (sorted.length >= 3) {
      final top3 =
          sorted.take(3).fold<double>(0.0, (sum, e) => sum + e.percentage);
      if (top3 > 0.7) {
        insights
            .add('Les 3 premiers segments representent ${_pct(top3)} du RWA.');
      }
    }
    return insights;
  }

  List<String> _generateRatingInsights(List<DistributionEntry> distribution) {
    if (distribution.isEmpty) return const [];
    final investmentGrade = distribution.where((e) {
      final r = e.label.toUpperCase();
      return r.startsWith('AAA') ||
          r.startsWith('AA') ||
          r.startsWith('A') ||
          r.startsWith('BBB');
    }).fold<double>(0.0, (sum, e) => sum + e.percentage);
    if (investmentGrade > 0.7) {
      return [
        'Portefeuille de qualite: ${_pct(investmentGrade)} investment grade.'
      ];
    }
    if (investmentGrade < 0.4) {
      return [
        'Attention: seulement ${_pct(investmentGrade)} investment grade.'
      ];
    }
    return [
      'Qualite de signature equilibree: ${_pct(investmentGrade)} investment grade.'
    ];
  }

  DistributionEntry? _findTopConcentration(
      List<DistributionEntry> distribution) {
    if (distribution.isEmpty) return null;
    final sorted = List<DistributionEntry>.from(distribution)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
    return sorted.first.percentage > 0.25 ? sorted.first : null;
  }

  double _calculateLowRatedExposure(List<DistributionEntry> distribution) {
    return distribution.where((e) {
      final r = e.label.toUpperCase();
      return r.startsWith('BB') || r.startsWith('B') || r.contains('NON');
    }).fold<double>(0.0, (sum, e) => sum + e.percentage);
  }

  String? _calculateWeightedAverageRating(
      List<DistributionEntry> distribution) {
    if (distribution.isEmpty) return null;
    final sorted = List<DistributionEntry>.from(distribution)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
    return sorted.first.label;
  }

  List<RwaEvolutionPoint> _generateRwaEvolution(
    List<DashboardProjectionPoint> projection,
  ) {
    final now = DateTime.now();
    return projection.asMap().entries.map((entry) {
      return RwaEvolutionPoint(
        label: entry.value.label,
        value: entry.value.value,
        date: DateTime(now.year, now.month + entry.key, 1),
      );
    }).toList();
  }

  List<PrudentialAlert> _generatePrudentialAlerts(
    DashboardSnapshot dashboard,
    RegulatoryAnalysisReport report,
    double concentrationLevel,
    double lowRatedExposure,
  ) {
    final alerts = <PrudentialAlert>[
      for (final diagnostic in report.diagnostics)
        if (diagnostic.severity == 'CRITICAL' || diagnostic.severity == 'HIGH')
          PrudentialAlert(
            severity: diagnostic.severity.toLowerCase(),
            message: diagnostic.message,
            action: report.recommendations.first.action,
          ),
    ];
    if (concentrationLevel > 0.4) {
      alerts.add(
        const PrudentialAlert(
          severity: 'high',
          message: 'Concentration de portefeuille elevee',
          action: 'Diversifier les expositions sur plusieurs secteurs et pays',
        ),
      );
    }
    if (lowRatedExposure > 0.2) {
      alerts.add(
        const PrudentialAlert(
          severity: 'medium',
          message: 'Exposition significative aux notations speculatives',
          action: 'Renforcer les garanties ou reduire ces expositions',
        ),
      );
    }
    return alerts;
  }

  List<RiskExposure> _identifyTopRiskExposures(List<PortfolioRow> portfolio) {
    final sorted = List<PortfolioRow>.from(portfolio)
      ..sort((a, b) => b.rwa.compareTo(a.rwa));
    return sorted.take(10).map((row) {
      return RiskExposure(
        counterparty: row.counterparty,
        rwa: row.rwa,
        rating: row.rating,
        category: row.category,
      );
    }).toList();
  }

  List<AnalyseRecommendation> _generateRecommendations(
    double concentrationLevel,
    double lowRatedExposure,
    double crmCoverage,
    double reductionPotential,
    List<RiskExposure> topRisks,
    RegulatoryAnalysisReport report,
  ) {
    final recommendations = <AnalyseRecommendation>[];
    for (final action in report.recommendations) {
      recommendations.add(
        AnalyseRecommendation(
          title: action.priority == 1
              ? 'Action prudentielle prioritaire'
              : 'Pilotage du capital',
          description: action.action,
          impact: action.priority == 1 ? 'high' : 'medium',
          effort: action.priority == 1 ? 'medium' : 'low',
          priority: action.priority == 1 ? 'high' : 'medium',
          category: 'regulatory',
          estimatedSaving:
              report.capitalGap < 0 ? report.capitalGap.abs() : null,
          actions: [
            'Documenter la cause dans le dossier trimestriel.',
            'Affecter un responsable et une date cible.',
          ],
        ),
      );
    }
    if (concentrationLevel > 0.3) {
      recommendations.add(
        AnalyseRecommendation(
          title: 'Diversifier le portefeuille',
          description:
              'Le niveau de concentration actuel (${_pct(concentrationLevel)}) augmente la sensibilite au Pilier 2.',
          impact: 'high',
          effort: 'medium',
          priority: 'high',
          category: 'diversification',
          estimatedSaving: null,
          actions: const [
            'Fixer des limites sectorielles et groupe client.',
            'Revoir les tickets des 10 premieres contreparties.',
          ],
        ),
      );
    }
    if (crmCoverage < 0.5) {
      recommendations.add(
        AnalyseRecommendation(
          title: 'Augmenter la couverture CRM',
          description:
              'La couverture CRM de ${_pct(crmCoverage)} laisse un potentiel de reduction de RWA.',
          impact: 'high',
          effort: 'medium',
          priority: 'high',
          category: 'crm',
          estimatedSaving: reductionPotential * 0.3,
          actions: const [
            'Identifier les expositions non garanties.',
            'Prioriser les garanties eligibles au sens prudentiel.',
          ],
        ),
      );
    }
    if (lowRatedExposure > 0.15 || topRisks.isNotEmpty) {
      recommendations.add(
        AnalyseRecommendation(
          title: 'Optimiser les expositions a fort RWA',
          description:
              'Les notations faibles ou non notees consomment davantage de capital.',
          impact: 'medium',
          effort: 'medium',
          priority: 'medium',
          category: 'quality',
          estimatedSaving: reductionPotential * 0.25,
          actions: const [
            'Renforcer la documentation financiere des contreparties.',
            'Convertir les dossiers les plus consommateurs en expositions mieux collateralisees.',
          ],
        ),
      );
    }
    recommendations.sort((a, b) {
      const order = {'high': 0, 'medium': 1, 'low': 2};
      return (order[a.priority] ?? 99).compareTo(order[b.priority] ?? 99);
    });
    return recommendations;
  }

  RegulatoryDiagnostic _ratioDiagnostic({
    required String ruleReference,
    required String label,
    required double currentRatio,
    required double threshold,
    bool higherIsBad = false,
  }) {
    final gap =
        higherIsBad ? threshold - currentRatio : currentRatio - threshold;
    final compliant =
        higherIsBad ? currentRatio <= threshold : currentRatio >= threshold;
    final severity = compliant
        ? 'LOW'
        : gap.abs() >= 0.015
            ? 'CRITICAL'
            : 'HIGH';
    final comparator = higherIsBad ? 'limite' : 'cible';
    final direction = compliant ? 'respecte' : 'ne respecte pas';
    return RegulatoryDiagnostic(
      ruleReference: ruleReference,
      threshold: threshold,
      currentValue: currentRatio,
      gap: gap,
      message:
          'Votre ratio $label est de ${_pct(currentRatio)}. Il $direction la $comparator de ${_pct(threshold)} (ecart ${_pct(gap)}).',
      severity: severity,
    );
  }

  _RegulatoryThresholds _thresholdsFor(RegulatoryZone zone) {
    switch (zone) {
      case RegulatoryZone.cemac:
        return const _RegulatoryThresholds(
          cet1Minimum: 0.045,
          cet1Target: 0.070,
          tier1Target: 0.085,
          fpeMinimum: 0.080,
          fpeTarget: 0.105,
          largeRiskLimit: 0.25,
        );
      case RegulatoryZone.uemoa:
        return const _RegulatoryThresholds(
          cet1Minimum: 0.050,
          cet1Target: 0.075,
          // Tier 1 minimum 6 % + coussin de conservation 2,5 % = 8,5 %.
          tier1Target: 0.085,
          fpeMinimum: 0.090,
          fpeTarget: 0.115,
          largeRiskLimit: 0.25,
        );
    }
  }

  _ConservationBand _conservationRequirement(
    double cet1Ratio,
    _RegulatoryThresholds thresholds,
  ) {
    final buffer = thresholds.cet1Target - thresholds.cet1Minimum;
    final progress = _safeRatio(cet1Ratio - thresholds.cet1Minimum, buffer);
    if (progress <= 0) {
      return const _ConservationBand('[sous minimum CET1]', 1.0);
    }
    if (progress < 0.25) return const _ConservationBand('[0%; 25%]', 1.0);
    if (progress < 0.50) return const _ConservationBand('[25%; 50%]', 0.8);
    if (progress < 0.75) return const _ConservationBand('[50%; 75%]', 0.6);
    if (progress < 1.0) return const _ConservationBand('[75%; 100%]', 0.4);
    return const _ConservationBand('[coussin constitue]', 0.0);
  }

  String _buildNarrative({
    required double fpeRatio,
    required _RegulatoryThresholds thresholds,
    required double capitalGap,
    required DistributionEntry? topSector,
    required int largeRisks,
    required _ConservationBand conservation,
    required int exposureCount,
  }) {
    final bufferText = capitalGap >= 0
        ? 'La banque conserve une marge de ${formatCurrencyCompact(capitalGap)} au-dessus de la cible.'
        : 'Il manque ${formatCurrencyCompact(capitalGap.abs())} pour revenir a la cible.';
    return 'Votre ratio de solvabilite est de ${_pct(fpeRatio)} contre une cible UEMOA de ${_pct(thresholds.fpeTarget)}. $bufferText '
        'La cause principale identifiee est la concentration du RWA sur ${topSector?.label ?? 'le segment dominant'}, avec $largeRisks grand(s) risque(s) a surveiller sur $exposureCount exposition(s). '
        'A court terme, conservez ${_pct(conservation.minimumRetention)} des benefices distribuables, puis arbitrez entre augmentation de FPE, ralentissement des actifs les plus consommateurs et renforcement des garanties eligibles.';
  }

  double _totalRwa(DashboardSnapshot dashboard) {
    final byRows = dashboard.portfolioOverview.fold<double>(
      0,
      (sum, item) => sum + item.rwa,
    );
    if (byRows > 0) return byRows;
    return dashboard.rwaCategoryDistribution.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
  }

  double _metricValue(
    DashboardSnapshot dashboard,
    String key, {
    double fallback = 0,
  }) {
    return dashboard.metrics
        .firstWhere(
          (item) => item.key == key,
          orElse: () => DashboardMetric(
            key: key,
            label: key,
            value: fallback,
            variation: '0%',
            trend: const [],
          ),
        )
        .value;
  }

  /// Sensibilité IRRBB estimée par heuristique (aucun module IRRBB dans
  /// l'outil pour l'instant) : le message affiché la présente explicitement
  /// comme une estimation.
  double _estimateIrrbbShockRatio(DashboardSnapshot dashboard) {
    final topCountry = _topDistribution(dashboard.countryDistribution);
    final concentration = topCountry?.percentage ?? 0.0;
    return (0.055 + concentration * 0.09).clamp(0.0, 0.24).toDouble();
  }

  DistributionEntry? _topDistribution(List<DistributionEntry> entries) {
    if (entries.isEmpty) return null;
    final sorted = List<DistributionEntry>.from(entries)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
    return sorted.first;
  }

  RegulatoryStatus _statusFromGap(double gap) {
    if (gap >= 0) return RegulatoryStatus.green;
    if (gap > -0.015) return RegulatoryStatus.warning;
    return RegulatoryStatus.critical;
  }

  double _safeRatio(double numerator, double denominator) {
    if (denominator == 0) return 0.0;
    return numerator / denominator;
  }

  String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
}

class _RegulatoryThresholds {
  const _RegulatoryThresholds({
    required this.cet1Minimum,
    required this.cet1Target,
    required this.tier1Target,
    required this.fpeMinimum,
    required this.fpeTarget,
    required this.largeRiskLimit,
  });

  final double cet1Minimum;
  final double cet1Target;
  final double tier1Target;
  final double fpeMinimum;
  final double fpeTarget;
  final double largeRiskLimit;
}

class _ConservationBand {
  const _ConservationBand(this.bandLabel, this.minimumRetention);

  final String bandLabel;
  final double minimumRetention;

  double get distributableRatio => 1 - minimumRetention;
}
