// Ce fichier centralise les styles et helpers du dashboard RWA.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';

Color dashboardPanelColor(bool isDark) {
  return isDark ? const Color(0xFF162642) : const Color(0xFFF8FAFC);
}

Color dashboardPanelBorder(bool isDark) {
  return isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F5);
}

Color dashboardTitleColor(bool isDark) {
  return isDark ? const Color(0xFFEAF2FF) : const Color(0xFF13203A);
}

Color dashboardSubtitleColor(bool isDark) {
  return isDark ? const Color(0xFF9FB0CE) : const Color(0xFF64748B);
}

List<BoxShadow> dashboardPanelShadow(bool isDark) {
  return [
    BoxShadow(
      color: isDark ? const Color(0x26040A16) : const Color(0x0F334155),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

String dashboardLongDate(DateTime date) {
  final weekdays = AppLocalizations.isEnglish
      ? const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ]
      : const [
          'Lundi',
          'Mardi',
          'Mercredi',
          'Jeudi',
          'Vendredi',
          'Samedi',
          'Dimanche',
        ];
  final months = AppLocalizations.isEnglish
      ? const [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ]
      : const [
          'Janvier',
          'Fevrier',
          'Mars',
          'Avril',
          'Mai',
          'Juin',
          'Juillet',
          'Aout',
          'Septembre',
          'Octobre',
          'Novembre',
          'Decembre',
        ];

  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

String dashboardShortMonth(DateTime date) {
  final months = AppLocalizations.isEnglish
      ? const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ]
      : const [
          'Jan',
          'Fev',
          'Mar',
          'Avr',
          'Mai',
          'Jun',
          'Jul',
          'Aou',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
  return '${months[date.month - 1]} ${date.year}';
}

String dashboardCompactCurrency(double value) {
  final amountUnit = PortfolioAmountUnitPreference.current;
  return '${AppFormatters.compactNumber(value / amountUnit.divisor)} ${amountUnit.label} (XOF)';
}

String dashboardCompactPercent(double value) {
  final scaled = value * 100;
  if (scaled.abs() >= 100) {
    return '${scaled.toStringAsFixed(0)}%';
  }
  return '${scaled.toStringAsFixed(1)}%';
}

String _normalizeDashboardText(String raw) {
  return raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'^\([a-z]\)\s*'), '')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ô', 'o')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _canonicalExposureLabel(String raw) {
  switch (_normalizeDashboardText(raw)) {
    case 'souverains':
      return 'souverains';
    case 'organismes publics':
    case 'organismes pub. hors adm c':
      return 'organismes pub. hors Adm c';
    case 'expositions sur les bmd':
    case 'bmd':
      return 'Expositions sur les BMD';
    case 'institutions financieres':
      return 'institutions financières';
    case 'entreprises':
      return 'entreprises';
    case 'particuliers':
    case 'clientele detail':
    case 'clientele de detail':
      return 'clientèle de détail';
    case 'immobilier':
    case "prets garantis par l'immobilier r":
    case 'immo r':
    case "prets garantis par l'immo r":
      return "prêts garantis par l'immo R";
    case "prets garantis par l'immobilier c":
    case 'immo c':
    case "prets garantis par l'immo c":
      return "prêts garantis par l'immo C";
    case 'creances en souffrance':
    case 'souffrance':
      return 'créances en souffrance';
    case 'creances a risque eleve':
    case 'risque eleve':
      return 'créances à risque élevé';
    case 'autres actifs':
      return 'autres actifs';
    case 'hors bilan':
      return 'Hors bilan';
    default:
      return raw;
  }
}

String dashboardExposureLabel(String raw) {
  return AppLocalizations.translate(_canonicalExposureLabel(raw));
}

/// Libellé complet, sans aucune abréviation, aligné sur FULL_AGENT_LABELS du
/// backend : sert aux infobulles quand l'affichage compact tronque le nom.
String dashboardExposureFullLabel(String raw) {
  switch (_canonicalExposureLabel(raw)) {
    case 'souverains':
      return AppLocalizations.translate('Souverains');
    case 'organismes pub. hors Adm c':
      return AppLocalizations.translate(
          'Organismes publics hors Administration centrale');
    case 'Expositions sur les BMD':
      return AppLocalizations.translate(
          'Banques multilatérales de développement');
    case 'institutions financières':
      return AppLocalizations.translate('Institutions financières');
    case 'entreprises':
      return AppLocalizations.translate('Entreprises');
    case 'clientèle de détail':
      return AppLocalizations.translate('Clientèle de détail');
    case "prêts garantis par l'immo R":
      return AppLocalizations.translate(
          "Prêts garantis par l'immobilier résidentiel");
    case "prêts garantis par l'immo C":
      return AppLocalizations.translate(
          "Prêts garantis par l'immobilier commercial");
    case 'créances en souffrance':
      return AppLocalizations.translate('Créances en souffrance');
    case 'créances à risque élevé':
      return AppLocalizations.translate('Créances à risque élevé');
    case 'autres actifs':
      return AppLocalizations.translate('Autres actifs');
    case 'Hors bilan':
      return AppLocalizations.translate('Hors bilan');
    default:
      return dashboardExposureLabel(raw);
  }
}

String _canonicalCrmLabel(String raw) {
  switch (_normalizeDashboardText(raw)) {
    case 'crm finance':
    case 'crm financee':
      return 'CRM financee';
    case 'crm non finance':
    case 'crm non financee':
      return 'CRM non financee';
    case 'sans crm':
    case 'aucune':
      return 'Aucune';
    default:
      return raw;
  }
}

String dashboardCrmLabel(String raw) {
  return AppLocalizations.translate(_canonicalCrmLabel(raw));
}

String dashboardRiskLabel(double value) {
  if (value <= 50) {
    return AppLocalizations.translate('Strong quality');
  }
  if (value <= 100) {
    return AppLocalizations.translate('Balanced quality');
  }
  return AppLocalizations.translate('Higher pressure');
}

Color dashboardCategoryColor(String raw) {
  switch (_canonicalExposureLabel(raw)) {
    case 'entreprises':
      return const Color(0xFF5E84BF);
    case 'institutions financières':
      return const Color(0xFF365F9A);
    case 'souverains':
      return const Color(0xFF7D91B5);
    case 'organismes pub. hors Adm c':
      return const Color(0xFF8A9DBB);
    case 'Expositions sur les BMD':
      return const Color(0xFF4B6F9D);
    case 'clientèle de détail':
      return const Color(0xFF8A9EBB);
    case "prêts garantis par l'immo R":
      return const Color(0xFF617FA7);
    case "prêts garantis par l'immo C":
      return const Color(0xFF7088AA);
    case 'créances en souffrance':
      return const Color(0xFF415A84);
    case 'créances à risque élevé':
      return const Color(0xFF283C63);
    case 'autres actifs':
      return const Color(0xFF98A7BE);
    case 'Hors bilan':
      return const Color(0xFFAAB5C5);
    default:
      return const Color(0xFF5E84BF);
  }
}

Color dashboardCrmColor(String raw) {
  switch (_canonicalCrmLabel(raw)) {
    case 'CRM financee':
      return const Color(0xFF2D6CDF);
    case 'CRM non financee':
      return const Color(0xFFE24A4A);
    case 'Aucune':
      return const Color(0xFF00C853);
    default:
      return const Color(0xFF2D6CDF);
  }
}

Color dashboardCountryBarColor(int index) {
  const palette = [
    Color(0xFF234A84),
    Color(0xFF3566B7),
    Color(0xFF4C7BDD),
    Color(0xFF6C95EB),
    Color(0xFF8DB1F6),
  ];
  final safeIndex = math.min(math.max(index, 0), palette.length - 1);
  return palette[safeIndex];
}
