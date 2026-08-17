import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import 'dashboard_design.dart';

/// Jauge de conformité « grands risques » - plus forte exposition vs limite.
///
/// Zones de la jauge = couleurs de statut institutionnelles (conforme / sous
/// surveillance / dépassement). Aiguille et chiffres en encre.
class DashboardComplianceGauge extends StatelessWidget {
  const DashboardComplianceGauge({super.key});

  // Données : plus forte exposition en % des fonds propres.
  static const double _value = 31.7;
  static const double _limit = 25.0;
  static const double _alerteInterne = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    const depassement = _value - _limit;
    final valueColor = _value >= _limit
        ? c.sousMinimum
        : _value >= _alerteInterne
            ? c.sousCible
            : c.conforme;

    return DashPanel(
      height: 280,
      title: 'Conformité grands risques - plus forte exposition'.tr(context),
      unit: 'En % des fonds propres'.tr(context),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: SizedBox(
                width: 180,
                height: 130,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 6,
                      child: CustomPaint(
                        size: const Size(160, 90),
                        painter: _GaugePainter(value: _value, colors: c),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_value.toStringAsFixed(1).replaceAll('.', ',')}%',
                            style: DashText.hero(c, size: 26, color: valueColor),
                          ),
                          const SizedBox(height: 4),
                          Text('Plus forte exposition'.tr(context),
                              style: DashText.caption(c)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LIMITE RÉGLEMENTAIRE'.tr(context),
                    style: DashText.eyebrow(c, color: c.faint)),
                const SizedBox(height: 4),
                Text('${_limit.toInt()}%', style: DashText.hero(c, size: 22)),
                const SizedBox(height: 16),
                _AlertLine(
                  colors: c,
                  color: c.sousMinimum,
                  label: 'Dépassement',
                  value:
                      '+${depassement.toStringAsFixed(1).replaceAll('.', ',')} pts',
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr("Seuil d'alerte interne : {{value}}%", args: {'value': _alerteInterne.toInt()}),
                  style: DashText.caption(c, color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertLine extends StatelessWidget {
  const _AlertLine({
    required this.colors,
    required this.color,
    required this.label,
    required this.value,
  });

  final DashColors colors;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.tr(context),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: DashText.value(colors, color: color, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value, required this.colors});

  final double value;
  final DashColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;

    // 0–20 % conforme, 20–25 % sous surveillance, 25–50 % dépassement.
    canvas.drawArc(rect, math.pi, 0.4 * math.pi, false, arc(colors.conforme));
    canvas.drawArc(rect, math.pi + 0.4 * math.pi, 0.1 * math.pi, false,
        arc(colors.sousCible));
    canvas.drawArc(rect, math.pi + 0.5 * math.pi, 0.5 * math.pi, false,
        arc(colors.sousMinimum));

    // Aiguille.
    final ratio = (value / 50.0).clamp(0.0, 1.0);
    final angle = math.pi + ratio * math.pi;
    final needleLength = radius - 6;
    final needlePaint = Paint()
      ..color = colors.ink
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx + needleLength * math.cos(angle),
          center.dy + needleLength * math.sin(angle)),
      needlePaint,
    );
    canvas.drawCircle(center, 5, Paint()..color = colors.ink);

    _tick(canvas, center, radius + 14, math.pi, '0', colors.faint);
    _tick(canvas, center, radius + 14, math.pi + 0.4 * math.pi, '20',
        colors.faint);
    _tick(canvas, center, radius + 16, math.pi + 0.5 * math.pi, '25',
        colors.faint);
    _tick(canvas, center, radius + 14, math.pi + math.pi, '50', colors.faint);
  }

  void _tick(Canvas canvas, Offset center, double r, double angle, String text,
      Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx + r * math.cos(angle) - tp.width / 2,
          center.dy + r * math.sin(angle) - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.colors != colors;
}
