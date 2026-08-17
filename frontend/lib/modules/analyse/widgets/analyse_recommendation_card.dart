// Widget de carte de recommandation actionnable.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/analyse_models.dart';

/// Carte affichant une recommandation avec actions.
class AnalyseRecommendationCard extends StatelessWidget {
  const AnalyseRecommendationCard({
    super.key,
    required this.recommendation,
  });

  final AnalyseRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _getPriorityColor(recommendation.priority);

    return Container(
      padding: AppSpacing.cardInsets,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: priorityColor.withValues(alpha: 0.3),
          width: 1.5,
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
          // En-tête avec badges
          Row(
            children: [
              Expanded(
                child: Text(
                  recommendation.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.text,
                  ),
                ),
              ),
              _buildBadge(
                'Priorité ${recommendation.priority.toUpperCase()}',
                priorityColor,
              ),
            ],
          ),
          AppSpacing.gapSm,

          // Badges d'impact et effort
          Row(
            children: [
              _buildSmallBadge(
                'Impact: ${_translateLevel(recommendation.impact)}',
                _getImpactColor(recommendation.impact),
              ),
              const SizedBox(width: 8),
              _buildSmallBadge(
                'Effort: ${_translateLevel(recommendation.effort)}',
                isDark ? AppTheme.darkMuted : AppTheme.muted,
              ),
              if (recommendation.estimatedSaving != null) ...[
                const SizedBox(width: 8),
                _buildSmallBadge(
                  'Économie: ${formatCurrencyCompact(recommendation.estimatedSaving!)}',
                  AppColors.success,
                ),
              ],
            ],
          ),
          AppSpacing.gapMd,

          // Description
          Text(
            recommendation.description,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.darkText : AppTheme.text,
              height: 1.5,
            ),
          ),
          AppSpacing.gapMd,

          // Actions
          if (recommendation.actions.isNotEmpty) ...[
            const Divider(height: 1),
            AppSpacing.gapMd,
            Text(
              'Actions recommandées:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkText : AppTheme.text,
              ),
            ),
            AppSpacing.gapSm,
            ...recommendation.actions.map((action) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkMuted : AppTheme.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.accent;
    }
  }

  Color _getImpactColor(String impact) {
    switch (impact.toLowerCase()) {
      case 'high':
        return AppColors.success;
      case 'medium':
        return AppColors.accent;
      default:
        return AppColors.warning;
    }
  }

  String _translateLevel(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return 'Élevé';
      case 'medium':
        return 'Moyen';
      case 'low':
        return 'Faible';
      default:
        return level;
    }
  }
}
