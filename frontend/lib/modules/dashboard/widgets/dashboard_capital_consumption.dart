import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardCapitalConsumption extends StatelessWidget {
  const DashboardCapitalConsumption({super.key, this.currency = 'XOF', this.data});

  final String currency;
  final DashboardSnapshot? data;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);

    // Aucune valeur de démonstration : sans données, la tuile affiche zéro
    // plutôt que des montants inventés qui passeraient pour réels.
    double capitalRequisXof = 0;
    double capitalDetenuXof = 0;
    double solvabilite = 0;

    if (data != null && data!.metrics.isNotEmpty) {
      double metric(String key) =>
          data!.metrics
              .firstWhere(
                (m) => m.key == key,
                orElse: () => DashboardMetric(
                    key: key, label: key, value: 0, variation: '', trend: const []),
              )
              .value;

      // Exigence réglementaire d'un côté, fonds propres effectivement détenus
      // de l'autre. Les confondre - ou déduire les fonds propres de
      // « solvabilité × RWA », qui les redonne à l'arrondi près - affichait un
      // excédent systématiquement nul.
      capitalRequisXof = metric('capital_requis');
      capitalDetenuXof = metric('capital');
      solvabilite = metric('solvabilite');
    }

    // Convert to requested currency and scale to unit
    final capitalDetenu = convertCurrencyAmount(capitalDetenuXof, fromCurrency: 'XOF', toCurrency: currency) / amountUnit.divisor;
    final capitalRequis = convertCurrencyAmount(capitalRequisXof, fromCurrency: 'XOF', toCurrency: currency) / amountUnit.divisor;
    final excedent = capitalDetenu - capitalRequis;
    
    // Status color
    final isSafe = solvabilite >= 0.09;
    final statusColor = isSafe ? c.conforme : c.sousMinimum;

    return DashPanel(
      title: 'RATIO DE SOLVABILITÉ'.tr(context),
      unit: context.tr('En {{unit}} ({{currency}})', args: {'unit': amountUnit.label, 'currency': currency}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _buildMetricRow('Fonds propres (Capital détenu)'.tr(context), capitalDetenu, c.navy, c, amountUnit.label),
          const SizedBox(height: 12),
          _buildMetricRow('Exigence minimale (9%)'.tr(context), capitalRequis, c.ink, c, amountUnit.label),
          const SizedBox(height: 12),
          _buildMetricRow('Coussin de sécurité (Excédent)'.tr(context), excedent, excedent >= 0 ? c.conforme : c.sousMinimum, c, amountUnit.label, showPlus: true),
          const SizedBox(height: 16),

          // Ratio display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ratio de Solvabilité global'.tr(context), style: TextStyle(fontSize: 13, color: c.muted, fontWeight: FontWeight.w600)),
              Text(
                AppFormatters.percent(solvabilite),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Jauge de Solvabilité (Target: 9%, Max displayed: 20%)
          Stack(
            children: [
              // Fond
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              // Barre remplie (Capped at 20% for visual scale)
              FractionallySizedBox(
                widthFactor: (solvabilite / 0.20).clamp(0.0, 1.0),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              // Ligne de l'exigence minimale (9%)
              Positioned(
                left: 0,
                right: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (0.09 / 0.20).clamp(0.0, 1.0),
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 2,
                      height: 12,
                      color: c.ink, // Black tick mark for the 9% target
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: TextStyle(fontSize: 11, color: c.muted)),
              Text('Min: 9%'.tr(context), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.ink)),
              Text('20%+', style: TextStyle(fontSize: 11, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, double amount, Color color, DashColors c, String unitLabel, {bool showPlus = false}) {
    final prefix = (showPlus && amount > 0) ? '+' : '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.muted, fontWeight: FontWeight.w500)),
        Text(
          '$prefix${AppFormatters.integer(amount)} $unitLabel',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
