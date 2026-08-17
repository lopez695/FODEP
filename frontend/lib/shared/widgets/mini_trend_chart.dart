// Ce fichier dessine un mini graphique simple pour les cartes KPI.
import 'package:flutter/material.dart';

/// Petit graphique de tendance utilisé dans les cartes KPI.
class MiniTrendChart extends StatelessWidget {
  const MiniTrendChart({
    super.key,
    required this.values,
    required this.color,
  });

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 68,
        height: 28,
        child: CustomPaint(
          painter: _MiniTrendPainter(values: values, color: color),
        ),
      ),
    );
  }
}

/// Painter interne qui trace la courbe de tendance miniature.
class _MiniTrendPainter extends CustomPainter {
  const _MiniTrendPainter({
    required this.values,
    required this.color,
  });

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final fillPath = Path();

    for (var index = 0; index < values.length; index++) {
      final dx =
          index / (values.length - 1 == 0 ? 1 : values.length - 1) * size.width;
      final dy =
          size.height - ((values[index] - minValue) / span * size.height);
      if (index == 0) {
        path.moveTo(dx, dy);
        fillPath.moveTo(dx, size.height);
        fillPath.lineTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
        fillPath.lineTo(dx, dy);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniTrendPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
