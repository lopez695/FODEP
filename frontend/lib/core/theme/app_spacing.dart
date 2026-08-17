// Ce fichier centralise tous les espacements de l'application.
import 'package:flutter/material.dart';

/// Système d'espacement standardisé pour l'outil RWA.
/// Remplace les valeurs d'espacement hardcodées.
class AppSpacing {
  AppSpacing._();

  // Espacements de base
  static const double xs = 1.0;
  static const double sm = 2.0;
  static const double md = 3.0;
  static const double lg = 4.0;
  static const double xl = 6.0;
  static const double xxl = 8.0;
  static const double xxxl = 12.0;

  // Espacements pour les pages
  static const double pagePadding = lg; // 4
  static const double pageGap = sm; // 2

  // Espacements pour les cartes
  static const double cardPadding = md; // 3
  static const double cardGap = sm; // 2
  static const double cardInnerGap = xs; // 1

  // Espacements pour les sections
  static const double sectionPadding = lg; // 4
  static const double sectionGap = sm; // 2
  static const double sectionHeaderGap = sm; // 2

  // Espacements pour les formulaires
  static const double formFieldGap = sm; // 2
  static const double formSectionGap = lg; // 4
  static const double formLabelGap = xs; // 1

  // Espacements pour les tableaux
  static const double tableCellPadding = sm; // 2
  static const double tableRowGap = xs; // 1
  static const double tableHeaderGap = sm; // 2

  // Espacements pour les boutons
  static const double buttonPaddingHorizontal = md; // 3
  static const double buttonPaddingVertical = sm; // 2
  static const double buttonGap = xs; // 1

  // Espacements pour les KPI et métriques
  static const double kpiPadding = md; // 3
  static const double kpiGap = sm; // 2
  static const double kpiLabelGap = xs; // 1

  // EdgeInsets prédéfinis pour usage courant
  static const EdgeInsets pageInsets = EdgeInsets.all(pagePadding);
  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);
  static const EdgeInsets sectionInsets = EdgeInsets.all(sectionPadding);
  static const EdgeInsets formFieldInsets = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
  static const EdgeInsets buttonInsets = EdgeInsets.symmetric(
    horizontal: buttonPaddingHorizontal,
    vertical: buttonPaddingVertical,
  );
  static const EdgeInsets kpiInsets = EdgeInsets.all(kpiPadding);

  // Gaps prédéfinis (pour Column, Row, Wrap, etc.)
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);

  // Gaps horizontaux
  static const SizedBox hGapXs = SizedBox(width: xs);
  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
  static const SizedBox hGapLg = SizedBox(width: lg);
  static const SizedBox hGapXl = SizedBox(width: xl);

  // Gaps verticaux
  static const SizedBox vGapXs = SizedBox(height: xs);
  static const SizedBox vGapSm = SizedBox(height: sm);
  static const SizedBox vGapMd = SizedBox(height: md);
  static const SizedBox vGapLg = SizedBox(height: lg);
  static const SizedBox vGapXl = SizedBox(height: xl);
}
