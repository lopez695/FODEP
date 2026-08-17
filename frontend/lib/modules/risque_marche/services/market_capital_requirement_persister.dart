/// Calcule et persiste automatiquement le RWA/capital requis "Risque de
/// Marché" (Taux + Actions + vrai risque de Change) dès que les données
/// sources changent - imports obligations/actions ou positions de change -
/// sans dépendre de la visite d'un écran de synthèse particulier. Alimente
/// la carte "Risque de Marché" du Dashboard via `/market/capital-requirement`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/foreign_exchange_repository.dart';
import 'market_data_import_store.dart';
import 'market_risk_aggregation_service.dart';

class MarketCapitalRequirementPersister {
  MarketCapitalRequirementPersister._internal();

  static final MarketCapitalRequirementPersister instance =
      MarketCapitalRequirementPersister._internal();

  bool _started = false;
  double? _lastPersistedRwa;

  /// Démarre l'observation (idempotent). À appeler une fois au démarrage de
  /// l'application, après avoir configuré le backend SQL sur
  /// [MarketDataImportStore] et [InMemoryForeignExchangeRepository].
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final fxRepository = InMemoryForeignExchangeRepository();
    fxRepository.positionsStream.listen((_) => _recompute());
    MarketDataImportStore.instance.snapshotNotifier.addListener(_recompute);

    await Future.wait([
      MarketDataImportStore.instance.initialized,
      fxRepository.initialized,
    ]);
    _recompute();
  }

  void _recompute() {
    final api = MarketDataImportStore.instance.sqlBackendApi;
    if (api == null) return;

    final snapshot = MarketDataImportStore.instance.snapshotNotifier.value;
    final records = [
      ...?snapshot.datasets[MarketPortfolioType.bonds]?.records,
      ...?snapshot.datasets[MarketPortfolioType.equities]?.records,
    ];
    final fxPositions = InMemoryForeignExchangeRepository().currentPositions;

    final r = applyRealForeignExchangeRisk(
      calculateMarketPrudentialCapital(records: records),
      fxPositions,
    );

    if (_lastPersistedRwa == r.marketRwa) return;
    _lastPersistedRwa = r.marketRwa;
    unawaited(
      api
          .saveMarketCapitalRequirement(
            rwaMarche: r.marketRwa,
            capitalRequis: r.capitalRequirement,
            exigenceTaux: r.interestRateRisk,
            exigenceActions: r.equityRisk,
            exigenceChange: r.foreignExchangeRisk,
            exigenceProduitsDeBase: r.commodityRisk,
            positions: positionsMarchePourFodep(r),
          )
          .catchError((Object error, StackTrace stackTrace) {
        debugPrint('Persist capital requis marché (global) failed: $error');
      }),
    );
  }
}
