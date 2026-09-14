// Ce fichier regroupe les formateurs utilises dans l'interface.
import 'package:intl/intl.dart';

import '../localization/app_localization.dart';
import 'currency_conversion.dart';

/// Top-level formatter functions for easy access
String formatLargeNumber(num value) => AppFormatters.compactNumber(value);

String formatDecimal(num value, int decimals) =>
    AppFormatters.decimalNumber(value, maxDecimals: decimals);

/// Centralise les formats d'affichage des montants, pourcentages et dates.
class AppFormatters {
  static final Map<String, NumberFormat> _currencyFormatCache = {};
  static final Map<String, NumberFormat> _percentFormatCache = {};
  static final Map<String, DateFormat> _shortDateFormatCache = {};

  static String rawCurrency(num value, {String currencyCode = 'XOF'}) {
    final upper = currencyCode.toUpperCase();
    final locale =
        upper == 'USD' ? 'en_US' : AppLocalizations.currentLanguage.intlLocale;
    final key = '$locale:$upper:v3';
    final formatter = _currencyFormatCache.putIfAbsent(key, () {
      return NumberFormat.currency(
        locale: locale,
        symbol: currencySymbol(currencyCode),
        decimalDigits: 0,
        customPattern: '#,##0 \u00a4',
      );
    });
    return formatter.format(value);
  }

  static String currency(
    num value, {
    String currencyCode = 'XOF',
    bool raw = false,
    int maxDecimals = 2,
  }) {
    if (raw) {
      return rawCurrency(value, currencyCode: currencyCode);
    }
    final unit = PortfolioAmountUnitPreference.current;
    final val = value.toDouble();
    if (val == 0) {
      return '0 ${unit.label} ${currencySymbol(currencyCode)}';
    }
    final scaled = val / unit.divisor;
    final absScaled = scaled.abs();
    int decimals = maxDecimals;
    if (absScaled > 0 && absScaled < 0.01) {
      decimals = 4;
    } else if (absScaled > 0 && absScaled < 1.0) {
      decimals = 3;
    }
    return '${decimalNumber(scaled, maxDecimals: decimals)} ${unit.label} ${currencySymbol(currencyCode)}';
  }

  static String compactNumber(num value) {
    final amount = value.toDouble();
    final absolute = amount.abs();

    int decimals;
    if (absolute == 0) {
      decimals = 0;
    } else if (absolute >= 1000) {
      decimals = 0;
    } else if (absolute >= 100) {
      decimals = 1;
    } else if (absolute >= 10) {
      decimals = 2;
    } else if (absolute >= 1) {
      decimals = 3;
    } else {
      decimals = 4;
    }

    return _number(decimals).format(amount);
  }

  static String decimalNumber(num value, {int maxDecimals = 2}) {
    return _number(maxDecimals).format(value);
  }

  static String fixedDecimalNumber(num value, {int decimals = 2}) {
    return _fixedNumber(decimals).format(value);
  }

  static String usefulDecimalNumber(num value, {int decimals = 3}) {
    final rounded = value.toDouble().toStringAsFixed(decimals);
    final fractional = rounded.split('.').last;
    if (RegExp(r'^0+$').hasMatch(fractional)) {
      return _number(0).format(value);
    }
    return _fixedNumber(decimals).format(value);
  }

  static String formatAmountValue(double value, [double? divisor]) {
    final absolute = value.abs();
    if (absolute == 0) return '0';
    final effectiveDivisor =
        divisor ?? PortfolioAmountUnitPreference.current.divisor;
    return decimalNumber(value / effectiveDivisor, maxDecimals: 2);
  }

  static String formatAmountSuffix(double value, [String? unitLabel]) {
    if (unitLabel != null) {
      return unitLabel;
    }
    return PortfolioAmountUnitPreference.current.label;
  }

  static String compactAmount(num value, [PortfolioAmountUnit? amountUnit]) {
    final unit = amountUnit ?? PortfolioAmountUnitPreference.current;
    final amount = value.toDouble();
    if (amount == 0) return '0 ${unit.label}';
    final scaled = amount / unit.divisor;
    return '${decimalNumber(scaled, maxDecimals: 2)} ${unit.label}';
  }

  static String integer(num value) => _plainNumber().format(value.round());

  /// Un montant en FCFA, écrit dans l'unité choisie en haut de l'écran
  /// (k, M ou Md) : « 1,93 Md », « 1 934,2 M », « 1 934 200 k ».
  ///
  /// C'est l'écriture des montants dans toute l'application. Un montant trop
  /// petit pour l'unité descend d'un cran plutôt que de s'afficher « 0 Md » :
  /// 28 M lus en milliards restent « 28 M ».
  ///
  /// Seul le classeur FODEP transmis garde le million, unité réglementaire de
  /// la déclaration (notice, § 2.3) : c'est le backend qui l'écrit.
  static String montant(
    num value, {
    int? maxDecimals,
    PortfolioAmountUnit? unite,
  }) {
    var unit = unite ?? PortfolioAmountUnitPreference.current;
    final valeur = value.toDouble();
    int decimales(PortfolioAmountUnit u) =>
        maxDecimals ??
        switch (u) {
          PortfolioAmountUnit.thousand => 0,
          PortfolioAmountUnit.million => 1,
          PortfolioAmountUnit.billion => 2,
        };
    bool arrondiANul(PortfolioAmountUnit u) =>
        double.parse((valeur.abs() / u.divisor).toStringAsFixed(decimales(u))) ==
        0;
    while (valeur != 0 &&
        unit != PortfolioAmountUnit.thousand &&
        arrondiANul(unit)) {
      unit = PortfolioAmountUnit.values[unit.index - 1];
    }
    return '${decimalNumber(valeur / unit.divisor, maxDecimals: decimales(unit))} '
        '${unit.label}';
  }

  /// L'unité choisie en toutes lettres, pour les en-têtes de tableau :
  /// « Milliards de FCFA ».
  static String libelleUnite([String devise = 'FCFA']) =>
      switch (PortfolioAmountUnitPreference.current) {
        PortfolioAmountUnit.thousand => 'Milliers de $devise',
        PortfolioAmountUnit.million => 'Millions de $devise',
        PortfolioAmountUnit.billion => 'Milliards de $devise',
      };

  static String percent(num value, {int decimalDigits = 2}) {
    final locale = AppLocalizations.currentLanguage.intlLocale;
    final key = '$locale:$decimalDigits';
    final formatter = _percentFormatCache.putIfAbsent(key, () {
      return NumberFormat.decimalPercentPattern(
          locale: locale, decimalDigits: decimalDigits);
    });
    return formatter.format(value).replaceAll(RegExp(r'\s+'), '');
  }

  static String shortDate(DateTime value) {
    final locale = AppLocalizations.currentLanguage.intlLocale;
    final formatter = _shortDateFormatCache.putIfAbsent(
      locale,
      () => DateFormat('dd/MM/yyyy', locale),
    );
    return formatter.format(value);
  }

  static String currencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'XOF':
      case 'XAF':
        return 'FCFA';
      case 'EUR':
        return 'EUR';
      case 'USD':
        return 'USD';
      default:
        return currencyCode.toUpperCase();
    }
  }

  static final Map<String, NumberFormat> _plainFormatCache = {};
  static final Map<String, NumberFormat> _numberFormatCache = {};

  static NumberFormat _plainNumber() {
    final locale = AppLocalizations.currentLanguage.intlLocale;
    return _plainFormatCache.putIfAbsent(
      locale,
      () => NumberFormat.decimalPattern(locale),
    );
  }

  static NumberFormat _number(int decimalDigits) {
    final locale = AppLocalizations.currentLanguage.intlLocale;
    final key = '$locale:$decimalDigits';
    return _numberFormatCache.putIfAbsent(key, () {
      return NumberFormat.decimalPattern(locale)
        ..minimumFractionDigits = 0
        ..maximumFractionDigits = decimalDigits;
    });
  }

  static NumberFormat _fixedNumber(int decimalDigits) {
    final locale = AppLocalizations.currentLanguage.intlLocale;
    final key = '$locale:fixed:$decimalDigits';
    return _numberFormatCache.putIfAbsent(key, () {
      return NumberFormat.decimalPattern(locale)
        ..minimumFractionDigits = decimalDigits
        ..maximumFractionDigits = decimalDigits;
    });
  }
}
