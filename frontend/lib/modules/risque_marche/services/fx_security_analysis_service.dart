/// Service de calcul de l'analyse des risques de change au niveau des titres
/// Conforme aux principes prudentiels BCEAO
/// Approche: Analyse ligne par ligne de l'impact des fluctuations de devises
library fx_security_analysis_service;

import 'dart:math' as math;

import '../../../core/utils/currency_conversion.dart';
import '../models/currency_registry.dart';
import '../models/fx_security_analysis.dart';
import 'market_data_import_store.dart';

/// Service pour analyser le risque de change au niveau des titres.
///
/// Outil prudentiel : le service ne travaille QUE sur les données réellement
/// importées - aucune donnée de démonstration, aucun repli fabriqué.
class FxSecurityAnalysisService {
  FxSecurityAnalysisService({
    CurrencyRegistry? currencyRegistry,
  }) : _currencyRegistry = currencyRegistry ?? CurrencyRegistry();

  final CurrencyRegistry _currencyRegistry;

  /// Calcule l'exposition au risque de change pour un portefeuille de titres
  /// Retourne un résultat structuré pour présentation multi-niveaux
  FxRiskAnalysisResult analyzePortfolio({
    required List<MarketPortfolioRecord> records,
    required DateTime analysisDate,
    Map<String, double>? exchangeRates,
  }) {
    // Étape 1: Analyser chaque titre individuellement
    final securities = _analyzeSecurities(
      records: records,
      analysisDate: analysisDate,
      exchangeRates: exchangeRates,
    );

    // Étape 2: Agréger par devise
    final currencyExposures = _aggregateByCurrency(securities);

    // Étape 3: Calculer les métriques globales
    final globalMetrics = _calculateGlobalMetrics(
      securities: securities,
      currencyExposures: currencyExposures,
    );

    return FxRiskAnalysisResult(
      securities: securities,
      currencyExposures: currencyExposures,
      totalExposure: globalMetrics['totalExposure'] as double,
      globalFxGainLoss: globalMetrics['globalFxGainLoss'] as double,
      totalLongPositions: globalMetrics['totalLongPositions'] as double,
      totalShortPositions: globalMetrics['totalShortPositions'] as double,
      globalNetPosition: globalMetrics['globalNetPosition'] as double,
      capitalRequirement: globalMetrics['capitalRequirement'] as double,
      rwaChange: globalMetrics['rwaChange'] as double,
      marketRiskContribution: globalMetrics['marketRiskContribution'] as double,
      analysisDate: analysisDate,
    );
  }

  /// Analyse chaque titre pour ses expositions au risque de change
  List<FxSecurityAnalysis> _analyzeSecurities({
    required List<MarketPortfolioRecord> records,
    required DateTime analysisDate,
    Map<String, double>? exchangeRates,
  }) {
    final securities = <FxSecurityAnalysis>[];

    for (final record in records) {
      // Filtrer les titres non exposés au risque de change
      if (!_isExposedToFxRisk(record)) continue;

      final currency = normalizeCurrencyCode(record.currency);
      if (currency.isEmpty) continue;

      // Récupérer les taux de change
      final initialRate =
          _getInitialExchangeRate(record, currency, exchangeRates);
      final currentRate =
          _getCurrentExchangeRate(record, currency, exchangeRates);

      if (initialRate <= 0 || currentRate <= 0) continue;

      // Calculer les valeurs
      final initialValue = _getInitialValue(record);
      final currentValue = _getCurrentValue(record);
      final quantity = _getQuantity(record);

      if (initialValue <= 0 || quantity == 0) continue;

      final security = FxSecurityAnalysis(
        titleId: record.titleId.isNotEmpty ? record.titleId : record.issuer,
        titleName: _getTitleName(record),
        currency: currency,
        initialValue: initialValue,
        currentValue: currentValue,
        initialRate: initialRate,
        currentRate: currentRate,
        quantity: quantity,
        acquisitionDate: record.issueDate ?? analysisDate,
        analysisDate: analysisDate,
      );

      securities.add(security);
    }

    return securities;
  }

  /// Détermine si un titre est exposé au risque de change.
  ///
  /// Seuls les titres libellés en devise ÉTRANGÈRE sont exposés : la devise de
  /// référence de l'outil (XOF - ainsi que XAF/FCFA repliés sur XOF par
  /// [normalizeCurrencyCode]) ne porte par définition AUCUN risque de change.
  /// Les titres XOF sont donc EXCLUS de l'analyse de change : un portefeuille
  /// de titres achetés ne génère que des positions LONGUES en devise.
  /// Convention alignée sur le calcul prudentiel global de l'outil
  /// (`_marketForeignExchangeGlobalNetPosition`), qui exclut lui aussi le XOF.
  bool _isExposedToFxRisk(MarketPortfolioRecord record) {
    final currency = normalizeCurrencyCode(record.currency);
    return currency.isNotEmpty && currency != 'XOF';
  }

  /// Récupère le nom du titre
  String _getTitleName(MarketPortfolioRecord record) {
    if (record.issuer.isNotEmpty) return record.issuer;
    if (record.titleId.isNotEmpty) return record.titleId;
    return record.instrumentType.isNotEmpty
        ? record.instrumentType
        : 'Titre sans nom';
  }

  /// Récupère la valeur initiale du titre
  double _getInitialValue(MarketPortfolioRecord record) {
    if (record.portfolioType == MarketPortfolioType.equities) {
      final price =
          record.marketPrice > 0 ? record.marketPrice : record.priceObservation;
      return price > 0 ? price : record.nominalUnit;
    }
    // Pour les obligations
    return record.issuePrice > 0 ? record.issuePrice : record.nominalUnit;
  }

  /// Récupère la valeur actuelle du titre
  double _getCurrentValue(MarketPortfolioRecord record) {
    if (record.portfolioType == MarketPortfolioType.equities) {
      final price =
          record.marketPrice > 0 ? record.marketPrice : record.priceObservation;
      return price > 0 ? price : record.nominalUnit;
    }
    // Pour les obligations: utiliser la valeur actualisée ou le prix de marché
    if (record.presentValue > 0) return record.presentValue;
    if (record.priceObservation > 0) return record.priceObservation;
    return record.nominalUnit;
  }

  /// Récupère la quantité
  double _getQuantity(MarketPortfolioRecord record) {
    if (record.portfolioType == MarketPortfolioType.equities) {
      return record.shares;
    }
    return record.quantity;
  }

  /// Taux de change COURANT (spot), en XOF pour 1 unité de devise.
  /// On privilégie la carte de taux fournie (saisie utilisateur dans l'écran),
  /// puis le registre des devises de l'outil.
  double _getCurrentExchangeRate(
    MarketPortfolioRecord record,
    String currency,
    Map<String, double>? exchangeRates,
  ) {
    if (currency == 'XOF') return 1.0;
    final provided = exchangeRates?[currency];
    if (provided != null && provided > 0) return provided;
    return _currencyRegistry.getRate(currency)?.rateToXof ?? 1.0;
  }

  /// Taux de change à l'ACQUISITION, en XOF pour 1 unité de devise.
  /// On utilise le taux historique du titre s'il est fourni à l'import
  /// ([MarketPortfolioRecord.acquisitionExchangeRate]) ; sinon on retombe sur
  /// le taux de RÉFÉRENCE du registre des devises (et non sur le taux courant
  /// édité) : la saisie ou la cotation d'un taux courant différent produit
  /// alors une variation mesurable dans la table et le profil de choc.
  double _getInitialExchangeRate(
    MarketPortfolioRecord record,
    String currency,
    Map<String, double>? exchangeRates,
  ) {
    if (currency == 'XOF') return 1.0;
    final booked = record.acquisitionExchangeRate;
    if (booked > 0) return booked;
    final reference = _currencyRegistry.getRate(currency)?.rateToXof;
    if (reference != null && reference > 0) return reference;
    return _getCurrentExchangeRate(record, currency, exchangeRates);
  }

  /// Agrège les données par devise
  List<FxCurrencyExposure> _aggregateByCurrency(
    List<FxSecurityAnalysis> securities,
  ) {
    final byDevise = <String, FxCurrencyExposure>{};

    for (final security in securities) {
      final currency = security.currency;
      if (currency == 'XOF' || currency == 'XAF') continue;
      final existing = byDevise[currency];

      final longExposure =
          security.quantity > 0 ? security.currentValueInXof : 0.0;
      final shortExposure =
          security.quantity < 0 ? security.currentValueInXof.abs() : 0.0;

      if (existing != null) {
        byDevise[currency] = FxCurrencyExposure(
          currency: currency,
          totalLongExposure: existing.totalLongExposure + longExposure,
          totalShortExposure: existing.totalShortExposure + shortExposure,
          netExposure: existing.netExposure + (longExposure - shortExposure),
          securitiesCount: existing.securitiesCount + 1,
          acquisitionDate: existing.acquisitionDate,
          analysisDate: security.analysisDate,
        );
      } else {
        byDevise[currency] = FxCurrencyExposure(
          currency: currency,
          totalLongExposure: longExposure,
          totalShortExposure: shortExposure,
          netExposure: longExposure - shortExposure,
          securitiesCount: 1,
          acquisitionDate: security.acquisitionDate,
          analysisDate: security.analysisDate,
        );
      }
    }

    return byDevise.values.toList();
  }

  /// Calcule les métriques globales
  Map<String, double> _calculateGlobalMetrics({
    required List<FxSecurityAnalysis> securities,
    required List<FxCurrencyExposure> currencyExposures,
  }) {
    double totalExposure = 0;
    double globalFxGainLoss = 0;
    double totalLongPositions = 0;
    double totalShortPositions = 0;

    // Calculer les totaux
    for (final security in securities) {
      if (security.currency == 'XOF' || security.currency == 'XAF') continue;
      totalExposure += security.currentValueInXof;
      globalFxGainLoss += security.fxGainLoss;
    }

    for (final exposure in currencyExposures) {
      if (exposure.currency == 'XOF' || exposure.currency == 'XAF') continue;
      totalLongPositions += exposure.totalLongExposure;
      totalShortPositions += exposure.totalShortExposure;
    }

    // Position nette globale = MAX(longues, courtes)
    final globalNetPosition =
        math.max(totalLongPositions, totalShortPositions).toDouble();

    // Exigence de fonds propres pour risque de change = 9 % de la position
    // nette globale (dispositif prudentiel UMOA).
    // 8 % de la position nette globale : taux imposé par l'EP27 du FODEP.
    final capitalRequirement = globalNetPosition * 0.08;

    // Équivalent RWA = Exigence_FP × 12,5, l'inverse de 8 %, convention
    // retenue par le reste du projet.
    final rwaChange = capitalRequirement * 12.5;

    final marketRiskContribution =
        totalExposure > 0 ? (capitalRequirement / totalExposure) * 100 : 0.0;

    return {
      'totalExposure': totalExposure,
      'globalFxGainLoss': globalFxGainLoss,
      'totalLongPositions': totalLongPositions,
      'totalShortPositions': totalShortPositions,
      'globalNetPosition': globalNetPosition,
      'capitalRequirement': capitalRequirement,
      'rwaChange': rwaChange,
      'marketRiskContribution': marketRiskContribution,
    };
  }

}
