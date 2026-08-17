// Ce fichier dessine un graphique circulaire simple.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../modules/dashboard/models/dashboard_models.dart';

/// Donut chart simplifié pour les répartitions rapides.
class SimpleDonutChart extends StatelessWidget {
  const SimpleDonutChart({
    super.key,
    required this.entries,
    required this.palette,
  });

  final List<DistributionEntry> entries;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: _DonutPainter(entries: entries, palette: palette),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((item) {
              final color = palette[item.key % palette.length];
              final entry = item.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(child: Text(entry.label)),
                    Text(
                      AppFormatters.percent(entry.percentage),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Painter interne chargé de dessiner le donut chart.
class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.entries,
    required this.palette,
  });

  final List<DistributionEntry> entries;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.width * 0.18;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    var startAngle = -math.pi / 2;
    for (var index = 0; index < entries.length; index++) {
      paint.color = palette[index % palette.length];
      final sweepAngle = entries[index].percentage * math.pi * 2;
      canvas.drawArc(
          rect.deflate(strokeWidth / 2), startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.palette != palette;
  }
}
