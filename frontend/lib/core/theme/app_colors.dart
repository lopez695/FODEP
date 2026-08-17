// Ce fichier centralise toutes les couleurs thématiques de l'application.
import 'package:flutter/material.dart';

/// Palette de couleurs centralisée pour l'outil RWA.
/// Remplace les couleurs hardcodées dispersées dans les modules.
class AppColors {
  AppColors._();

  // Couleurs principales (déjà dans AppTheme)
  static const Color sidebar = Color(0xFF172B4D);
  static const Color sidebarLight = Color(0xFF23477A);
  static const Color accent = Color(0xFF2563EB);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Couleurs de concentration
  static const Color concentrationPrimary = Color(0xFF4338CA);
  static const Color concentrationDark = Color(0xFF3730A3);
  static const Color concentrationDeeper = Color(0xFF312E81);

  // Couleurs de risque de crédit
  static const Color counterpartyBlue = Color(0xFF3B82F6);
  static const Color riskWeightGreen = Color(0xFFBFDBFE);
  static const Color riskWeightText = Color(0xFF2563EB);
  static const Color riskWeightDark = Color(0xFF312E81);
  static const Color riskWeightTrack = Color(0xFFE2E8F0);
  static const Color panelAccent = Color(0xFF475569);

  // Couleurs de notation
  static const Color ratingInvestment = Color(0xFF10B981);
  static const Color ratingSpeculative = Color(0xFFF59E0B);
  static const Color ratingDefault = Color(0xFFEF4444);

  // Couleurs géographiques (zones UMOA/CEMAC)
  static const Color zoneUemoa = Color(0xFF16A34A);
  static const Color zoneCemac = Color(0xFFEAB308);
  static const Color zoneOutside = Color(0xFFDC143C);

  // Couleurs prudentielles (ratios réglementaires)
  static const Color prudentialCapital = Color(0xFF1E40AF);
  static const Color prudentialTier = Color(0xFF059669);
  static const Color prudentialSolvency = Color(0xFF7C3AED);
  static const Color prudentialLeverage = Color(0xFFD97706);
  static const Color prudentialBuffer = Color(0xFFBE123C);
  static const Color prudentialCompliance = Color(0xFFE11D48);

  // Couleurs de qualité / scoring
  static const Color qualityExcellent = Color(0xFF3B82F6);
  static const Color qualityGood = Color(0xFF6366F1);
  static const Color qualityAverage = Color(0xFF14B8A6);
  static const Color qualityFair = Color(0xFF0EA5E9);
  static const Color qualityPoor = Color(0xFF8B5CF6);

  // Couleurs pour graphiques et visualisations
  static const List<Color> chartPalette = [
    Color(0xFF3B82F6), // Bleu
    Color(0xFF10B981), // Vert
    Color(0xFFF59E0B), // Orange
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Rose
    Color(0xFF14B8A6), // Teal
    Color(0xFF6366F1), // Indigo
    Color(0xFFF97316), // Orange foncé
  ];

  // Couleurs pour les surfaces et arrière-plans
  static const Color surfaceLight = Color(0xFFF5F7FF);
  static const Color surfaceDark = Color(0xFF0F1B31);
  static const Color borderLight = Color(0xFFE6EAF5);
  static const Color borderDark = Color(0xFF172554);

  // Couleurs pour les alertes
  static const Color alertCritical = Color(0xFFDC143C);
  static const Color alertHigh = Color(0xFFEF4444);
  static const Color alertMedium = Color(0xFFF59E0B);
  static const Color alertLow = Color(0xFF10B981);
  static const Color alertInfo = Color(0xFF3B82F6);

  // Couleurs pour le risque de marché
  static const Color marketPositive = Color(0xFF10B981);
  static const Color marketNegative = Color(0xFFEF4444);
  static const Color marketNeutral = Color(0xFF06B6D4);
  static const Color marketVolatility = Color(0xFF8B5CF6);

  // Couleurs pour le risque opérationnel
  static const Color operationalLow = Color(0xFF10B981);
  static const Color operationalMedium = Color(0xFFF59E0B);
  static const Color operationalHigh = Color(0xFFEF4444);
  static const Color operationalCritical = Color(0xFFDC143C);

  /// Retourne la couleur appropriée selon le niveau de sévérité
  static Color severityColor(String severity) {
    final normalized = severity.toLowerCase();
    if (normalized.contains('critique') || normalized.contains('critical')) {
      return alertCritical;
    }
    if (normalized.contains('élevé') ||
        normalized.contains('eleve') ||
        normalized.contains('high') ||
        normalized.contains('haut')) {
      return alertHigh;
    }
    if (normalized.contains('moyen') || normalized.contains('medium')) {
      return alertMedium;
    }
    if (normalized.contains('faible') ||
        normalized.contains('low') ||
        normalized.contains('bas')) {
      return alertLow;
    }
    return alertInfo;
  }

  /// Retourne la couleur appropriée pour une notation de crédit
  static Color ratingColor(String? rating) {
    if (rating == null || rating.isEmpty) return ratingSpeculative;
    final normalized = rating.toUpperCase();
    if (normalized.startsWith('AAA') ||
        normalized.startsWith('AA') ||
        normalized.startsWith('A')) {
      return ratingInvestment;
    }
    if (normalized.startsWith('BB') || normalized.startsWith('B')) {
      return ratingSpeculative;
    }
    return ratingDefault;
  }

  /// Retourne la couleur appropriée pour un ratio prudentiel
  static Color ratioColor(double ratio, double minimum, double target) {
    if (ratio >= target) return success;
    if (ratio >= minimum) return warning;
    return danger;
  }
}
