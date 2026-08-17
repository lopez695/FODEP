import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardRwaDonut extends StatefulWidget {
  const DashboardRwaDonut({super.key, this.currency = 'XOF', required this.data});

  final String currency;
  final DashboardSnapshot data;

  @override
  State<DashboardRwaDonut> createState() => _DashboardRwaDonutState();
}

class _DashboardRwaDonutState extends State<DashboardRwaDonut> {

  DashboardMetric _metric(String key) {
    return widget.data.metrics.firstWhere((m) => m.key == key, orElse: () => DashboardMetric(key: key, label: '', value: 0.0, variation: '', trend: []));
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    final scale = 1.0 / amountUnit.divisor;

    // RWA Data from explicit metrics
    final creditRawXof = _metric('rwa_credit').value;
    final operationnelRawXof = _metric('rwa_op').value;
    final marcheRawXof = _metric('rwa_market').value;

    // Convert to requested currency, then scale to the display unit (M/Md).
    final credit = convertCurrencyAmount(creditRawXof, fromCurrency: 'XOF', toCurrency: widget.currency) * scale;
    final operationnel = convertCurrencyAmount(operationnelRawXof, fromCurrency: 'XOF', toCurrency: widget.currency) * scale;
    final marche = convertCurrencyAmount(marcheRawXof, fromCurrency: 'XOF', toCurrency: widget.currency) * scale;
    
    final total = credit + operationnel + marche;

    return DashPanel(
      title: 'RWA TOTAL ET CAPITAL REQUIS'.tr(context),
      unit: context.tr('En {{unit}} ({{currency}})', args: {'unit': amountUnit.label, 'currency': widget.currency}),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RWA TOTAL'.tr(context),
                style: DashText.eyebrow(c, color: Colors.indigo.shade500).copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text.rich(
                  TextSpan(
                    text: AppFormatters.compactNumber(total),
                    children: [
                      TextSpan(
                        text: amountUnit.label,
                        style: TextStyle(fontSize: 16, color: c.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.ink),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Divider(height: 1, thickness: Dash.hairline, color: c.divider),
          const SizedBox(height: 32),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CAPITAL MINIMUM REQUIS (9%)'.tr(context),
                style: DashText.eyebrow(c, color: Colors.indigo.shade500).copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text.rich(
                  TextSpan(
                    text: AppFormatters.compactNumber(total * 0.09),
                    children: [
                      TextSpan(
                        text: amountUnit.label,
                        style: TextStyle(fontSize: 16, color: c.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.ink),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
