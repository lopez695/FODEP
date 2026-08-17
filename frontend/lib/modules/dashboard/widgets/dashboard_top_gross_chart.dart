import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_chart_tooltip.dart';
import 'dashboard_design.dart';
import 'dashboard_theme.dart';

String _cleanLabel(String label) {
  final cleaned = label.replaceAll(RegExp(r'^\([a-zA-Z]\)\s*'), '');
  if (cleaned.isEmpty) return cleaned;
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

const List<Color> _barColors = [
  Color(0xFF1E3A5F), // Indigo 900 (deepblue)
  Color(0xFF3F51B5), // Indigo 500 (indigo)
  Color(0xFF2196F3), // Blue 500 (bleu)
  Color(0xFF64B5F6), // Blue 300 (clair)
  Color(0xFF90CAF9), // Blue 200 (très clair)
];

class DashboardTopGrossChart extends StatelessWidget {
  const DashboardTopGrossChart({
    super.key,
    required this.entries,
    this.displayCurrency = 'XOF',
    this.trailing,
    this.exposureCounts,
  });

  final List<DistributionEntry> entries;
  final String displayCurrency;
  final Widget? trailing;

  /// Nombre d'expositions par catégorie (clé = libellé brut de l'entrée),
  /// affiché dans l'infobulle de survol quand il est connu.
  final Map<String, int>? exposureCounts;

  @override
  Widget build(BuildContext context) {
    final top5 = entries.take(5).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: top5.asMap().entries.map((mapEntry) {
        final index = mapEntry.key;
        final entry = mapEntry.value;
        final isLast = entry == top5.last;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0),
          child: _HorizontalBarItem(
            entry: entry,
            currency: displayCurrency,
            color: _barColors[index % _barColors.length],
            count: exposureCounts?[entry.label],
          ),
        );
      }).toList(),
    );
  }
}

class _HorizontalBarItem extends StatefulWidget {
  const _HorizontalBarItem({
    required this.entry,
    required this.currency,
    required this.color,
    this.count,
  });

  final DistributionEntry entry;
  final String currency;
  final Color color;
  final int? count;

  @override
  State<_HorizontalBarItem> createState() => _HorizontalBarItemState();
}

class _HorizontalBarItemState extends State<_HorizontalBarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final percentage = widget.entry.percentage * 100;
    
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    final valScaled = widget.entry.amount / amountUnit.divisor;
    final decimals = valScaled >= 1000 ? 0 : 2;
    final formattedAmount = AppFormatters.decimalNumber(valScaled, maxDecimals: decimals);
    final suffix = amountUnit.label;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: DashChartTooltip(
        title: dashboardExposureFullLabel(widget.entry.label),
        lines: [
          context.tr('Part: {{value}}%', args: {
            'value': AppFormatters.decimalNumber(percentage, maxDecimals: 2),
          }),
          context.tr('Exposition totale: {{value}}', args: {
            'value': '$formattedAmount $suffix',
          }),
          if (widget.count != null)
            context.tr('{{count}} expositions', args: {'count': widget.count}),
        ],
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _cleanLabel(widget.entry.label).tr(context),
                  style: DashText.caption(c, color: _isHovered ? widget.color : const Color(0xFF1E3A8A)).copyWith(fontWeight: FontWeight.w600, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$formattedAmount $suffix',
                style: DashText.caption(c, color: _isHovered ? widget.color : const Color(0xFF1E3A8A)).copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                textAlign: TextAlign.right,
                maxLines: 1,
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedScale(
            scale: _isHovered ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            alignment: Alignment.centerLeft,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final barWidth = maxWidth * widget.entry.percentage;
                
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      width: barWidth,
                      height: 16,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.zero,
                        boxShadow: _isHovered ? [BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))] : [],
                      ),
                    ),
                    Positioned(
                      left: (barWidth + 45 > maxWidth) ? null : barWidth + 6,
                      right: (barWidth + 45 > maxWidth) ? 6 : null,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Text(
                          '${AppFormatters.decimalNumber(percentage, maxDecimals: 1)}%',
                          style: DashText.caption(c, color: const Color(0xFF1E3A8A)).copyWith(fontWeight: FontWeight.w700, fontSize: 9.5),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}
