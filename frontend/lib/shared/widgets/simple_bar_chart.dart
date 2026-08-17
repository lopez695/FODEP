// Ce fichier dessine un graphique en barres simple.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../modules/dashboard/models/dashboard_models.dart';

/// Histogramme léger utilisé pour les visuels simples.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.entries,
    required this.palette,
  });

  final List<DistributionEntry> entries;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: entries.asMap().entries.map((item) {
        final entry = item.value;
        final color = palette[item.key % palette.length];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppFormatters.percent(entry.percentage),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 160.0 * (entry.percentage.clamp(0.09, 1.0)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color, color.withValues(alpha: 0.65)],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
