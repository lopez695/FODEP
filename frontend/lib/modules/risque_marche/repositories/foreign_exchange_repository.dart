/// Repository pour la gestion des positions de change
/// Abstraction pour permettre stockage en BD, SharedPreferences, ou en mémoire
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/rwa_api_service.dart';
import '../services/foreign_exchange_risk_service.dart';

/// Interface pour la persistance des positions de change
abstract class ForeignExchangeRepository {
  /// Récupère toutes les positions de change
  Future<List<ForeignExchangePosition>> getAllPositions();

  /// Ajoute ou met à jour une position pour une devise
  Future<void> savePosition(ForeignExchangePosition position);

  /// Supprime une position pour une devise
  Future<void> deletePosition(String currency);

  /// Efface toutes les positions
  Future<void> clearAll();

  /// Écoute les changements (stream pour UI reactive)
  Stream<List<ForeignExchangePosition>> get positionsStream;
}

/// Implémentation en mémoire, avec persistance optionnelle vers le backend
/// SQL (voir [configureSqlBackend]) - même mécanisme que
/// `MarketDataImportStore.configureSqlBackend`.
class InMemoryForeignExchangeRepository implements ForeignExchangeRepository {
  final Map<String, ForeignExchangePosition> _positions = {};
  final _positionsController =
      StreamController<List<ForeignExchangePosition>>.broadcast();

  static final InMemoryForeignExchangeRepository _instance =
      InMemoryForeignExchangeRepository._internal();

  factory InMemoryForeignExchangeRepository() {
    return _instance;
  }

  InMemoryForeignExchangeRepository._internal();

  bool _sqlModeEnabled = false;
  RwaApiService? _sqlBackendApi;
  Future<void>? _restoreFuture;

  /// Se termine une fois la restauration depuis le backend (ou l'échec de
  /// celle-ci) prise en compte. Toujours résolu si [configureSqlBackend] n'a
  /// jamais été appelé (mode purement local).
  Future<void> get initialized => _restoreFuture ?? Future.value();

  /// Branche ce repository sur le backend SQL : restaure les positions
  /// persistées au premier appel, puis persiste toute mutation ultérieure.
  /// Idempotent - les appels suivants renvoient le même futur.
  Future<void> configureSqlBackend(RwaApiService api) {
    final existing = _restoreFuture;
    if (existing != null) return existing;
    _sqlModeEnabled = true;
    _sqlBackendApi = api;
    _restoreFuture = _restoreFromBackend(api);
    return _restoreFuture!;
  }

  Future<void> _restoreFromBackend(RwaApiService api) async {
    try {
      final rows = await api.fetchFxPositions();
      if (rows.isNotEmpty) {
        _positions
          ..clear()
          ..addEntries(rows.map((row) {
            final position = ForeignExchangePosition.fromJson(row);
            return MapEntry(position.currency, position);
          }));
        _notifyListeners();
      }
      // Rien de persisté : le portefeuille de change reste VIDE. Outil
      // prudentiel : aucune position fictive n'est jamais injectée - seules
      // les positions réellement saisies ou importées par l'utilisateur sont
      // affichées et prises en compte dans le calcul.
    } catch (error) {
      debugPrint('Restauration des positions de change indisponible: $error');
    }
  }

  Future<void> _persist() async {
    final api = _sqlBackendApi;
    if (!_sqlModeEnabled || api == null) return;
    try {
      await api.saveFxPositions(
        _positions.values.map((p) => p.toJson()).toList(),
      );
    } catch (error) {
      debugPrint('Persist positions de change failed: $error');
    }
  }

  @override
  Future<List<ForeignExchangePosition>> getAllPositions() async {
    return List.from(_positions.values);
  }

  /// Accès synchrone aux positions actuelles (pour les observateurs qui
  /// doivent recalculer immédiatement, sans passer par le Future de
  /// [getAllPositions]).
  List<ForeignExchangePosition> get currentPositions =>
      List.from(_positions.values);

  @override
  Future<void> savePosition(ForeignExchangePosition position) async {
    _positions[position.currency] = position;
    _notifyListeners();
    unawaited(_persist());
  }

  @override
  Future<void> deletePosition(String currency) async {
    _positions.remove(currency);
    _notifyListeners();
    unawaited(_persist());
  }

  @override
  Future<void> clearAll() async {
    _positions.clear();
    _notifyListeners();
    unawaited(_persist());
  }

  @override
  Stream<List<ForeignExchangePosition>> get positionsStream =>
      _positionsController.stream;

  void _notifyListeners() {
    _positionsController.add(List.from(_positions.values));
  }

  void dispose() {
    _positionsController.close();
  }
}
