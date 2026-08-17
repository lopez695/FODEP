/// Référentiel des devises et taux de conversion
/// Utilisé pour convertir les positions en devise de référence (XOF)
library;

/// Représente une devise avec son taux de change
class CurrencyRate {
  const CurrencyRate({
    required this.code,
    required this.label,
    required this.rateToXof,
    required this.lastUpdate,
  });

  final String code; // Code devise (USD, EUR, etc.)
  final String label; // Libellé complet
  final double rateToXof; // Taux de change vers XOF
  final DateTime lastUpdate; // Date de mise à jour du taux

  /// Convertit une montant depuis cette devise vers XOF
  double toXof(double amount) => amount * rateToXof;

  /// Convertit un montant depuis XOF vers cette devise
  double fromXof(double xofAmount) => xofAmount / rateToXof;
}

/// Référentiel des devises principales
class CurrencyRegistry {
  static final CurrencyRegistry _instance = CurrencyRegistry._internal();

  factory CurrencyRegistry() {
    return _instance;
  }

  CurrencyRegistry._internal();

  // Devises principales (XOF, EUR, USD) alignées sur `currency_conversion.dart`
  // et le backend (`calculations.py`) pour garantir une source unique.
  // XAF/FCFA sont repliés vers XOF par `normalizeCurrencyCode`.
  //
  // Les autres devises portent une CONTRE-VALEUR DE RÉFÉRENCE INDICATIVE en
  // XOF (cohérente avec 1 USD = 600 XOF) : elle sert de taux d'acquisition par
  // défaut et de point de départ dans la barre des taux, où l'utilisateur
  // saisit ou cote le taux courant réel.
  final Map<String, CurrencyRate> _rates = {
    'XOF': CurrencyRate(
      code: 'XOF',
      label: 'Franc CFA BCEAO',
      rateToXof: 1.0,
      lastUpdate: DateTime(2026, 6, 17),
    ),
    'EUR': CurrencyRate(
      code: 'EUR',
      label: 'Euro',
      rateToXof: 655.957, // Parité fixe FCFA/Euro
      lastUpdate: DateTime(2026, 6, 17),
    ),
    'USD': CurrencyRate(
      code: 'USD',
      label: 'Dollar américain',
      rateToXof: 600.0,
      lastUpdate: DateTime(2026, 6, 17),
    ),
    'GBP': CurrencyRate(
      code: 'GBP',
      label: 'Livre sterling',
      rateToXof: 760.0,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'CHF': CurrencyRate(
      code: 'CHF',
      label: 'Franc suisse',
      rateToXof: 660.0,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'JPY': CurrencyRate(
      code: 'JPY',
      label: 'Yen japonais',
      rateToXof: 4.0,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'CNY': CurrencyRate(
      code: 'CNY',
      label: 'Yuan chinois',
      rateToXof: 83.0,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'MAD': CurrencyRate(
      code: 'MAD',
      label: 'Dirham marocain',
      rateToXof: 60.0,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'TND': CurrencyRate(
      code: 'TND',
      label: 'Dinar tunisien',
      rateToXof: 190.0,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'EGP': CurrencyRate(
      code: 'EGP',
      label: 'Livre égyptienne',
      rateToXof: 12.5,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'NGN': CurrencyRate(
      code: 'NGN',
      label: 'Naira nigérian',
      rateToXof: 0.40,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'GHS': CurrencyRate(
      code: 'GHS',
      label: 'Cedi ghanéen',
      rateToXof: 40.0,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'ZAR': CurrencyRate(
      code: 'ZAR',
      label: 'Rand sud-africain',
      rateToXof: 32.5,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'KES': CurrencyRate(
      code: 'KES',
      label: 'Shilling kényan',
      rateToXof: 4.65,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'ZMW': CurrencyRate(
      code: 'ZMW',
      label: 'Kwacha zambien',
      rateToXof: 22.0,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'BWP': CurrencyRate(
      code: 'BWP',
      label: 'Pula botswanais',
      rateToXof: 44.0,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'CDF': CurrencyRate(
      code: 'CDF',
      label: 'Franc congolais',
      rateToXof: 0.21,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'GNF': CurrencyRate(
      code: 'GNF',
      label: 'Franc guinéen',
      rateToXof: 0.07,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'SOS': CurrencyRate(
      code: 'SOS',
      label: 'Shilling somalien',
      rateToXof: 1.05,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'SSP': CurrencyRate(
      code: 'SSP',
      label: 'Livre sud-soudanaise',
      rateToXof: 0.13,
      lastUpdate: DateTime(2026, 7, 8),
    ),
    'ZWG': CurrencyRate(
      code: 'ZWG',
      label: 'Dollar zimbabwéen',
      rateToXof: 22.0,
      lastUpdate: DateTime(2026, 7, 8),
    ),
  };

  /// Récupère le taux de change pour une devise
  CurrencyRate? getRate(String currencyCode) => _rates[currencyCode];

  /// Retourne toutes les devises disponibles
  List<CurrencyRate> getAllRates() => _rates.values.toList();

  /// Met à jour un taux de change
  void updateRate(String currencyCode, double newRate) {
    final existing = _rates[currencyCode];
    if (existing != null) {
      _rates[currencyCode] = CurrencyRate(
        code: existing.code,
        label: existing.label,
        rateToXof: newRate,
        lastUpdate: DateTime.now(),
      );
    }
  }
}

/// Analyse statistique des positions
class PositionAnalysis {
  const PositionAnalysis({
    required this.totalDevises,
    required this.longPositions,
    required this.shortPositions,
    required this.neutralPositions,
    required this.averagePositionSize,
    required this.largestLongPosition,
    required this.largestShortPosition,
    required this.concentrationRatio,
  });

  final int totalDevises; // Nombre de devises
  final int longPositions; // Nombre de positions longues
  final int shortPositions; // Nombre de positions courtes
  final int neutralPositions; // Nombre de positions neutres
  final double averagePositionSize; // Taille moyenne en XOF
  final double largestLongPosition; // Plus grande position longue
  final double largestShortPosition; // Plus grande position courte
  final double concentrationRatio; // Ratio de concentration (0-1)
}
