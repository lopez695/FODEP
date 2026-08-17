import 'package:flutter/material.dart';

import 'dashboard_design.dart';

/// Infobulle « carte » des graphiques du dashboard : titre en gras puis
/// lignes de détail, sur fond clair arrondi et ombré — même langage visuel
/// que la carte de survol du donut CRM.
class DashChartTooltip extends StatelessWidget {
  const DashChartTooltip({
    super.key,
    required this.title,
    required this.lines,
    required this.child,
  });

  final String title;
  final List<String> lines;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    const ink = Color(0xFF1E3A8A);
    return Tooltip(
      waitDuration: const Duration(milliseconds: 250),
      preferBelow: false,
      // Hors de l'arbre sémantique : sur Windows, l'apparition/disparition
      // des nœuds d'infobulle fait boucler le pont d'accessibilité du moteur
      // Flutter (« Failed to update ui::AXTree ») et inonde la console.
      excludeFromSemantics: true,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ink,
              height: 1.5,
            ),
          ),
          for (final line in lines)
            TextSpan(
              text: '\n$line',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: ink,
                height: 1.45,
              ),
            ),
        ],
      ),
      child: child,
    );
  }
}
