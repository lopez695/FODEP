// Ce fichier affiche une carte KPI reutilisable.
import 'package:flutter/material.dart';

import '../../core/state/portfolio_amount_unit_scope.dart';
import '../../core/state/portfolio_currency_scope.dart';
import '../../core/utils/currency_conversion.dart';
import '../../core/utils/formatters.dart';
import 'kpi_metric_card.dart';

/// Carte compacte réutilisable pour afficher une métrique et sa tendance.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.variation,
    required this.color,
    required this.icon,
    required this.trend,
    this.isPercent = false,
    this.currencyCode = 'XOF',
  });

  final String label;
  final double value;
  final String variation;
  final Color color;
  final IconData icon;
  final List<double> trend;
  final bool isPercent;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.maybeOf(
      context,
      fallback: currencyCode,
    );
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    final formattedValue = isPercent
        ? AppFormatters.percent(value)
        : formatCurrencyInDisplayUnit(
            value,
            fromCurrency: currencyCode,
            toCurrency: displayCurrency,
            amountUnit: amountUnit,
          );

    return KpiMetricCard(
      label: label,
      value: formattedValue,
      helper: variation,
      icon: icon,
      color: color,
      trend: trend,
      fullValue: formattedValue,
    );
  }
}
