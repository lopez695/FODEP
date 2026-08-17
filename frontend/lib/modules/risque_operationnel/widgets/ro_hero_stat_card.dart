import 'package:flutter/material.dart';

import '../../dashboard/widgets/dashboard_design.dart';

/// Carte KPI "hero" - même habillage que les cartes de la vue Analyse rapide
/// BIC/CRR3 (libellé en capitales, filet séparateur, grande valeur, sous-titre
/// en pied de carte). Réutilisée par les autres onglets UEMOA (AIB, AS, ...)
/// pour garder un style de carte KPI unique dans tout le module.
class RoHeroStatCard extends StatefulWidget {
  const RoHeroStatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  @override
  State<RoHeroStatCard> createState() => _RoHeroStatCardState();
}

class _RoHeroStatCardState extends State<RoHeroStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 152,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Dash.radius),
          border: Border.all(
            color: _hovered ? Colors.indigo.shade300 : c.border,
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label.toUpperCase(),
              style: DashText.eyebrow(c, color: Colors.indigo).copyWith(
                fontSize: 9.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Divider(color: c.border, thickness: Dash.hairline, height: 1),
            const SizedBox(height: 10),
            Text(
              widget.value,
              style: DashText.hero(c, size: 19,
                  color: widget.valueColor != null ? _readableColor(widget.valueColor!) : c.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
              const Spacer(),
              Tooltip(
                message: widget.subtitle!,
                waitDuration: const Duration(milliseconds: 300),
                textStyle: const TextStyle(
                    fontSize: 12, color: Colors.white, height: 1.4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.subtitle!,
                  style: DashText.caption(c, color: c.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Assombrit une couleur de statut trop claire (ex. l'orange d'alerte) pour
/// que les chiffres des cartes restent bien lisibles sur fond clair - la
/// teinte est conservée, seule la luminosité est réduite.
Color _readableColor(Color c) {
  final hsl = HSLColor.fromColor(c);
  if (hsl.lightness <= 0.5) return c;
  return hsl.withLightness(0.34).toColor();
}
