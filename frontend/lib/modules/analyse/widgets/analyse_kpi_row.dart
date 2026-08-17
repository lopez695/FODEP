// Widget d'affichage des KPIs d'analyse.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../models/analyse_models.dart';

/// Ligne de KPIs pour le module d'analyse.
class AnalyseKpiRow extends StatelessWidget {
  const AnalyseKpiRow({
    super.key,
    required this.kpis,
  });

  final List<AnalyseKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: kpis.asMap().entries.map((entry) {
        final index = entry.key;
        final kpi = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < kpis.length - 1 ? AppSpacing.md : 0,
            ),
            child: _KpiCard(kpi: kpi),
          ),
        );
      }).toList(),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final AnalyseKpi kpi;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kpi.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  kpi.icon,
                  size: 20,
                  color: kpi.color,
                ),
              ),
              const Spacer(),
              _buildTrendIndicator(kpi.trend, isDark),
            ],
          ),
          AppSpacing.gapMd,
          Text(
            kpi.label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkMuted : AppTheme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          AppSpacing.gapXs,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                kpi.value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkText : AppTheme.text,
                ),
              ),
              if (kpi.suffix != null) ...[
                const SizedBox(width: 2),
                Text(
                  kpi.suffix!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(String trend, bool isDark) {
    IconData icon;
    Color color;

    switch (trend.toLowerCase()) {
      case 'up':
        icon = Icons.arrow_upward;
        color = AppColors.success;
        break;
      case 'down':
        icon = Icons.arrow_downward;
        color = AppColors.danger;
        break;
      default:
        icon = Icons.remove;
        color = isDark ? AppTheme.darkMuted : AppTheme.muted;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}
