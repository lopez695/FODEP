import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardTop10RisquesChart extends StatelessWidget {
  const DashboardTop10RisquesChart({
    super.key,
    required this.exposures,
    required this.currency,
  });

  final List<TopExposure> exposures;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    final scale = 1000000000 / amountUnit.divisor;

    // Outil prudentiel : aucune donnée fictive. Sans exposition réelle, le
    // graphique affiche un état vide explicite au lieu d'un jeu de démonstration.
    final data = exposures;
    if (data.isEmpty) {
      return DashPanel(
        title: 'RÉPARTITION PAR SECTEUR',
        unit: 'En ${amountUnit.label} ($currency)',
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'Aucune exposition à afficher',
              style: TextStyle(
                color: c.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    // Group Top 10 exposures by sector
    final sectorTotals = <String, double>{};
    for (final exp in data) {
      sectorTotals[exp.sector] = (sectorTotals[exp.sector] ?? 0) + exp.exposureAmount;
    }

    // Sort by amount descending
    final sortedSectors = sectorTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Limit to top 5 sectors for better display
    final displaySectors = sortedSectors.take(5).toList();

    // Determine max X for chart scaling
    double maxAmount = 0;
    if (displaySectors.isNotEmpty) {
      maxAmount = displaySectors.map((e) => (e.value / 1000000000) * scale).reduce((a, b) => a > b ? a : b);
    }
    // Add 20% padding to max X
    final maxX = maxAmount * 1.2;

    return DashPanel(
      title: 'RÉPARTITION PAR SECTEUR'.tr(context),
      unit: context.tr('En {{unit}} ({{currency}})', args: {'unit': amountUnit.label, 'currency': currency}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxX,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFFFEFEFE),
                    tooltipBorder: BorderSide(color: c.navy.withValues(alpha: 0.2), width: 1),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final sectorLabel = displaySectors[groupIndex].key.tr(context);
                      return BarTooltipItem(
                        '$sectorLabel\n',
                        TextStyle(
                          color: c.muted,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: '────────────────\n',
                            style: TextStyle(
                              color: c.muted.withValues(alpha: 0.3),
                              fontSize: 8,
                              height: 0.4,
                            ),
                          ),
                          TextSpan(
                            text: '${AppFormatters.compactNumber(rod.toY)} ${amountUnit.label} ($currency)',
                            style: TextStyle(
                              color: c.navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= displaySectors.length) return const SizedBox.shrink();
                        
                        final label = displaySectors[index].key.replaceFirst(RegExp(r'^\([a-z]\)\s*'), '');

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: SizedBox(
                            width: 80,
                            child: Text(
                              label.tr(context),
                              style: TextStyle(
                                color: c.navy,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 70,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == maxX) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text(
                            AppFormatters.compactNumber(value),
                            style: TextStyle(color: c.muted, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: c.divider, width: 1.5),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxX > 0 ? maxX / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: c.divider,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                barGroups: List.generate(displaySectors.length, (index) {
                  final amount = (displaySectors[index].value / 1000000000) * scale;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: amount,
                        width: 24,
                        color: c.ramp[index % c.ramp.length],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
