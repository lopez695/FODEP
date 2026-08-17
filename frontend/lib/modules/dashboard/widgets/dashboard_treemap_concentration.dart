import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import 'dashboard_design.dart';

/// Concentration des risques - top 10 contreparties, en treemap.
///
/// Pavés en nuances de navy ordonnées par taille (le plus exposé = navy le
/// plus profond). Aucune couleur catégorielle arbitraire.
class DashboardTreemapConcentration extends StatelessWidget {
  const DashboardTreemapConcentration({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    Widget box(int rampIndex, String title, String value) {
      final color = c.ramp[rampIndex];
      final onColor =
          rampIndex <= 3 ? Colors.white : const Color(0xFF0F1B2D);
      return _TreemapBox(color: color, onColor: onColor, title: title, value: value);
    }

    return DashPanel(
      height: 300,
      title: 'Concentration des risques - top 10 contreparties'.tr(context),
      unit: 'En % des fonds propres'.tr(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 317, child: box(0, 'Groupe A', '31,7%')),
            const SizedBox(width: 2),
            Expanded(flex: 243, child: box(1, 'Groupe B', '24,3%')),
            const SizedBox(width: 2),
            Expanded(
              flex: 440,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 186, child: box(2, 'Groupe C', '18,6%')),
                  const SizedBox(height: 2),
                  Expanded(flex: 124, child: box(3, 'Groupe D', '12,4%')),
                  const SizedBox(height: 2),
                  Expanded(
                    flex: 130,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 92, child: box(4, 'Groupe E', '9,2%')),
                        const SizedBox(width: 2),
                        Expanded(flex: 38, child: box(5, 'Autres', '3,9%')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreemapBox extends StatelessWidget {
  const _TreemapBox({
    required this.color,
    required this.onColor,
    required this.title,
    required this.value,
  });

  final Color color;
  final Color onColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title.tr(context),
              style: TextStyle(
                color: onColor.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: onColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: Dash.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
