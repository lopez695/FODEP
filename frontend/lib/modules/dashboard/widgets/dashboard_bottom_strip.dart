import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import 'dashboard_design.dart';

/// Bandeau de chiffres-clés en bas de dashboard.
///
/// Cellules plates à filet fin : sur-titre tracé + chiffre tabulaire. Pas
/// d'icon-box teintée ; la couleur ne signale qu'un dépassement.
class DashboardBottomStrip extends StatelessWidget {
  const DashboardBottomStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    final cells = <Widget>[
      _Cell(c: c, label: 'Fonds propres totaux'.tr(context), value: '180 Md FCFA'),
      _Cell(
        c: c,
        label: 'Consommation des FP'.tr(context),
        value: '70,9%',
        progress: 0.708,
      ),
      _Cell(c: c, label: 'Nombre de grands risques'.tr(context), value: '54'),
      _Cell(c: c, label: 'Risques traités'.tr(context), value: '337'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final perRow = width >= 1000
            ? 4
            : width >= 560
                ? 2
                : 1;
        return _grid(cells, perRow);
      },
    );
  }

  Widget _grid(List<Widget> cells, int perRow) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += perRow) {
      final end = i + perRow < cells.length ? i + perRow : cells.length;
      final slice = cells.sublist(i, end);
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < perRow; j++) ...[
                Expanded(
                  child: j < slice.length ? slice[j] : const SizedBox.shrink(),
                ),
                if (j < perRow - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      );
      if (i + perRow < cells.length) rows.add(const SizedBox(height: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.c,
    required this.label,
    required this.value,
    this.progress,
  });

  final DashColors c;
  final String label;
  final String value;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: DashText.eyebrow(c, color: c.faint).copyWith(fontSize: 9.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(value, style: DashText.hero(c, size: 19)),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: c.grid,
                valueColor: AlwaysStoppedAnimation<Color>(c.navy),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
