// Ce fichier assemble le dashboard RWA a partir de composants modulaires.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../models/dashboard_models.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_charts_section.dart';
import '../widgets/dashboard_top_metrics_grid.dart';

/// Ecran principal de pilotage des RWA et du capital.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// Etat interne qui charge et rafraîchit les données du dashboard.
class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardSnapshot> _future;
  StreamSubscription<int>? _portfolioRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _future = _loadDashboard();
    _portfolioRefreshSubscription =
        widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _future = _loadDashboard();
      });
    });
  }

  @override
  void dispose() {
    _portfolioRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<DashboardSnapshot> _loadDashboard() {
    return widget.api.fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              context.tr('Erreur: {{error}}', args: {'error': snapshot.error}),
            ),
          );
        }

        final data = snapshot.data!;
        final displayCurrency = PortfolioCurrencyScope.of(context);
        final metrics = {
          for (final metric in data.metrics) metric.key: metric,
        };
        final double rwaCredit = data.portfolioOverview.fold(0.0, (sum, row) => sum + row.rwa);
        final rwaMetric = DashboardMetric(key: 'rwa', label: 'RWA crédit', value: rwaCredit, variation: '', trend: []);
        final grossMetric = _metric(metrics, 'encours');
        final defaultRateMetric = _metric(metrics, 'taux_defaut');
        // Exigence du seul risque de crédit, dérivée du même RWA que la tuile
        // voisine : les deux tuiles restent cohérentes entre elles quel que
        // soit l'état du snapshot serveur. L'exigence totale (marché et
        // opérationnel compris) reste servie par « capital_requis ».
        final capitalMetric = DashboardMetric(
          key: 'capital_credit',
          label: 'Capital min. requis (crédit)',
          value: rwaCredit * 0.09,
          variation: '',
          trend: const [],
        );
        final residualRiskMetric = _metric(metrics, 'risque_residuel');
        final crmMetric = _metric(metrics, 'crm');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                AppTheme.pagePadding,
                AppTheme.pagePadding,
                0,
              ),
              child: DashboardHeader(
                onReload: () {
                  setState(() {
                    _future = widget.api.fetchDashboard(forceRefresh: true);
                  });
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  AppTheme.pagePadding,
                  AppTheme.pagePadding,
                  AppTheme.pagePadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashboardTopMetricsGrid(
                      grossMetric: grossMetric,
                      rwaMetric: rwaMetric,
                      capitalMetric: capitalMetric,
                      residualRiskMetric: residualRiskMetric,
                      defaultRateMetric: defaultRateMetric,
                      exposuresCount: data.portfolioOverview.length,
                    ),
                    const SizedBox(height: AppTheme.pageGap),
                    Builder(
                      builder: (context) {
                        // Recompute counts locally from the portfolio overview
                        final crmCounts = <String, int>{};
                        int totalFound = 0;
                        for (final row in data.portfolioOverview) {
                          final normalized = row.crmType.toLowerCase();
                          String label;
                          if (normalized.contains('aucune') || normalized.contains('sans crm')) {
                            label = 'AUCUNE GARANTIE';
                          } else if (normalized.contains('non') && normalized.contains('financ')) {
                            label = 'GARANTIE NON FINANCÉE';
                          } else if (normalized.contains('cash') || normalized.contains('financ')) {
                            label = 'GARANTIE FINANCÉE';
                          } else {
                            label = 'GARANTIE NON FINANCÉE';
                          }
                          crmCounts[label] = (crmCounts[label] ?? 0) + 1;
                          totalFound++;
                        }

                        final enrichedCrmEntries = data.crmDistribution.map((e) {
                          final normalizedLabel = e.label.toLowerCase();
                          String displayLabel;
                          if (normalizedLabel.contains('aucune') || normalizedLabel.contains('sans crm')) {
                            displayLabel = 'AUCUNE GARANTIE';
                          } else if (normalizedLabel.contains('non') && normalizedLabel.contains('financ')) {
                            displayLabel = 'GARANTIE NON FINANCÉE';
                          } else if (normalizedLabel.contains('cash') || normalizedLabel.contains('financ')) {
                            displayLabel = 'GARANTIE FINANCÉE';
                          } else {
                            displayLabel = e.label.toUpperCase();
                          }

                          // If portfolioOverview was empty, fallback to e.count
                          final finalCount = totalFound > 0 ? (crmCounts[displayLabel] ?? 0) : (e.count ?? 0);

                          return DistributionEntry(
                            label: displayLabel,
                            amount: e.amount,
                            percentage: e.percentage,
                            count: finalCount,
                          );
                        }).toList();

                        return DashboardChartsSection(
                          displayCurrency: displayCurrency,
                          grossCategoryEntries: data.categoryDistribution,
                          rwaCategoryEntries: data.rwaCategoryDistribution,
                          crmEntries: enrichedCrmEntries,
                          portfolioOverview: data.portfolioOverview,
                          coveredRatio: grossMetric.value > 0
                              ? crmMetric.value / grossMetric.value
                              : 0.0,
                        );
                      }
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

DashboardMetric _metric(Map<String, DashboardMetric> metrics, String key) {
  return metrics[key] ??
      DashboardMetric(
        key: key,
        label: key,
        value: 0,
        variation: '+0.0%',
        trend: const [0, 0, 0, 0],
      );
}

