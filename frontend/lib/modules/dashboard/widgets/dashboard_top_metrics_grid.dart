import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardTopMetricsGrid extends StatelessWidget {
  const DashboardTopMetricsGrid({
    super.key,
    required this.grossMetric,
    required this.rwaMetric,
    required this.capitalMetric,
    required this.residualRiskMetric,
    required this.defaultRateMetric,
    required this.exposuresCount,
  });

  final DashboardMetric grossMetric;
  final DashboardMetric rwaMetric;
  final DashboardMetric capitalMetric;
  final DashboardMetric residualRiskMetric;
  final DashboardMetric defaultRateMetric;
  final int exposuresCount;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MinimalMetricCard(
        label: 'Exposition brute'.tr(context),
        value: grossMetric.value,
        isCurrency: true,
        subtitle: context.tr('Nombre d\'expositions : {{count}}', args: {'count': exposuresCount}),
      ),
      _MinimalMetricCard(
        label: 'RWA Crédit'.tr(context),
        value: rwaMetric.value,
        isCurrency: true,
        subtitle: 'EAD × RW (Taux de pondération)'.tr(context),
      ),
      _MinimalMetricCard(
        label: 'Capital min. requis (crédit)'.tr(context),
        value: capitalMetric.value,
        isCurrency: true,
        subtitle: 'RWA Crédit × 9%'.tr(context),
      ),
      _MinimalMetricCard(
        label: 'Risque résiduel'.tr(context),
        value: residualRiskMetric.value,
        isCurrency: true,
        subtitle: 'Exposition brute - Sûretés/Garanties'.tr(context),
      ),

      _MinimalMetricCard(
        label: 'Non-Performing Loans (NPL)'.tr(context),
        value: defaultRateMetric.value * 100,
        isCurrency: false,
        subtitle: 'Prêts en défaut / Total des prêts'.tr(context),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
      children: cards.asMap().entries.map((entry) {
        final isLast = entry.key == cards.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 12.0),
            child: entry.value,
          ),
        );
      }).toList(),
      ),
    );
  }
}

class _MinimalMetricCard extends StatefulWidget {
  const _MinimalMetricCard({
    required this.label,
    required this.value,
    required this.isCurrency,
    this.subtitle,
  });

  final String label;
  final double value;
  final bool isCurrency;
  final String? subtitle;

  @override
  State<_MinimalMetricCard> createState() => _MinimalMetricCardState();
}

class _MinimalMetricCardState extends State<_MinimalMetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    
    String formattedValue;
    String suffix = '';
    
    if (widget.isCurrency) {
      final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
      formattedValue = AppFormatters.decimalNumber(widget.value / amountUnit.divisor, maxDecimals: 2);
      suffix = amountUnit.label;
    } else {
      formattedValue = AppFormatters.fixedDecimalNumber(widget.value, decimals: 2);
      suffix = '%';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 130,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Dash.radius),
          border: Border.all(
            color: _isHovered ? Colors.indigo.shade300 : c.border,
            width: 1.0,
          ),
        ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label.toUpperCase(),
            style: DashText.eyebrow(c, color: Colors.indigo).copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Divider(color: c.border, thickness: Dash.hairline, height: 1),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formattedValue,
                style: DashText.hero(c, size: 20),
              ),
              if (suffix.isNotEmpty) ...[
                Text(
                  suffix,
                  style: DashText.caption(c, color: c.muted).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ]
            ],
          ),
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            const Spacer(),
            Text(
              widget.subtitle!,
              style: DashText.caption(c, color: c.muted).copyWith(
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          ],
        ),
      ),
    );
  }
}
