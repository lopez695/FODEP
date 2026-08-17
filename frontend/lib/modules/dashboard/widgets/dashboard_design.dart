// Système visuel « rapport prudentiel » du dashboard général.
//
// Règle directrice (cf. charte institutionnelle FODEP) : un seul accent =
// le navy `AppColors.sidebar`. La couleur ne sert qu'au **statut** (conforme /
// sous-cible / sous-minimum) en tons profonds désaturés. Pas de pastel, pas de
// gradient, pas d'icon-box teintée, pas d'ombre portée, pas d'arc-en-ciel de
// catégories : les séries multiples se déclinent en **nuances de navy**.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_colors.dart';

/// Constantes de mise en page partagées par les panneaux du dashboard.
class Dash {
  Dash._();

  /// Rayon des panneaux : net, jamais l'arrondi « SaaS ».
  static const double radius = 8;

  /// Filet fin unique pour bordures et séparateurs.
  static const double hairline = 0.6;

  /// Padding interne standard d'un panneau.
  static const EdgeInsets panelPadding = EdgeInsets.all(18);

  /// Chiffres tabulaires (alignement vertical des colonnes de nombres).
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

/// Statut prudentiel d'une métrique - seule chose qui porte de la couleur.
enum DashStatus { conforme, sousCible, sousMinimum, neutre }

/// Palette résolue selon le thème clair/sombre.
@immutable
class DashColors {
  const DashColors({
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.divider,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.navy,
    required this.accent,
    required this.grid,
    required this.conforme,
    required this.sousCible,
    required this.sousMinimum,
    required this.ramp,
  });

  /// Fond des panneaux.
  final Color surface;

  /// Fond alterné (en-têtes de table, lignes zébrées).
  final Color surfaceAlt;

  /// Bordure des panneaux (filet fin).
  final Color border;

  /// Séparateur interne (encore plus discret que la bordure).
  final Color divider;

  /// Encre principale (texte, chiffres-héros).
  final Color ink;

  /// Texte secondaire.
  final Color muted;

  /// Texte tertiaire / graduations.
  final Color faint;

  /// Accent unique institutionnel.
  final Color navy;

  /// Couleur d'accentuation dynamique pour les points de données clés.
  final Color accent;

  /// Lignes de grille des graphiques.
  final Color grid;

  final Color conforme;
  final Color sousCible;
  final Color sousMinimum;

  /// Dégradé monochrome navy (foncé → clair) pour les séries catégorielles.
  final List<Color> ramp;

  static DashColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static const DashColors _light = DashColors(
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF7F8FB),
    border: Color(0xFFE3E7EE),
    divider: Color(0xFFEDEFF4),
    ink: Color(0xFF0F1B2D),
    muted: Color(0xFF5B6577),
    faint: Color(0xFF98A2B3),
    navy: AppColors.sidebar, // 0xFF172B4D
    accent: Color(0xFF4338CA), // Indigo (0xFF4F46E5 or 4338CA)
    grid: Color(0xFFEEF1F5),
    conforme: Color(0xFF1B7A4B),
    sousCible: Color(0xFFB45309),
    sousMinimum: Color(0xFFB42318),
    ramp: [
      Color(0xFF172B4D),
      Color(0xFF2D456E),
      Color(0xFF47608A),
      Color(0xFF6981A6),
      Color(0xFF95A6C0),
      Color(0xFFC4CDDC),
    ],
  );

  static const DashColors _dark = DashColors(
    surface: Color(0xFF111827),
    surfaceAlt: Color(0xFF0F1827),
    border: Color(0xFF24304A),
    divider: Color(0xFF1F2937),
    ink: Color(0xFFF1F5F9),
    muted: Color(0xFF94A3B8),
    faint: Color(0xFF6B7280),
    navy: Color(0xFF637B9C), // Plus clair sur fond sombre
    accent: Color(0xFF818CF8), // Indigo plus clair sur fond sombre
    grid: Color(0xFF2D333B),
    conforme: Color(0xFF35B07A),
    sousCible: Color(0xFFD9912F),
    sousMinimum: Color(0xFFE0695E),
    ramp: [
      Color(0xFFC2D0EC),
      Color(0xFFA2B5DD),
      Color(0xFF8196C4),
      Color(0xFF6075A0),
      Color(0xFF45587F),
      Color(0xFF32435F),
    ],
  );

  Color status(DashStatus s) {
    switch (s) {
      case DashStatus.conforme:
        return conforme;
      case DashStatus.sousCible:
        return sousCible;
      case DashStatus.sousMinimum:
        return sousMinimum;
      case DashStatus.neutre:
        return muted;
    }
  }

  /// Couleur d'un index de série, en repartant du début si dépassement.
  Color rampAt(int index) => ramp[index % ramp.length];
}

extension DashStatusX on DashStatus {
  String get label {
    switch (this) {
      case DashStatus.conforme:
        return 'Conforme';
      case DashStatus.sousCible:
        return 'Sous la cible';
      case DashStatus.sousMinimum:
        return 'Sous le minimum';
      case DashStatus.neutre:
        return '-';
    }
  }
}

/// Statut d'un ratio par rapport à son minimum réglementaire et sa cible.
DashStatus dashRatioStatus(double value, double minimum, double target) {
  if (value < minimum) return DashStatus.sousMinimum;
  if (value < target) return DashStatus.sousCible;
  return DashStatus.conforme;
}

/// Styles de texte normalisés.
class DashText {
  DashText._();

  /// Sur-titre en capitales tracées (eyebrow).
  static TextStyle eyebrow(DashColors c, {Color? color}) => TextStyle(
        color: color ?? c.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      );

  /// Légende / unité.
  static TextStyle caption(DashColors c, {Color? color}) => TextStyle(
        color: color ?? c.faint,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      );

  /// Chiffre-héros tabulaire.
  static TextStyle hero(DashColors c, {double size = 30, Color? color}) =>
      TextStyle(
        color: color ?? c.ink,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.0,
        fontFeatures: Dash.tabular,
      );

  /// Valeur de table tabulaire.
  static TextStyle value(DashColors c, {Color? color, FontWeight? weight}) =>
      TextStyle(
        color: color ?? c.ink,
        fontSize: 13,
        fontWeight: weight ?? FontWeight.w600,
        fontFeatures: Dash.tabular,
      );
}

/// Panneau institutionnel : surface plate, filet fin, pas d'ombre.
/// En-tête optionnel = eyebrow en capitales + unité + filet séparateur.
class DashPanel extends StatelessWidget {
  const DashPanel({
    super.key,
    this.title,
    this.subtitle,
    this.unit,
    this.trailing,
    this.height,
    this.padding = Dash.panelPadding,
    required this.child,
  });

  /// Sur-titre (affiché en capitales).
  final String? title;

  /// Sous-titre optionnel affiché sous le titre principal.
  final String? subtitle;

  /// Précision d'unité affichée à droite de l'en-tête (ex. « En % des FP »).
  final String? unit;

  /// Widget aligné à droite dans l'en-tête (prioritaire sur [unit]).
  final Widget? trailing;

  final double? height;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    reverseDuration: const Duration(milliseconds: 100),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: Text(
                      title!.toUpperCase(),
                      key: ValueKey(title),
                      style: DashText.eyebrow(
                        c,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue.shade400
                            : c.navy,
                      ),
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (unit != null)
                  Text(unit!, style: DashText.caption(c)),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: DashText.caption(c, color: c.muted)),
              const SizedBox(height: 10),
            ] else ...[
              const SizedBox(height: 10),
            ],
            Divider(height: 1, thickness: Dash.hairline, color: c.divider),
            const SizedBox(height: 14),
          ],
          if (height != null) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// Pastille de statut discrète : point + libellé, sans fond ni bordure.
class DashStatusTag extends StatelessWidget {
  const DashStatusTag({super.key, required this.status, this.dense = false});

  final DashStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final color = c.status(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          status.label.tr(context),
          style: TextStyle(
            color: color,
            fontSize: dense ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
