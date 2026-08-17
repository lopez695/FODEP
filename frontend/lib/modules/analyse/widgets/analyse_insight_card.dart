// Widget de carte d'insights et observations.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../models/analyse_models.dart';

/// Carte affichant des insights et observations.
class AnalyseInsightCard extends StatelessWidget {
  const AnalyseInsightCard({
    super.key,
    required this.title,
    required this.insights,
  });

  final String title;
  final List<AnalyseInsight> insights;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

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
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkText : AppTheme.text,
            ),
          ),
          AppSpacing.gapMd,
          ...insights.asMap().entries.map((entry) {
            final isLast = entry.key == insights.length - 1;
            return _InsightItem(
              insight: entry.value,
              showDivider: !isLast,
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  const _InsightItem({
    required this.insight,
    required this.showDivider,
    required this.isDark,
  });

  final AnalyseInsight insight;
  final bool showDivider;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final severityColor = _getSeverityColor(insight.severity);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                insight.icon,
                size: 18,
                color: severityColor,
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkText : AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.recommendation,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          AppSpacing.gapMd,
          const Divider(height: 1),
          AppSpacing.gapMd,
        ],
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppColors.alertCritical;
      case 'high':
        return AppColors.alertHigh;
      case 'medium':
        return AppColors.alertMedium;
      case 'low':
        return AppColors.alertLow;
      default:
        return AppColors.alertInfo;
    }
  }
}
