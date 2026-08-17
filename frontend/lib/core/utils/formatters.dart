// Ce fichier regroupe les formateurs utilises dans l'interface.
import 'package:intl/intl.dart';

import '../localization/app_localization.dart';

/// Top-level formatter functions for easy access
String formatLargeNumber(num value) => AppFormatters.compactNumber(value);

String formatDecimal(num value, int decimals) =>
    AppFormatters.decimalNumber(value, maxDecimals: decimals);

/// Centralise les formats d'affichage des montants, pourcentages et dates.
class AppFormatters {
  static final Map<String, NumberFormat> _currencyFormatCache = {};
  static final Map<String, NumberFormat> _percentFormatCache = {};
  static final Map<String, DateFormat> _shortDateFormatCache = {};

  static String currency(num value, {String currencyCode = 'XOF'}) {
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
    if (divisor != null && divisor > 0) {
      return decimalNumber(value / divisor, maxDecimals: 2);
    }
    if (absolute < 1000000) {
      return decimalNumber(value, maxDecimals: 2);
    } else if (absolute < 1000000000) {
      return decimalNumber(value / 1000000, maxDecimals: 2);
    } else {
      return decimalNumber(value / 1000000000, maxDecimals: 2);
    }
  }

  static String formatAmountSuffix(double value, [String? unitLabel]) {
    if (unitLabel != null) {
      return unitLabel;
    }
    final absolute = value.abs();
    if (absolute == 0) return '';
    if (absolute < 1000000) {
      return '';
    } else if (absolute < 1000000000) {
      return 'M';
    } else {
      return 'Md';
    }
  }

  static String compactAmount(num value) {
    final amount = value.toDouble();
    final absolute = amount.abs();
    if (absolute == 0) return '0';
    if (absolute >= 1000000000) {
      return '${decimalNumber(amount / 1000000000, maxDecimals: 2)} Md';
    } else if (absolute >= 1000000) {
      return '${decimalNumber(amount / 1000000, maxDecimals: 2)} M';
    } else if (absolute >= 1000) {
      return '${decimalNumber(amount / 1000, maxDecimals: 2)} k';
    } else {
      return decimalNumber(amount, maxDecimals: 2);
    }
  }

  static String integer(num value) => _plainNumber().format(value.round());

  /// Formate un montant (exprime dans l'unite de base, ex. XOF) en millions
  /// avec separateur de milliers, ex. 1934000000 -> "1 934 M".
  static String millions(num value) {
    return '${decimalNumber(value / 1000000, maxDecimals: 0)} M';
  }

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
