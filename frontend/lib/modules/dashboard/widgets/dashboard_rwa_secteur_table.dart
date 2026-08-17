import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardRwaSecteurChart extends StatelessWidget {
  const DashboardRwaSecteurChart({super.key, required this.currency, this.data});

  final String currency;
  final DashboardSnapshot? data;

  Widget _buildRiskBlock({
    required BuildContext context,
    required String title,
    required double rwa,
    required double capital,
    required double percentage,
    required Color color,
    required String currency,
    required String unitLabel,
    required DashColors c,
    double bottomMargin = 8,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.divider.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.divider.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.tr(context),
                style: TextStyle(
                  color: c.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Values Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RWA'.tr(context),
                    style: TextStyle(color: c.muted, fontSize: 9),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${AppFormatters.compactNumber(rwa)}$unitLabel',
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Capital Requis'.tr(context),
                    style: TextStyle(color: c.muted, fontSize: 9),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${AppFormatters.compactNumber(capital)}$unitLabel',
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: c.divider.withValues(alpha: 0.55),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);

    final metrics = data?.metrics;
    
    // Get RWA Credit
    final creditMetric = metrics != null && metrics.isNotEmpty
        ? metrics.firstWhere((m) => m.key == 'rwa_credit', orElse: () => const DashboardMetric(key: 'rwa_credit', label: '', value: 0.0, variation: '', trend: []))
        : null;
    final rwaCreditXof = creditMetric != null ? creditMetric.value : 0.0;

    // Get RWA Market
    final marketMetric = metrics != null && metrics.isNotEmpty
        ? metrics.firstWhere((m) => m.key == 'rwa_market', orElse: () => const DashboardMetric(key: 'rwa_market', label: '', value: 0.0, variation: '', trend: []))
        : null;
    final rwaMarketXof = marketMetric != null ? marketMetric.value : 0.0;

    // Get RWA Op
    final opMetric = metrics != null && metrics.isNotEmpty
        ? metrics.firstWhere((m) => m.key == 'rwa_op', orElse: () => const DashboardMetric(key: 'rwa_op', label: '', value: 0.0, variation: '', trend: []))
        : null;
    final rwaOpXof = opMetric != null ? opMetric.value : 0.0;

    // Total RWA
    final rwaTotalXof = rwaCreditXof + rwaMarketXof + rwaOpXof;

    // Converted values
    final rwaCredit = convertCurrencyAmount(rwaCreditXof, fromCurrency: 'XOF', toCurrency: currency) / amountUnit.divisor;
    final rwaMarket = convertCurrencyAmount(rwaMarketXof, fromCurrency: 'XOF', toCurrency: currency) / amountUnit.divisor;
    final rwaOp = convertCurrencyAmount(rwaOpXof, fromCurrency: 'XOF', toCurrency: currency) / amountUnit.divisor;
    
    final capCredit = rwaCredit * 0.09;
    final capMarket = rwaMarket * 0.09;
    final capOp = rwaOp * 0.09;

    // Percentages
    final pctCredit = rwaTotalXof > 0 ? (rwaCreditXof / rwaTotalXof) : 0.0;
    final pctMarket = rwaTotalXof > 0 ? (rwaMarketXof / rwaTotalXof) : 0.0;
    final pctOp = rwaTotalXof > 0 ? (rwaOpXof / rwaTotalXof) : 0.0;

    final creditColor = c.navy;
    const marcheColor = Color(0xFF38BDF8); // Light Sky Blue
    final opColor = c.accent;

    return DashPanel(
      title: 'EXIGENCES DE FONDS PROPRES PAR TYPE DE RISQUE'.tr(context),
      unit: context.tr('En {{unit}} ({{currency}})', args: {'unit': amountUnit.label, 'currency': currency}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _buildRiskBlock(
            context: context,
            title: 'Risque de Crédit',
            rwa: rwaCredit,
            capital: capCredit,
            percentage: pctCredit,
            color: creditColor,
            currency: currency,
            unitLabel: amountUnit.label,
            c: c,
            bottomMargin: 8,
          ),
          _buildRiskBlock(
            context: context,
            title: 'Risque Opérationnel',
            rwa: rwaOp,
            capital: capOp,
            percentage: pctOp,
            color: opColor,
            currency: currency,
            unitLabel: amountUnit.label,
            c: c,
            bottomMargin: 8,
          ),
          _buildRiskBlock(
            context: context,
            title: 'Risque de Marché',
            rwa: rwaMarket,
            capital: capMarket,
            percentage: pctMarket,
            color: marcheColor,
            currency: currency,
            unitLabel: amountUnit.label,
            c: c,
            bottomMargin: 0,
          ),
        ],
      ),
    );
  }
}
