import 'dart:ui';

enum AppLanguage {
  francais,
  anglais;

  Locale get locale {
    switch (this) {
      case AppLanguage.francais:
        return const Locale('fr', 'FR');
      case AppLanguage.anglais:
        return const Locale('en', 'US');
    }
  }

  String get intlLocale {
    switch (this) {
      case AppLanguage.francais:
        return 'fr_FR';
      case AppLanguage.anglais:
        return 'en_US';
    }
  }

  String get shortLabel {
    switch (this) {
      case AppLanguage.francais:
        return 'Fr';
      case AppLanguage.anglais:
        return 'En';
    }
  }
}
