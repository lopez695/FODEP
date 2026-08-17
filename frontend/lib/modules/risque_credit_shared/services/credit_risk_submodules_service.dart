import 'dart:math' as math;

import '../../../core/services/rwa_api_service.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../expositions/models/exposition_models.dart';
import '../../crm/models/crm_models.dart';
import '../models/credit_risk_models.dart';

class CreditRiskSubmodulesService {
  CreditRiskSubmodulesService(this.api);

  final RwaApiService api;

  static final Map<String, CreditGuaranteeRecord> _editedGuarantees = {};
  static final Set<String> _deletedGuaranteeIds = <String>{};
  static final List<CreditGuaranteeRecord> _customGuarantees =
      <CreditGuaranteeRecord>[];
  static final List<CreditReportHistoryRecord> _reportHistory =
      <CreditReportHistoryRecord>[];

  Future<GuaranteesModuleData> fetchGuaranteesModule() async {
    final exposureModule = await api.fetchExpositionsModule();
    final crmModule = await api.fetchCrmModule();
    final baseGuarantees = _buildBaseGuarantees(
      exposureModule.exposures,
      crmModule.items,
    );

    final merged = <CreditGuaranteeRecord>[
      for (final item in baseGuarantees)
        if (!_deletedGuaranteeIds.contains(item.id))
          _editedGuarantees[item.id] ?? item,
      ..._customGuarantees.where(
        (item) => !_deletedGuaranteeIds.contains(item.id),
      ),
    ]..sort(
        (left, right) => right.expirationDate.compareTo(left.expirationDate));

    final exposureOptions = exposureModule.exposures
        .map(
          (item) => CreditExposureOption(
            id: item.id,
            label: '${item.id} • ${item.counterparty.name}',
            counterpartyName: item.counterparty.name,
            category: item.categoryLabel,
            currency: item.currency,
            grossAmount: item.grossAmount,
          ),
        )
        .toList()
      ..sort((left, right) => left.label.compareTo(right.label));

    final now = DateTime.now();
    final activeGuarantees =
        merged.where((item) => !_isExpired(item.expirationDate, now)).toList();
    final summary = CreditGuaranteeSummary(
      totalGuarantees: merged.length,
      activeValue: activeGuarantees.fold<double>(
        0.0,
        (sum, item) => sum + item.value,
      ),
      averageCoverage: merged.isEmpty
          ? 0.0
          : merged.fold<double>(0.0, (sum, item) => sum + item.coverageRatio) /
              merged.length,
      expiringSoonCount: merged.where((item) {
        if (_isExpired(item.expirationDate, now)) {
          return false;
        }
        final days = item.expirationDate.difference(now).inDays;
        return days <= 90;
      }).length,
    );

    return GuaranteesModuleData(
      guarantees: merged,
      exposureOptions: exposureOptions,
      summary: summary,
    );
  }

  Future<void> upsertGuarantee(CreditGuaranteeDraft draft) async {
    final exposureModule = await api.fetchExpositionsModule();
    final exposure = exposureModule.exposures.firstWhere(
      (item) => item.id == draft.exposureId,
      orElse: () => throw Exception(
        'Exposition introuvable (${draft.exposureId}) : elle a peut-être été supprimée depuis.',
      ),
    );

    final id = draft.id ?? _nextGuaranteeId();
    final record = CreditGuaranteeRecord(
      id: id,
      exposureId: exposure.id,
      exposureLabel: '${exposure.id} • ${exposure.counterparty.name}',
      counterpartyName: exposure.counterparty.name,
      sector: _sectorFromCategory(exposure.categoryLabel),
      type: draft.type,
      value: draft.value,
      currency: draft.currency,
      coverageRatio: draft.coverageRatio.clamp(0.0, 1.0).toDouble(),
      expirationDate: draft.expirationDate,
      status: draft.status,
      sourceLabel: id.startsWith('CRM') ? 'CRM ajuste' : 'Saisie manuelle',
      rwaLinked: true,
    );

    _deletedGuaranteeIds.remove(id);
    final customIndex = _customGuarantees.indexWhere((item) => item.id == id);
    if (customIndex >= 0) {
      _customGuarantees[customIndex] = record;
      return;
    }

    if (id.startsWith('CRM')) {
      _editedGuarantees[id] = record;
      return;
    }

    _customGuarantees.insert(0, record);
  }

  Future<void> deleteGuarantee(String id) async {
    _editedGuarantees.remove(id);
    _customGuarantees.removeWhere((item) => item.id == id);
    _deletedGuaranteeIds.add(id);
  }

  Future<DefaultsModuleData> fetchDefaultsModule() async {
    final exposureModule = await api.fetchExpositionsModule();
    final guarantees = await fetchGuaranteesModule();
    final activeCoverageByExposure = <String, double>{};

    for (final item in guarantees.guarantees) {
      if (_isExpired(item.expirationDate, DateTime.now())) {
        continue;
      }
      activeCoverageByExposure.update(
        item.exposureId,
        (value) => math.max(value, item.coverageRatio),
        ifAbsent: () => item.coverageRatio,
      );
    }

    final candidates = [...exposureModule.exposures]..sort((left, right) {
        final rightScore = _defaultRiskScore(right);
        final leftScore = _defaultRiskScore(left);
        return rightScore.compareTo(leftScore);
      });

    final records = candidates
        .take(math.min(6, candidates.length))
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => _buildDefaultRecord(
            entry.value,
            index: entry.key,
            activeCoverage: activeCoverageByExposure[entry.value.id] ?? 0.0,
          ),
        )
        .toList(growable: false);

    final summary = CreditDefaultSummary(
      totalDefaults: records.length,
      totalDefaultGross: records.fold<double>(
        0.0,
        (sum, item) => sum + item.grossAmount,
      ),
      totalProvision: records.fold<double>(
        0.0,
        (sum, item) => sum + item.estimatedProvision,
      ),
      averageDaysPastDue: records.isEmpty
          ? 0.0
          : records.fold<double>(0.0, (sum, item) => sum + item.daysPastDue) /
              records.length,
    );

    return DefaultsModuleData(items: records, summary: summary);
  }

  Future<ConcentrationModuleData> fetchConcentrationModule() async {
    final exposureModule = await api.fetchExpositionsModule();
    final exposures = exposureModule.exposures;
    final totalGross = exposures.fold<double>(
      0.0,
      (sum, item) => sum + item.grossAmountXof,
    );
    final totalNetEad =
        exposures.fold<double>(0.0, (sum, item) => sum + item.eadXof);
    final totalRwa =
        exposures.fold<double>(0.0, (sum, item) => sum + item.rwaXof);
    final totalCapital =
        exposures.fold<double>(0.0, (sum, item) => sum + item.capitalXof);
    final latestDate = exposures.isEmpty
        ? DateTime.now()
        : exposures
            .map((item) => item.analysisDate)
            .reduce((left, right) => left.isAfter(right) ? left : right);

    final sectorGroups = <String, _ConcentrationAccumulator>{};
    final countryGroups = <String, _ConcentrationAccumulator>{};
    final regionGroups = <String, _ConcentrationAccumulator>{};
    final prudentialGroups = <String, _ConcentrationAccumulator>{};
    final counterpartyGroups = <String, _ConcentrationAccumulator>{};
    final riskWeightGroups = <double, _ConcentrationAccumulator>{};
    final ratingTotals = <String, double>{};
    final exposureDetails = <ConcentrationExposureDetail>[];

    for (final item in exposures) {
      final sector = _sectorFromCategory(item.categoryLabel);
      final counterpartyName = item.counterparty.name.trim().isEmpty
          ? item.id
          : item.counterparty.name.trim();
      final country = item.counterparty.country.trim().isEmpty
          ? 'Non renseigné'
          : item.counterparty.country.trim();
      final region = item.zone.trim().isEmpty ? 'Non renseigné' : item.zone;
      final category = item.categoryLabel.trim().isEmpty
          ? 'Non renseigné'
          : item.categoryLabel.trim();
      final riskWeightBucket = _riskWeightBucket(item.finalRw);
      final activeCoverage = _crmCoverageRatio(item);
      final estimatedProvision = _estimatedProvisionAmountForExposure(item);
      final provisionRate = item.ead > 0 ? estimatedProvision / item.ead : 0.0;

      sectorGroups
          .putIfAbsent(sector, () => _ConcentrationAccumulator(label: sector))
          .add(item, sector: sector, country: country);
      countryGroups
          .putIfAbsent(country, () => _ConcentrationAccumulator(label: country))
          .add(item, sector: sector, country: country);
      regionGroups
          .putIfAbsent(region, () => _ConcentrationAccumulator(label: region))
          .add(item, sector: sector, country: country);
      prudentialGroups
          .putIfAbsent(
            category,
            () => _ConcentrationAccumulator(label: category),
          )
          .add(item, sector: sector, country: country);
      counterpartyGroups
          .putIfAbsent(
            counterpartyName,
            () => _ConcentrationAccumulator(label: counterpartyName),
          )
          .add(item, sector: sector, country: country);
      riskWeightGroups
          .putIfAbsent(
            riskWeightBucket,
            () => _ConcentrationAccumulator(
              label: _riskWeightBucketLabel(riskWeightBucket),
            ),
          )
          .add(item, sector: sector, country: country);
      // Tous les montants du détail sont convertis en XOF (devise de calcul
      // unique) ; provisionRate reste un ratio (invariant par devise).
      double toXof(double value) => convertCurrencyAmount(
            value,
            fromCurrency: item.currency,
            toCurrency: 'XOF',
          );
      ratingTotals.update(
        item.ratingLabel,
        (value) => value + item.grossAmountXof,
        ifAbsent: () => item.grossAmountXof,
      );
      exposureDetails.add(
        ConcentrationExposureDetail(
          id: item.id,
          analysisDate: item.analysisDate,
          counterpartyName: counterpartyName,
          country: country,
          region: region,
          sector: sector,
          segment: sector,
          prudentialCategory: category,
          rating: item.ratingLabel,
          status: item.status,
          hasGuarantee: item.crmModeLabel != 'Aucune' || activeCoverage > 0,
          isDefault: item.isDefaultLike,
          authorizationAmount: toXof(item.loanTotalAmount ?? item.grossAmount),
          onBalanceAmount: toXof(item.onBalanceExposureAmount ?? item.grossAmount),
          offBalanceAmount: toXof(item.offBalanceExposureAmount ?? 0.0),
          grossAmount: item.grossAmountXof,
          ead: item.eadXof,
          rwa: item.rwaXof,
          capital: item.capitalXof,
          originalRiskWeight: _normalizedRiskWeight(item.originalRw),
          riskWeight: _normalizedRiskWeight(item.finalRw),
          crmCoverageRatio: activeCoverage,
          pd: _pdFromRating(item.ratingLabel),
          lgd: _lgdFromCrm(item),
          estimatedProvision: toXof(estimatedProvision),
          provisionRate: provisionRate,
          joursImpayes: item.joursImpayes,
          provisionsAmount: item.provisionsAmount ?? 0.0,
        ),
      );
    }

    final sectorRows = _sectorRowsFromGroups(
      sectorGroups,
      totalGross: totalGross,
      totalRwa: totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final countryRows = _breakdownRowsFromGroups(
      countryGroups,
      group: 'Pays',
      totalGross: totalGross,
      totalRwa: totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final regionRows = _breakdownRowsFromGroups(
      regionGroups,
      group: 'Région',
      totalGross: totalGross,
      totalRwa: totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final prudentialRows = _breakdownRowsFromGroups(
      prudentialGroups,
      group: 'Catégorie prudentielle',
      totalGross: totalGross,
      totalRwa: totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final topCounterparties = _counterpartyRowsFromGroups(
      counterpartyGroups,
      totalGross: totalGross,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final topRwaCounterparties = [...topCounterparties]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final rwaSectorRows = [...sectorRows]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final riskWeightRows = _riskWeightRowsFromGroups(
      riskWeightGroups,
      totalEad: totalNetEad,
      totalRwa: totalRwa,
    )..sort((left, right) => left.weight.compareTo(right.weight));

    final sectorDistribution = _distributionFromSectorRows(
      sectorRows,
      totalGross,
    );
    final countryDistribution = _distributionFromBreakdownRows(
      countryRows.take(7).toList(growable: false),
      totalGross,
    );
    final ratingDistribution =
        _distributionFromTotals(ratingTotals, totalGross).take(5).toList();

    final topSectorShare = sectorRows.isEmpty
        ? 0.0
        : sectorRows.first.share.clamp(0.0, 1.0).toDouble();
    final topThreeShare = sectorRows
        .take(3)
        .fold<double>(0.0, (sum, item) => sum + item.share)
        .clamp(0.0, 1.0)
        .toDouble();
    final topCounterpartyShare =
        topCounterparties.isEmpty ? 0.0 : topCounterparties.first.share;
    final hhi = _hhi(
      counterpartyGroups.values.map(
        (item) => totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
      ),
    );
    final trends = _portfolioTrends(exposures);
    final quality = _portfolioQuality(
      exposures,
      totalGross: totalGross,
      totalNetEad: totalNetEad,
      trends: trends,
    );
    final alerts = _concentrationAlerts(
      latestDate: latestDate,
      totalRwa: totalRwa,
      ownFunds: totalCapital * 1.42,
      hhi: hhi,
      topSectors: sectorRows,
      topCounterparties: topCounterparties,
      topCountries: countryRows,
      rwaCounterparties: topRwaCounterparties,
      trends: trends,
    );

    return ConcentrationModuleData(
      summary: ConcentrationSummary(
        totalGross: totalGross,
        totalNetEad: totalNetEad,
        totalRwa: totalRwa,
        topSectorShare: topSectorShare,
        topThreeShare: topThreeShare,
        topSectorLabel: sectorRows.isEmpty ? 'N/D' : sectorRows.first.sector,
        topCounterpartyName: topCounterparties.isEmpty
            ? 'N/D'
            : topCounterparties.first.counterpartyName,
        topCounterpartyShare: topCounterpartyShare,
        herfindahlIndex: hhi,
        hhiBadge: _hhiBadge(hhi),
        counterpartyCount: counterpartyGroups.length,
      ),
      sectorRows: sectorRows,
      countryRows: countryRows,
      regionRows: regionRows,
      prudentialRows: prudentialRows,
      riskWeightRows: riskWeightRows,
      rwaSectorRows: rwaSectorRows,
      rwaCounterpartyRows: topRwaCounterparties,
      exposureDetails: exposureDetails,
      topExposures: topCounterparties,
      sectorDistribution: sectorDistribution,
      countryDistribution: countryDistribution,
      ratingDistribution: ratingDistribution,
      quality: quality,
      trends: trends,
      alerts: alerts,
    );
  }

  List<SectorConcentrationRow> _sectorRowsFromGroups(
    Map<String, _ConcentrationAccumulator> groups, {
    required double totalGross,
    required double totalRwa,
  }) {
    return groups.values
        .map(
          (item) => SectorConcentrationRow(
            sector: item.label,
            exposureCount: item.exposureCount,
            grossAmount: item.grossAmount,
            ead: item.ead,
            rwa: item.rwa,
            averageRiskWeight: item.averageRiskWeight,
            rwaShare: totalRwa == 0 ? 0.0 : item.rwa / totalRwa,
            share: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
          ),
        )
        .toList();
  }

  List<ConcentrationBreakdownRow> _breakdownRowsFromGroups(
    Map<String, _ConcentrationAccumulator> groups, {
    required String group,
    required double totalGross,
    required double totalRwa,
  }) {
    return groups.values
        .map(
          (item) => ConcentrationBreakdownRow(
            label: item.label,
            group: group,
            exposureCount: item.exposureCount,
            grossAmount: item.grossAmount,
            ead: item.ead,
            rwa: item.rwa,
            averageRiskWeight: item.averageRiskWeight,
            portfolioShare:
                totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
            rwaShare: totalRwa == 0 ? 0.0 : item.rwa / totalRwa,
          ),
        )
        .toList();
  }

  List<ConcentrationExposureRow> _counterpartyRowsFromGroups(
    Map<String, _ConcentrationAccumulator> groups, {
    required double totalGross,
  }) {
    return groups.values
        .map(
          (item) => ConcentrationExposureRow(
            exposureId: '${item.exposureCount} dossier(s)',
            counterpartyName: item.label,
            country: item.country,
            sector: item.sector,
            segment: item.sector,
            grossAmount: item.grossAmount,
            ead: item.ead,
            rwa: item.rwa,
            averageRiskWeight: item.averageRiskWeight,
            share: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
          ),
        )
        .toList();
  }

  List<RiskWeightBucketRow> _riskWeightRowsFromGroups(
    Map<double, _ConcentrationAccumulator> groups, {
    required double totalEad,
    required double totalRwa,
  }) {
    return groups.entries
        .map(
          (entry) => RiskWeightBucketRow(
            label: _riskWeightBucketLabel(entry.key),
            weight: entry.key,
            exposureCount: entry.value.exposureCount,
            ead: entry.value.ead,
            rwa: entry.value.rwa,
            portfolioShare: totalEad == 0 ? 0.0 : entry.value.ead / totalEad,
            rwaShare: totalRwa == 0 ? 0.0 : entry.value.rwa / totalRwa,
          ),
        )
        .toList();
  }

  List<DistributionEntry> _distributionFromSectorRows(
    List<SectorConcentrationRow> rows,
    double totalGross,
  ) {
    return rows
        .map(
          (row) => DistributionEntry(
            label: row.sector,
            amount: row.grossAmount,
            percentage: totalGross == 0 ? 0.0 : row.grossAmount / totalGross,
          ),
        )
        .toList();
  }

  List<DistributionEntry> _distributionFromBreakdownRows(
    List<ConcentrationBreakdownRow> rows,
    double totalGross,
  ) {
    return rows
        .map(
          (row) => DistributionEntry(
            label: row.label,
            amount: row.grossAmount,
            percentage: totalGross == 0 ? 0.0 : row.grossAmount / totalGross,
          ),
        )
        .toList();
  }

  PortfolioQualitySummary _portfolioQuality(
    List<ExposureRecord> exposures, {
    required double totalGross,
    required double totalNetEad,
    required List<ConcentrationTrendPoint> trends,
  }) {
    final defaultRows = exposures.where((item) => item.isDefaultLike).toList();
    final defaultGross =
        defaultRows.fold<double>(0.0, (sum, item) => sum + item.grossAmountXof);
    final weightedPd = exposures.fold<double>(
      0.0,
      (sum, item) => sum + _pdFromRating(item.ratingLabel) * item.eadXof,
    );
    final weightedLgd = exposures.fold<double>(
      0.0,
      (sum, item) => sum + _lgdFromCrm(item) * item.eadXof,
    );
    final estimatedProvision = defaultRows.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          convertCurrencyAmount(
            _estimatedProvisionAmountForExposure(item),
            fromCurrency: item.currency,
            toCurrency: 'XOF',
          ),
    );
    final nplTrend = trends.length < 2
        ? 0.0
        : trends.last.npl - trends[trends.length - 2].npl;

    return PortfolioQualitySummary(
      nplRatio: totalGross == 0 ? 0.0 : defaultGross / totalGross,
      defaultRate:
          exposures.isEmpty ? 0.0 : defaultRows.length / exposures.length,
      defaultGross: defaultGross,
      riskCoverage: defaultGross == 0 ? 0.0 : estimatedProvision / defaultGross,
      averagePd: totalNetEad == 0 ? 0.0 : weightedPd / totalNetEad,
      averageLgd: totalNetEad == 0 ? 0.0 : weightedLgd / totalNetEad,
      nplTrend: nplTrend,
      defaultTrend: nplTrend,
      coverageTrend: 0.0,
    );
  }

  List<ConcentrationTrendPoint> _portfolioTrends(
    List<ExposureRecord> exposures,
  ) {
    final groups = <DateTime, List<ExposureRecord>>{};
    for (final item in exposures) {
      final key = DateTime(item.analysisDate.year, item.analysisDate.month);
      groups.putIfAbsent(key, () => <ExposureRecord>[]).add(item);
    }
    final dates = groups.keys.toList()..sort();

    return [
      for (final date in dates)
        ConcentrationTrendPoint(
          label: _monthLabel(date),
          date: date,
          ead:
              groups[date]!.fold<double>(0.0, (sum, item) => sum + item.eadXof),
          rwa:
              groups[date]!.fold<double>(0.0, (sum, item) => sum + item.rwaXof),
          npl: _nplRatio(groups[date]!),
          hhi: _hhiForRows(groups[date]!),
        ),
    ];
  }

  List<ConcentrationAlert> _concentrationAlerts({
    required DateTime latestDate,
    required double totalRwa,
    required double ownFunds,
    required double hhi,
    required List<SectorConcentrationRow> topSectors,
    required List<ConcentrationExposureRow> topCounterparties,
    required List<ConcentrationBreakdownRow> topCountries,
    required List<ConcentrationExposureRow> rwaCounterparties,
    required List<ConcentrationTrendPoint> trends,
  }) {
    final alerts = <ConcentrationAlert>[];

    if (topSectors.isNotEmpty && topSectors.first.share > 0.25) {
      alerts.add(
        ConcentrationAlert(
          level: 'Secteur',
          severity: topSectors.first.share > 0.40 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              '${topSectors.first.sector} représente ${_percent(topSectors.first.share)} du portefeuille.',
          recommendation:
              'Revoir les limites sectorielles et renforcer le suivi des nouvelles entrées.',
        ),
      );
    }
    if (topCounterparties.isNotEmpty && ownFunds > 0) {
      final ratio = topCounterparties.first.grossAmount / ownFunds;
      if (ratio > 0.10) {
        alerts.add(
          ConcentrationAlert(
            level: 'Client',
            severity: ratio > 0.25 ? 'Élevé' : 'Moyen',
            date: latestDate,
            message:
                '${topCounterparties.first.counterpartyName} dépasse ${_percent(ratio)} des fonds propres estimés.',
            recommendation:
                'Contrôler la limite single-name et les garanties mobilisables.',
          ),
        );
      }
    }
    if (hhi > 1800) {
      alerts.add(
        ConcentrationAlert(
          level: 'HHI',
          severity: hhi > 2500 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message: 'Indice HHI à ${hhi.toStringAsFixed(0)}.',
          recommendation:
              'Diversifier les expositions ou recalibrer les seuils internes.',
        ),
      );
    }
    if (topCountries.isNotEmpty && topCountries.first.portfolioShare > 0.25) {
      alerts.add(
        ConcentrationAlert(
          level: 'Pays',
          severity:
              topCountries.first.portfolioShare > 0.40 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              '${topCountries.first.label} concentre ${_percent(topCountries.first.portfolioShare)} du portefeuille.',
          recommendation:
              'Tester les limites pays et les scénarios de stress souverain.',
        ),
      );
    }
    if (rwaCounterparties.isNotEmpty && totalRwa > 0) {
      final topFiveRwa = rwaCounterparties
          .take(5)
          .fold<double>(0.0, (sum, item) => sum + item.rwa);
      final share = topFiveRwa / totalRwa;
      if (share > 0.40) {
        alerts.add(
          ConcentrationAlert(
            level: 'RWA',
            severity: share > 0.60 ? 'Élevé' : 'Moyen',
            date: latestDate,
            message:
                '${_percent(share)} du RWA est porté par moins de 5 contreparties.',
            recommendation:
                'Prioriser les revues de rating, garanties et arbitrages RWA.',
          ),
        );
      }
    }
    if (trends.length >= 2 && trends[trends.length - 2].ead > 0) {
      final growth = (trends.last.ead - trends[trends.length - 2].ead) /
          trends[trends.length - 2].ead;
      if (growth > 0.15) {
        alerts.add(
          ConcentrationAlert(
            level: 'Croissance',
            severity: growth > 0.30 ? 'Élevé' : 'Moyen',
            date: latestDate,
            message:
                'Croissance mensuelle anormale de ${_percent(growth)} sur l’EAD.',
            recommendation:
                'Vérifier les nouveaux engagements et leur consommation RWA.',
          ),
        );
      }
    }

    return alerts;
  }

  double _hhi(Iterable<double> shares) {
    return shares.fold<double>(
      0.0,
      (sum, share) => sum + math.pow(share * 100, 2).toDouble(),
    );
  }

  double _hhiForRows(List<ExposureRecord> exposures) {
    final totalGross = exposures.fold<double>(
      0.0,
      (sum, item) => sum + item.grossAmountXof,
    );
    if (totalGross == 0) {
      return 0.0;
    }
    final totals = <String, double>{};
    for (final item in exposures) {
      totals.update(
        item.counterparty.name,
        (value) => value + item.grossAmountXof,
        ifAbsent: () => item.grossAmountXof,
      );
    }
    return _hhi(totals.values.map((amount) => amount / totalGross));
  }

  String _hhiBadge(double hhi) {
    if (hhi >= 1800) {
      return 'Élevé';
    }
    if (hhi >= 1000) {
      return 'Moyen';
    }
    return 'Faible';
  }

  double _riskWeightBucket(double rawWeight) {
    final weight = _normalizedRiskWeight(rawWeight);
    const buckets = <double>[0.0, 0.20, 0.50, 0.75, 1.0, 1.50];
    return buckets.reduce(
      (closest, bucket) =>
          (weight - bucket).abs() < (weight - closest).abs() ? bucket : closest,
    );
  }

  String _riskWeightBucketLabel(double weight) {
    return '${(weight * 100).round()} %';
  }

  double _normalizedRiskWeight(double rawWeight) {
    return rawWeight > 2 ? rawWeight / 100 : rawWeight;
  }

  double _crmCoverageRatio(ExposureRecord exposure) {
    final rawCoverage = exposure.crmCoveragePercent == 0
        ? exposure.crmDetails.coveragePercent
        : exposure.crmCoveragePercent;
    final normalized = rawCoverage > 1 ? rawCoverage / 100 : rawCoverage;
    return normalized.clamp(0.0, 1.0).toDouble();
  }

  double _estimatedProvisionAmountForExposure(ExposureRecord exposure) {
    if (exposure.provisionsAmount != null) {
      return exposure.provisionsAmount!;
    }
    if (!exposure.isDefaultLike) {
      return 0.0;
    }
    final rate = exposure.defaultedExposureProvisionAtLeastTwentyPercent == true
        ? 0.20
        : 0.0;
    return exposure.ead * rate;
  }

  double _nplRatio(List<ExposureRecord> exposures) {
    final totalGross = exposures.fold<double>(
      0.0,
      (sum, item) => sum + item.grossAmountXof,
    );
    if (totalGross == 0) {
      return 0.0;
    }
    final defaultGross = exposures
        .where((item) => item.isDefaultLike)
        .fold<double>(0.0, (sum, item) => sum + item.grossAmountXof);
    return defaultGross / totalGross;
  }

  double _pdFromRating(String rating) {
    final normalized = rating.toUpperCase();
    if (normalized.contains('AAA') || normalized == 'AA') {
      return 0.0005;
    }
    if (normalized == 'A') {
      return 0.0015;
    }
    if (normalized == 'BBB') {
      return 0.006;
    }
    if (normalized.contains('BB') || normalized.contains('B')) {
      return 0.025;
    }
    return 0.045;
  }

  double _lgdFromCrm(ExposureRecord exposure) {
    final coverage = _crmCoverageRatio(exposure);
    return (1 - coverage).clamp(0.25, 1.0).toDouble();
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Janv.',
      'Févr.',
      'Mars',
      'Avr.',
      'Mai',
      'Juin',
      'Juil.',
      'Août',
      'Sept.',
      'Oct.',
      'Nov.',
      'Déc.',
    ];
    return months[date.month - 1];
  }

  Future<CreditReportingModuleData> fetchReportingModule() async {
    final exposureModule = await api.fetchExpositionsModule();
    final guaranteesModule = await fetchGuaranteesModule();
    final defaultsModule = await fetchDefaultsModule();

    final snapshots = [
      CreditReportingFamilySnapshot(
        family: CreditReportFamily.portfolio,
        itemCount: exposureModule.exposures.length,
        totalAmount: exposureModule.summary.totalExpositions,
      ),
      CreditReportingFamilySnapshot(
        family: CreditReportFamily.guarantees,
        itemCount: guaranteesModule.guarantees.length,
        totalAmount: guaranteesModule.guarantees.fold<double>(
          0.0,
          (sum, item) => sum + item.value,
        ),
      ),
      CreditReportingFamilySnapshot(
        family: CreditReportFamily.defaults,
        itemCount: defaultsModule.items.length,
        totalAmount: defaultsModule.summary.totalDefaultGross,
      ),
    ];

    final summary = CreditReportingSummary(
      generatedReports: _reportHistory.length,
      excelExports: _reportHistory
          .where((item) => item.format == CreditExportFormat.excel)
          .length,
      pdfExports: _reportHistory
          .where((item) => item.format == CreditExportFormat.pdf)
          .length,
    );

    return CreditReportingModuleData(
      familySnapshots: snapshots,
      history: List<CreditReportHistoryRecord>.unmodifiable(_reportHistory),
      summary: summary,
    );
  }

  Future<CreditExportDataset> buildExportDataset(
    CreditReportFamily family,
  ) async {
    switch (family) {
      case CreditReportFamily.portfolio:
        final module = await api.fetchExpositionsModule();
        return CreditExportDataset(
          sheetName: 'Portefeuille',
          headers: const [
            'ID',
            'Contrepartie',
            'Pays',
            'Categorie',
            'Notation',
            'Montant brut',
            'EAD',
            'RWA',
            'Capital',
            'CRM',
          ],
          rows: module.exposures
              .map(
                (item) => [
                  item.id,
                  item.counterparty.name,
                  item.counterparty.country,
                  item.categoryLabel,
                  item.ratingLabel,
                  _number(item.grossAmount),
                  _number(item.ead),
                  _number(item.rwa),
                  _number(item.capital),
                  item.crmModeLabel,
                ],
              )
              .toList(growable: false),
          totalAmount: module.summary.totalExpositions,
        );
      case CreditReportFamily.guarantees:
        final module = await fetchGuaranteesModule();
        return CreditExportDataset(
          sheetName: 'Garanties',
          headers: const [
            'ID',
            'Exposition',
            'Contrepartie',
            'Secteur',
            'Type',
            'Valeur',
            'Couverture',
            'Expiration',
            'Statut',
            'Source',
          ],
          rows: module.guarantees
              .map(
                (item) => [
                  item.id,
                  item.exposureLabel,
                  item.counterpartyName,
                  item.sector,
                  item.type,
                  _number(item.value),
                  _percent(item.coverageRatio),
                  AppFormatters.shortDate(item.expirationDate),
                  item.status,
                  item.sourceLabel,
                ],
              )
              .toList(growable: false),
          totalAmount: module.guarantees.fold<double>(
            0.0,
            (sum, item) => sum + item.value,
          ),
        );
      case CreditReportFamily.defaults:
        final module = await fetchDefaultsModule();
        return CreditExportDataset(
          sheetName: 'Defauts',
          headers: const [
            'Exposition',
            'Contrepartie',
            'Pays',
            'Secteur',
            'Notation',
            'Jours de retard',
            'Statut prudentiel',
            'Provision estimee',
            'Taux de provision',
            'Incidents',
          ],
          rows: module.items
              .map(
                (item) => [
                  item.exposureId,
                  item.counterpartyName,
                  item.country,
                  item.sector,
                  item.rating,
                  item.daysPastDue.toString(),
                  item.prudentialStatus,
                  _number(item.estimatedProvision),
                  _percent(item.provisionRate),
                  item.incidents.length.toString(),
                ],
              )
              .toList(growable: false),
          totalAmount: module.summary.totalDefaultGross,
        );
    }
  }

  Future<CreditReportHistoryRecord> registerExport({
    required CreditReportFamily family,
    required CreditExportFormat format,
    required String fileName,
    required int lineCount,
    required double totalAmount,
  }) async {
    final record = CreditReportHistoryRecord(
      id: 'RCR${(_reportHistory.length + 1).toString().padLeft(3, '0')}',
      createdAt: DateTime.now(),
      family: family,
      format: format,
      fileName: fileName,
      lineCount: lineCount,
      totalAmount: totalAmount,
    );
    _reportHistory.insert(0, record);
    return record;
  }

  List<CreditGuaranteeRecord> _buildBaseGuarantees(
    List<ExposureRecord> exposures,
    List<CrmRecord> crmItems,
  ) {
    final exposureById = {
      for (final item in exposures) item.id: item,
    };

    return crmItems.map((item) {
      final exposure = exposureById[item.exposureId];
      final expirationDate = exposure?.maturityDate ??
          exposure?.analysisDate.add(
            Duration(days: 240 + (item.coverageRatio * 160).round()),
          ) ??
          DateTime.now().add(const Duration(days: 180));

      return CreditGuaranteeRecord(
        id: item.id,
        exposureId: item.exposureId,
        exposureLabel: '${item.exposureId} • ${item.borrowerName}',
        counterpartyName: item.borrowerName,
        sector: _sectorFromCategory(item.borrowerCategory),
        type: item.guaranteeType,
        value: item.coverageAmount,
        currency: 'XOF',
        coverageRatio: item.coverageRatio,
        expirationDate: expirationDate,
        status: _resolveGuaranteeStatus(expirationDate),
        sourceLabel: 'CRM RWA',
        rwaLinked: true,
      );
    }).toList(growable: false);
  }

  CreditDefaultRecord _buildDefaultRecord(
    ExposureRecord exposure, {
    required int index,
    required double activeCoverage,
  }) {
    final baseDelay = switch (exposure.ratingLabel) {
      'BB/B' => 78,
      'BBB' => 46,
      'A' => 21,
      _ => exposure.isDefaultLike ? 96 : 34,
    };
    final daysPastDue = baseDelay + (index * 11);
    final prudentialStatus = _prudentialStatusForDelay(daysPastDue);
    final estimatedProvision = _estimatedProvisionAmountForExposure(exposure);
    final provisionRate =
        exposure.ead > 0 ? estimatedProvision / exposure.ead : 0.0;
    final incidents = _incidentHistory(
      exposure: exposure,
      daysPastDue: daysPastDue,
      prudentialStatus: prudentialStatus,
    );

    return CreditDefaultRecord(
      exposureId: exposure.id,
      counterpartyName: exposure.counterparty.name,
      country: exposure.counterparty.country,
      sector: _sectorFromCategory(exposure.categoryLabel),
      rating: exposure.ratingLabel,
      grossAmount: exposure.grossAmountXof,
      ead: exposure.eadXof,
      rwa: exposure.rwaXof,
      capital: exposure.capitalXof,
      daysPastDue: daysPastDue,
      prudentialStatus: prudentialStatus,
      estimatedProvision: convertCurrencyAmount(
        estimatedProvision,
        fromCurrency: exposure.currency,
        toCurrency: 'XOF',
      ),
      provisionRate: provisionRate,
      incidents: incidents,
    );
  }

  List<CreditIncidentEvent> _incidentHistory({
    required ExposureRecord exposure,
    required int daysPastDue,
    required String prudentialStatus,
  }) {
    final referenceDate = exposure.analysisDate;
    final firstDate = referenceDate.subtract(Duration(days: daysPastDue));
    final secondDate = referenceDate.subtract(
      Duration(days: math.max(5, daysPastDue ~/ 2)),
    );
    final thirdDate = referenceDate.subtract(const Duration(days: 7));
    return [
      CreditIncidentEvent(
        date: thirdDate,
        title: prudentialStatus,
        description:
            'Revue du dossier ${exposure.id} et ajustement du niveau de surveillance.',
      ),
      CreditIncidentEvent(
        date: secondDate,
        title: 'Relance client',
        description:
            'Relance formelle envoyee a ${exposure.counterparty.name} sur les echeances impayees.',
      ),
      CreditIncidentEvent(
        date: firstDate,
        title: 'Premier incident',
        description:
            'Retard detecte sur l exposition ${exposure.id} avec suivi renforcé.',
      ),
    ];
  }

  List<DistributionEntry> _distributionFromTotals(
    Map<String, double> totals,
    double globalAmount,
  ) {
    final entries = totals.entries
        .map(
          (entry) => DistributionEntry(
            label: entry.key,
            amount: entry.value,
            percentage: globalAmount == 0 ? 0.0 : entry.value / globalAmount,
          ),
        )
        .toList()
      ..sort((left, right) => right.amount.compareTo(left.amount));
    return entries;
  }

  double _defaultRiskScore(ExposureRecord exposure) {
    var score = exposure.rwaXof;
    if (exposure.isDefaultLike) {
      score += 250000000;
    }
    if (exposure.ratingLabel == 'BB/B') {
      score += 180000000;
    }
    if (exposure.crmModeLabel == 'Aucune') {
      score += 60000000;
    }
    score += exposure.finalRw * 10000000;
    return score;
  }

  bool _isExpired(DateTime expirationDate, DateTime now) {
    final baseline = DateTime(now.year, now.month, now.day);
    return expirationDate.isBefore(baseline);
  }

  String _resolveGuaranteeStatus(DateTime expirationDate) {
    final now = DateTime.now();
    if (_isExpired(expirationDate, now)) {
      return 'Expiree';
    }
    if (expirationDate.difference(now).inDays <= 90) {
      return 'A renouveler';
    }
    return 'Active';
  }

  String _prudentialStatusForDelay(int daysPastDue) {
    if (daysPastDue >= 90) {
      return 'Defaut prudentiel';
    }
    if (daysPastDue >= 60) {
      return 'Sous surveillance renforcee';
    }
    if (daysPastDue >= 30) {
      return 'Surveillance';
    }
    return 'Pre-alerte';
  }

  String _sectorFromCategory(String category) {
    final normalized = category
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a');
    if (normalized.contains('souverain') ||
        normalized.contains('organismes pub')) {
      return 'Secteur public';
    }
    if (normalized.contains('institution')) {
      return 'Interbancaire';
    }
    if (normalized.contains('entreprise')) {
      return 'Corporate';
    }
    if (normalized.contains('detail')) {
      return 'Retail';
    }
    if (normalized.contains('immo')) {
      return 'Immobilier';
    }
    if (normalized.contains('souffrance')) {
      return 'Defaut';
    }
    return 'Autres';
  }

  String _nextGuaranteeId() {
    final existingIds = <String>[
      ..._customGuarantees.map((item) => item.id),
      ..._editedGuarantees.keys,
    ];
    var max = 0;
    for (final id in existingIds) {
      if (!id.startsWith('GAR')) {
        continue;
      }
      final parsed = int.tryParse(id.substring(3));
      if (parsed != null && parsed > max) {
        max = parsed;
      }
    }
    return 'GAR${(max + 1).toString().padLeft(3, '0')}';
  }

  String _number(double value) => value.toStringAsFixed(0);
  String _percent(double value) => '${(value * 100).toStringAsFixed(2)}%';
}

class _ConcentrationAccumulator {
  _ConcentrationAccumulator({required this.label});

  final String label;
  var exposureCount = 0;
  var grossAmount = 0.0;
  var ead = 0.0;
  var rwa = 0.0;
  var sector = 'Non renseigné';
  var country = 'Non renseigné';

  void add(
    ExposureRecord exposure, {
    required String sector,
    required String country,
  }) {
    exposureCount += 1;
    grossAmount += exposure.grossAmountXof;
    ead += exposure.eadXof;
    rwa += exposure.rwaXof;
    if (this.sector == 'Non renseigné' || this.sector.isEmpty) {
      this.sector = sector;
    }
    if (this.country == 'Non renseigné' || this.country.isEmpty) {
      this.country = country;
    }
  }

  double get averageRiskWeight => ead == 0 ? 0.0 : rwa / ead;
}
