import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/utils/currency_conversion.dart';

class RegulatoryRatioSpec {
  const RegulatoryRatioSpec({
    required this.label,
    required this.value,
    required this.minimum,
    required this.capitalRequired,
  });

  final String label;
  final double value;
  final double minimum;
  final double capitalRequired;
}

class DashboardRegulatoryRatios extends StatelessWidget {
  const DashboardRegulatoryRatios({
    super.key,
    required this.ratios,
    required this.displayCurrency,
  });

  final List<RegulatoryRatioSpec> ratios;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Ratios Réglementaires & Capital Requis'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 24),
          ...ratios.map((r) => _buildRatioRow(context, r, isDark, textColor)),
        ],
      ),
    );
  }

  Widget _buildRatioRow(BuildContext context, RegulatoryRatioSpec ratio,
      bool isDark, Color textColor) {
    final isBreached = ratio.value < ratio.minimum;
    final barColor = isBreached ? Colors.redAccent : Colors.teal;
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final String capReqFormatted = formatCurrencyForDisplay(
      ratio.capitalRequired,
      toCurrency: displayCurrency,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ratio.label.tr(context),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                context.tr('Cap. Requis: {{value}}', args: {'value': capReqFormatted}),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: mutedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor:
                    (ratio.value / 0.20).clamp(0.0, 1.0), // Scale max to 20%
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Actuel: {{value}}%', args: {'value': (ratio.value * 100).toStringAsFixed(2)}),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isBreached ? Colors.redAccent : textColor,
                ),
              ),
              Text(
                context.tr('Min. exigé: {{value}}%', args: {'value': (ratio.minimum * 100).toStringAsFixed(2)}),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
