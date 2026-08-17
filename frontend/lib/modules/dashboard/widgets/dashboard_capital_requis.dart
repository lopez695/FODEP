import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

/// Adéquation des fonds propres - graphique de points (écart au minimum).
///
/// Pour chaque compartiment : ○ capital minimal requis (exigence × RWA) vs
/// ● fonds propres détenus, sur un axe commun en Md (devise). L'écart entre les
/// deux points = le surplus de fonds propres. Pas de tableau ni de barres ;
/// registre superviseur (style EBA/ECB). Les ratios % restent dans les tuiles.
double _calculateTickStep(double maxVal, {int targetTicks = 4}) {
  if (maxVal <= 0) return 100.0;
  final rawStep = maxVal / targetTicks;
  final mag = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
  final norm = rawStep / mag;
  
  double niceNorm;
  if (norm < 1.5) {
    niceNorm = 1.0;
  } else if (norm < 3) {
    niceNorm = 2.0;
  } else if (norm < 7) {
    niceNorm = 5.0;
  } else {
    niceNorm = 10.0;
  }
  return niceNorm * mag;
}

class DashboardCapitalRequis extends StatefulWidget {
  const DashboardCapitalRequis({super.key, required this.data, this.currency = 'XOF'});

  final DashboardSnapshot data;
  final String currency;

  @override
  State<DashboardCapitalRequis> createState() =>
      _DashboardCapitalRequisState();
}

class _DashboardCapitalRequisState extends State<DashboardCapitalRequis> {
  _TooltipData? _tooltip;
  int? _hoveredRow;
  int? _hoveredDotType;
  final _chartKey = GlobalKey();

  double _getWidth() {
    final rb = _chartKey.currentContext?.findRenderObject() as RenderBox?;
    return rb?.size.width ?? 500;
  }

  double _getHeight() {
    final rb = _chartKey.currentContext?.findRenderObject() as RenderBox?;
    return rb?.size.height ?? 190;
  }

  double get _rwa {
    final metric = widget.data.metrics.firstWhere((m) => m.key == 'rwa', orElse: () => const DashboardMetric(key: 'rwa', label: '', value: 0.0, variation: '', trend: []));
    return metric.value;
  }

  List<_CapLine> get _lines {
    final cet1Metric = widget.data.metrics.firstWhere((m) => m.key == 'cet1_ratio', orElse: () => const DashboardMetric(key: '', label: '', value: 0.0, variation: '', trend: []));
    final t1Metric = widget.data.metrics.firstWhere((m) => m.key == 'tier1_ratio', orElse: () => const DashboardMetric(key: '', label: '', value: 0.0, variation: '', trend: []));
    final solvMetric = widget.data.metrics.firstWhere((m) => m.key == 'solvabilite', orElse: () => const DashboardMetric(key: '', label: '', value: 0.0, variation: '', trend: []));

    // Les ratios servis par le backend sont arrondis (3 décimales de %) : les
    // reconstituer en montants (ratio × RWA) fait diverger le « Montant
    // détenu » des fonds propres réels affichés dans le panneau voisin.
    // On repart donc des montants CET1/Tier 1/FP totaux du snapshot, et on ne
    // retombe sur la métrique que si le détail des fonds propres est absent.
    final fp = widget.data.fondsPropres;
    final rwa = _rwa;
    double actuelPct(double? montant, DashboardMetric fallback) {
      if (montant != null && rwa > 0) {
        return montant / rwa * 100;
      }
      return fallback.value * 100;
    }

    return [
      _CapLine('CET1'.tr(context), base: 5.0, coussin: 2.5, actuel: actuelPct(fp?.cet1, cet1Metric)),
      _CapLine('Tier 1'.tr(context), base: 6.0, coussin: 2.5, actuel: actuelPct(fp?.tier1, t1Metric)),
      _CapLine('Solvabilité'.tr(context), base: 9.0, coussin: 2.5, actuel: actuelPct(fp?.totalFp, solvMetric)),
    ];
  }

  void _onHover(PointerHoverEvent event) {
    if (_chartKey.currentContext == null) return;
    final rb = _chartKey.currentContext!.findRenderObject() as RenderBox;
    final pos = rb.globalToLocal(event.position);

    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    final unitLabel = amountUnit.label;

    final rwaVal = convertCurrencyAmount(_rwa, fromCurrency: 'XOF', toCurrency: widget.currency) / amountUnit.divisor;
    final lines = _lines;
    if (lines.isEmpty) return;

    final maxDetenu = lines.map((l) => math.max(l.detenu(rwaVal), l.requis(rwaVal))).reduce(math.max);
    final tickStep = _calculateTickStep(maxDetenu);
    var maxAxis = (maxDetenu / tickStep).ceil() * tickStep;
    if (maxAxis <= 0) maxAxis = tickStep;

    // Mêmes marges que _DotPlotPainter pour que le survol vise exactement
    // les points dessinés.
    final plotW = _getWidth() - 85.0 - 60.0;
    const plotLeft = 85.0;
    const plotTop = 12.0;
    final plotBottom = _getHeight() - 26.0;

    double x(double v) => plotLeft + (v / maxAxis) * plotW;

    _TooltipData? found;
    int? foundRow;
    int? foundDot;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final y = plotTop + (plotBottom - plotTop) * ((i + 0.5) / lines.length);
      final xb = x(l.base * rwaVal / 100);
      final xr = x(l.requis(rwaVal));
      final xd = x(l.detenu(rwaVal));

      if ((pos.dy - y).abs() > 18) continue;

      // Même précision que le panneau « Fonds propres réglementaires »
      // (3 décimales utiles) : le montant détenu doit se lire à l'identique
      // des deux côtés de l'écran.
      final baseMd = AppFormatters.decimalNumber(l.base * rwaVal / 100, maxDecimals: 3);
      final requisMd = AppFormatters.decimalNumber(l.requis(rwaVal), maxDecimals: 3);
      final detenuMd = AppFormatters.decimalNumber(l.detenu(rwaVal), maxDecimals: 3);
      final surplusMd = AppFormatters.decimalNumber(l.surplus(rwaVal), maxDecimals: 3);
      final basePct = '${l.base.toStringAsFixed(1)}%';
      final exigPct = '${l.exigence.toStringAsFixed(1)}%';
      final actPct = '${l.actuel.toStringAsFixed(1)}%';
      final coussinPct = '${l.coussin.toStringAsFixed(1)}%';

      // Pilier 1 marker
      if ((pos.dx - xb).abs() < 12) {
        found = _TooltipData(
          context.tr('{{label}} : Pilier 1 (en {{unit}})', args: {'label': l.label, 'unit': unitLabel}),
          [
            _TooltipRow('Seuil minimum strict'.tr(context), basePct),
            const _TooltipRow.divider(),
            _TooltipRow('Montant équivalent'.tr(context), '$baseMd $unitLabel', isHighlight: true),
          ],
          pos,
          formula: '(Seuil minimum × Actifs pondérés au risque)'.tr(context),
        );
        foundRow = i;
        foundDot = 0;
        break;
      }
      // Globale circle
      if ((pos.dx - xr).abs() < 12) {
        found = _TooltipData(
          context.tr('{{label}} : Exigence globale (en {{unit}})', args: {'label': l.label, 'unit': unitLabel}),
          [
            _TooltipRow('Pilier 1'.tr(context), basePct),
            _TooltipRow('Coussin de conservation'.tr(context), coussinPct),
            const _TooltipRow.divider(),
            _TooltipRow('Taux global exigé'.tr(context), exigPct, isHighlight: true),
            const _TooltipRow.divider(),
            _TooltipRow('Montant requis'.tr(context), '$requisMd $unitLabel', isHighlight: true),
          ],
          pos,
          formula: '(Taux global exigé × Actifs pondérés au risque)'.tr(context),
        );
        foundRow = i;
        foundDot = 1;
        break;
      }
      // Effectifs circle
      if ((pos.dx - xd).abs() < 12) {
        final sign = l.surplus(rwaVal) >= 0 ? '+' : '';
        found = _TooltipData(
          context.tr('{{label}} : Fonds propres détenus (en {{unit}})', args: {'label': l.label, 'unit': unitLabel}),
          [
            _TooltipRow('Montant détenu'.tr(context), '$detenuMd $unitLabel'),
            _TooltipRow('Ratio effectif'.tr(context), actPct, isHighlight: true),
            const _TooltipRow.divider(),
            _TooltipRow('Montant exigé'.tr(context), '$requisMd $unitLabel'),
            _TooltipRow(
              (l.surplus(rwaVal) >= 0 ? 'Excédent de capital' : 'Déficit de capital').tr(context),
              '$sign$surplusMd $unitLabel',
              isHighlight: true,
            ),
          ],
          pos,
          formula: '(Montant détenu - Montant exigé)'.tr(context),
        );
        foundRow = i;
        foundDot = 2;
        break;
      }
      
      // Coussin line (intervalle bleu clair)
      if (pos.dx >= xb && pos.dx <= xr) {
        final coussinMd = AppFormatters.decimalNumber(l.coussin * rwaVal / 100, maxDecimals: 3);
        found = _TooltipData(
          context.tr('{{label}} : Coussin de conservation (en {{unit}})', args: {'label': l.label, 'unit': unitLabel}),
          [
            _TooltipRow('Taux du coussin'.tr(context), coussinPct),
            const _TooltipRow.divider(),
            _TooltipRow('Montant équivalent'.tr(context), '$coussinMd $unitLabel', isHighlight: true),
          ],
          pos,
          formula: '(Taux du coussin × Actifs pondérés au risque)'.tr(context),
        );
        foundRow = i;
        foundDot = 3;
        break;
      }
    }

    setState(() {
      _tooltip = found;
      _hoveredRow = foundRow;
      _hoveredDotType = foundDot;
    });
  }

  void _onExit(PointerEvent _) {
    setState(() {
      _tooltip = null;
      _hoveredRow = null;
      _hoveredDotType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
    final unitLabel = amountUnit.label;

    final c = DashColors.of(context);
    final rwaVal = convertCurrencyAmount(_rwa, fromCurrency: 'XOF', toCurrency: widget.currency) / amountUnit.divisor;
    final lines = _lines;
    final maxDetenu = lines.isEmpty ? 100.0 : lines.map((l) => math.max(l.detenu(rwaVal), l.requis(rwaVal))).reduce(math.max);
    final tickStep = _calculateTickStep(maxDetenu);
    var maxAxis = (maxDetenu / tickStep).ceil() * tickStep;
    if (maxAxis <= 0) maxAxis = tickStep;

    return DashPanel(
      title: 'Exigences de fonds propres'.tr(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _LegendShape(type: 0),
              const SizedBox(width: 6),
              Text('Pilier 1'.tr(context), style: DashText.caption(c, color: c.muted)),
              const SizedBox(width: 14),
              const _LegendShape(type: 1),
              const SizedBox(width: 6),
              Text('Coussin'.tr(context), style: DashText.caption(c, color: c.muted)),
              const SizedBox(width: 14),
              const _LegendShape(type: 2),
              const SizedBox(width: 6),
              Text('Globale'.tr(context),
                  style: DashText.caption(c, color: c.muted)),
              const SizedBox(width: 18),
              _LegendShape(type: 3, color: c.accent),
              const SizedBox(width: 6),
              Text('Détenus'.tr(context),
                  style: DashText.caption(c, color: c.muted)),
              const Spacer(),
              Text(' ', style: DashText.caption(c)),
            ],
          ),
          const SizedBox(height: 12),
          MouseRegion(
            onHover: _onHover,
            onExit: _onExit,
            child: SizedBox(
              key: _chartKey,
              height: 190,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DotPlotPainter(
                        lines: lines,
                        hoveredRow: _hoveredRow,
                        hoveredDotType: _hoveredDotType,
                        rwa: rwaVal,
                        maxAxis: maxAxis,
                        tickStep: tickStep,
                        unitLabel: unitLabel,
                        grid: c.grid,
                        navy: c.navy,
                        accent: c.accent,
                        surface: c.surface,
                        ink: c.ink,
                        faint: c.faint,
                        muted: c.muted,
                        conforme: c.conforme,
                        sousMinimum: c.sousMinimum,
                      ),
                    ),
                  ),
                  if (_tooltip != null)
                    Positioned(
                      left: math.max(0.0, math.min(_getWidth() - 320.0, 
                          _tooltip!.pos.dx < _getWidth() / 2
                              ? _tooltip!.pos.dx + 16
                              : _tooltip!.pos.dx - 336)),
                      bottom: _getHeight() - _tooltip!.pos.dy + 12,
                      child: IgnorePointer(
                        child: Container(
                          width: 320,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: c.navy.withValues(alpha: 0.15), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: c.ink.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _tooltip!.title,
                                style: const TextStyle(
                                  color: Colors.indigo,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._tooltip!.rows.map((r) {
                                if (r.isDivider) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Divider(height: 1, color: c.border),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        r.label,
                                        style: TextStyle(
                                          color: r.isHighlight ? c.ink : c.muted,
                                          fontSize: 12,
                                          fontWeight: r.isHighlight ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Text(
                                        r.value,
                                        style: TextStyle(
                                          color: r.isHighlight ? c.ink : c.muted,
                                          fontSize: 12,
                                          fontWeight: r.isHighlight ? FontWeight.w700 : FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (_tooltip!.formula != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _tooltip!.formula!,
                                      style: TextStyle(
                                        color: c.muted,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _TooltipData {
  const _TooltipData(this.title, this.rows, this.pos, {this.formula});
  final String title;
  final List<_TooltipRow> rows;
  final Offset pos;
  final String? formula;
}

class _TooltipRow {
  const _TooltipRow(this.label, this.value, {this.isHighlight = false}) : isDivider = false;
  const _TooltipRow.divider() : label = '', value = '', isHighlight = false, isDivider = true;
  
  final String label;
  final String value;
  final bool isHighlight;
  final bool isDivider;
}

class _CapLine {
  const _CapLine(
    this.label, {
    required this.base,
    required this.coussin,
    required this.actuel,
  });

  final String label;
  final double base;
  final double coussin;
  final double actuel;

  double get exigence => base + coussin;
  double get couverture => actuel / exigence;
  double get margeRwa => (actuel / exigence - 1) * 100;

  double requis(double rwa) => exigence / 100 * rwa;
  double detenu(double rwa) => actuel / 100 * rwa;
  double surplus(double rwa) => detenu(rwa) - requis(rwa);
}

class _LegendShape extends StatelessWidget {
  const _LegendShape({required this.type, this.color});
  final int type; // 0=triangle, 1=line, 2=diamond, 3=circle
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: CustomPaint(
        painter: _LegendShapePainter(type: type, customColor: color),
      ),
    );
  }
}

class _LegendShapePainter extends CustomPainter {
  _LegendShapePainter({required this.type, this.customColor});
  final int type;
  final Color? customColor;
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    if (type == 0) { // Triangle (Pilier 1)
      final p = Path()
        ..moveTo(center.dx, center.dy - 4.5)
        ..lineTo(center.dx - 4, center.dy + 3.5)
        ..lineTo(center.dx + 4, center.dy + 3.5)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFF3B82F6)); // Bleu vif
    } else if (type == 1) { // Ligne (Coussin)
      canvas.drawLine(
        Offset(0, center.dy),
        Offset(size.width, center.dy),
        Paint()..color = const Color(0xFF93C5FD)..strokeWidth = 3, // Bleu clair
      );
    } else if (type == 2) { // Diamond (Globale)
      final p = Path()
        ..moveTo(center.dx, center.dy - 4.5)
        ..lineTo(center.dx + 4.5, center.dy)
        ..lineTo(center.dx, center.dy + 4.5)
        ..lineTo(center.dx - 4.5, center.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFF10B981)); // Vert
    } else if (type == 3) { // Circle (Détenus)
      canvas.drawCircle(center, 4, Paint()..color = customColor ?? const Color(0xFF8B5CF6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotPlotPainter extends CustomPainter {
  const _DotPlotPainter({
    required this.lines,
    required this.hoveredRow,
    required this.hoveredDotType,
    required this.rwa,
    required this.maxAxis,
    required this.tickStep,
    required this.unitLabel,
    required this.grid,
    required this.navy,
    required this.accent,
    required this.surface,
    required this.ink,
    required this.faint,
    required this.muted,
    required this.conforme,
    required this.sousMinimum,
  });

  final List<_CapLine> lines;
  final int? hoveredRow;
  final int? hoveredDotType;
  final double rwa;
  final double maxAxis;
  final double tickStep;
  final String unitLabel;
  final Color grid;
  final Color navy;
  final Color accent;
  final Color surface;
  final Color ink;
  final Color faint;
  final Color muted;
  final Color conforme;
  final Color sousMinimum;

  static const double _leftPad = 85;
  static const double _rightPad = 60;
  static const double _topPad = 12;
  static const double _bottomPad = 26;

  @override
  void paint(Canvas canvas, Size size) {
    const plotLeft = _leftPad;
    final plotRight = size.width - _rightPad;
    final plotW = plotRight - plotLeft;
    const plotTop = _topPad;
    final plotBottom = size.height - _bottomPad;

    double x(double v) => plotLeft + (v / maxAxis) * plotW;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    for (double t = 0; t <= maxAxis + 0.1; t += tickStep) {
      final gx = x(t);
      canvas.drawLine(Offset(gx, plotTop), Offset(gx, plotBottom), gridPaint);
      _text(
        canvas,
        AppFormatters.compactNumber(t),
        Offset(gx, plotBottom + 14),
        color: faint,
        size: 10,
        align: _Align.center,
      );
    }

    final rowCount = lines.length;
    for (var i = 0; i < rowCount; i++) {
      final l = lines[i];
      final y = plotTop + (plotBottom - plotTop) * ((i + 0.5) / rowCount);
      final xr = x(l.requis(rwa));
      final xd = x(l.detenu(rwa));

      final xb = x(l.base * rwa / 100);

      _text(canvas, l.label, Offset(plotLeft - 16, y),
          color: ink, size: 12, weight: FontWeight.w600, align: _Align.right);

      if (hoveredRow == i && hoveredDotType != null) {
        final dropPaint = Paint()
          ..color = navy.withValues(alpha: 0.15)
          ..strokeWidth = 1;
        if (hoveredDotType == 0) {
          _drawVerticalDashedLine(canvas, xb, y + 8, plotBottom, dropPaint);
        } else if (hoveredDotType == 1) {
          _drawVerticalDashedLine(canvas, xr, y + 8, plotBottom, dropPaint);
        } else if (hoveredDotType == 2) {
          _drawVerticalDashedLine(canvas, xd, y + 8, plotBottom, dropPaint);
        }
      }

      canvas.drawLine(
        Offset(plotLeft - 10, y),
        Offset(xb, y),
        Paint()
          ..color = grid
          ..strokeWidth = Dash.hairline,
      );

      // Anti-collision : on écarte visuellement les deux formes 
      // d'au moins 12 pixels pour éviter qu'elles ne se superposent.
      double vXb = xb;
      double vXr = xr;
      if (vXr - vXb < 12) {
        final mid = (vXb + vXr) / 2;
        vXb = mid - 6;
        vXr = mid + 6;
      }

      // Ligne du coussin (intervalle bleu clair)
      canvas.drawLine(
        Offset(vXb, y),
        Offset(vXr, y),
        Paint()
          ..color = const Color(0xFF93C5FD)
          ..strokeWidth = 3,
      );

      final isDeficit = l.surplus(rwa) < 0;
      final pointColor = isDeficit ? sousMinimum : accent;

      canvas.drawLine(
        Offset(vXr, y),
        Offset(xd, y),
        Paint()
          ..color = isDeficit ? sousMinimum.withValues(alpha: 0.5) : accent.withValues(alpha: 0.25)
          ..strokeWidth = 2,
      );

      // Marqueur Pilier 1 (Triangle bleu)
      final pathP1 = Path()
        ..moveTo(vXb, y - 5)
        ..lineTo(vXb - 4.5, y + 4)
        ..lineTo(vXb + 4.5, y + 4)
        ..close();
      canvas.drawPath(pathP1, Paint()..color = const Color(0xFF3B82F6));

      // Marqueur Exigence Globale (Losange ambre)
      final pathGlob = Path()
        ..moveTo(vXr, y - 5)
        ..lineTo(vXr + 5, y)
        ..lineTo(vXr, y + 5)
        ..lineTo(vXr - 5, y)
        ..close();
      canvas.drawPath(pathGlob, Paint()..color = const Color(0xFF10B981));

      // Marqueur Fonds propres détenus (point coloré)
      canvas.drawCircle(Offset(xd, y), 4, Paint()..color = pointColor);

      final surplusVal = l.surplus(rwa);
      final signStr = surplusVal > 0 ? '+' : '';
      final rightMostX = math.max(xr, xd);
      
      _text(
        canvas,
        '$signStr${AppFormatters.decimalNumber(surplusVal.abs(), maxDecimals: 3)}$unitLabel',
        Offset(rightMostX + 11, y),
        color: pointColor,
        size: 10,
        weight: FontWeight.w600,
        align: _Align.left,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required Color color,
    required double size,
    FontWeight weight = FontWeight.w400,
    _Align align = _Align.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          fontFeatures: Dash.tabular,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx = at.dx;
    if (align == _Align.center) dx = at.dx - tp.width / 2;
    if (align == _Align.right) dx = at.dx - tp.width;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DotPlotPainter old) =>
      old.hoveredRow != hoveredRow ||
      old.hoveredDotType != hoveredDotType ||
      old.maxAxis != maxAxis ||
      old.rwa != rwa ||
      old.navy != navy ||
      old.grid != grid;

  void _drawVerticalDashedLine(Canvas canvas, double x, double yStart, double yEnd, Paint paint) {
    const double dash = 3;
    const double space = 3;
    double currentY = yStart;
    while (currentY < yEnd) {
      canvas.drawLine(
        Offset(x, currentY),
        Offset(x, math.min(currentY + dash, yEnd)),
        paint,
      );
      currentY += dash + space;
    }
  }
}

enum _Align { left, center, right }
