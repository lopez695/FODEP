import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../models/dashboard_models.dart';
import 'dashboard_crm_donut.dart';
import 'dashboard_design.dart';
import 'dashboard_top_gross_chart.dart';
import 'dashboard_top_rwa_chart.dart';

class DashboardChartsSection extends StatefulWidget {
  const DashboardChartsSection({
    super.key,
    required this.displayCurrency,
    required this.grossCategoryEntries,
    required this.rwaCategoryEntries,
    required this.crmEntries,
    required this.coveredRatio,
    required this.portfolioOverview,
  });

  final String displayCurrency;
  final List<DistributionEntry> grossCategoryEntries;
  final List<DistributionEntry> rwaCategoryEntries;
  final List<DistributionEntry> crmEntries;
  final double coveredRatio; // Kept for API compatibility
  final List<PortfolioRow> portfolioOverview;

  @override
  State<DashboardChartsSection> createState() => _DashboardChartsSectionState();
}

class _DashboardChartsSectionState extends State<DashboardChartsSection> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Nombre d'expositions par catégorie : les entrées des deux Top 5
        // sont agrégées côté serveur sur ce même libellé de catégorie.
        final exposureCounts = <String, int>{};
        for (final row in widget.portfolioOverview) {
          exposureCounts[row.category] = (exposureCounts[row.category] ?? 0) + 1;
        }

        final grossContent = DashboardTopGrossChart(
          key: const ValueKey('grossChart'),
          entries: widget.grossCategoryEntries,
          displayCurrency: widget.displayCurrency,
          exposureCounts: exposureCounts,
        );

        final rwaContent = DashboardTopRwaChart(
          key: const ValueKey('rwaChart'),
          entries: widget.rwaCategoryEntries,
          displayCurrency: widget.displayCurrency,
          exposureCounts: exposureCounts,
        );

        final donutChart = DashboardCrmDonut(
          entries: widget.crmEntries,
          portfolioOverview: widget.portfolioOverview,
        );

        final eadPanel = DashPanel(
          title: 'Top 5 de l\'EAD par catégorie'.tr(context),
          height: 360,
          child: grossContent,
        );

        final rwaPanel = DashPanel(
          title: 'Top 5 du RWA crédit par catégorie'.tr(context),
          height: 360,
          child: rwaContent,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 30,
              child: eadPanel,
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 40,
              child: rwaPanel,
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 30,
              child: donutChart,
            ),
          ],
        );
      },
    );
  }
}
