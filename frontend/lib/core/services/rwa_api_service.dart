// Ce fichier centralise l'acces aux donnees du backend.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../modules/crm/models/crm_models.dart';
import '../../modules/dashboard/models/dashboard_models.dart';
import '../../modules/expositions/models/exposition_models.dart';
import '../../modules/expositions/models/suivi_versements_models.dart';
import '../../modules/hors_bilan/models/hors_bilan_models.dart';
import '../../modules/rapports/models/report_models.dart';
import '../../modules/participations/models/participation_models.dart';
import '../../modules/referentiels/models/referentiels_models.dart';
import '../../modules/risque_operationnel/models/ro_models.dart';
//
import '../../modules/rwa_engine/models/rwa_credit_analysis.dart';
import 'api_client.dart';
import 'api_runtime_environment.dart' as runtime_environment;

String _resolveDefaultApiBaseUrl() {
  final runtimeBaseUrl =
      runtime_environment.runtimeEnvironmentValue('RWA_API_BASE_URL')?.trim();
  if (runtimeBaseUrl != null && runtimeBaseUrl.isNotEmpty) {
    return runtimeBaseUrl;
  }

  const buildBaseUrl = String.fromEnvironment('RWA_API_BASE_URL');
  if (buildBaseUrl.isNotEmpty) {
    return buildBaseUrl;
  }

  // Dans un navigateur, l'API est servie par le meme domaine que
  // l'application, derriere le proxy inverse : une adresse relative evite
  // toute origine croisee, donc tout CORS, et suit le domaine sans
  // reconstruction. `window.RWA_CONFIG` permet de pointer ailleurs si besoin.
  if (kIsWeb) {
    // Adresse absolue construite sur l'origine de la page : elle suit le
    // domaine sans reconstruction, et evite les surprises des URL relatives
    // selon le client HTTP du navigateur.
    return '${Uri.base.origin}/api';
  }

  final runtimeHost =
      runtime_environment.runtimeEnvironmentValue('RWA_API_HOST')?.trim();
  final runtimePort =
      runtime_environment.runtimeEnvironmentValue('RWA_API_PORT')?.trim();
  final host =
      runtimeHost == null || runtimeHost.isEmpty ? '127.0.0.1' : runtimeHost;
  final port =
      runtimePort == null || runtimePort.isEmpty ? '8001' : runtimePort;
  return 'http://$host:$port';
}

class MarketPortfolioPayloadResponse {
  const MarketPortfolioPayloadResponse({
    required this.isEmpty,
    this.payload,
  });

  final bool isEmpty;
  final Map<String, dynamic>? payload;
}

/// Service principal qui orchestre les appels API métier.
class RwaApiService {
  RwaApiService({
    String? baseUrl,
    ApiClient? client,
    String? Function()? tokenProvider,
    Future<bool> Function()? onUnauthorized,
  }) : _client = client ??
            ApiClient(
              baseUrl: baseUrl ?? _resolveDefaultApiBaseUrl(),
              tokenProvider: tokenProvider,
              onUnauthorized: onUnauthorized,
            );

  /// URL de l'API telle que résolue par défaut.
  ///
  /// Exposée pour que la session s'adresse exactement au même backend que les
  /// appels métier : deux résolutions séparées finiraient par diverger.
  static String resolveDefaultBaseUrl() => _resolveDefaultApiBaseUrl();

  final ApiClient _client;
  final StreamController<int> _portfolioRefreshController =
      StreamController<int>.broadcast();
  int _portfolioRefreshTick = 0;
  Future<DashboardSnapshot>? _dashboardFuture;
  Future<ExposureModuleData>? _expositionsFuture;
  Future<OffBalanceModuleData>? _horsBilanFuture;
  Future<CrmModuleData>? _crmFuture;
  Future<ReferentielsModuleData>? _referentielsFuture;
  Future<ReportsModuleData>? _reportsFuture;

  Stream<int> get portfolioRefreshStream => _portfolioRefreshController.stream;

  Future<Map<String, dynamic>> refreshCemacYieldCurves() async {
    final payload =
        await _client.post('/market/yield-curves/cemac/refresh', {});
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    throw StateError('Réponse CEMAC invalide.');
  }

  /// Appelle un endpoint VaR du backend (/api/var/historique,
  /// /api/var/parametrique ou /api/var/montecarlo). Tous les calculs sont
  /// effectués côté serveur ; le client ne fait que de l'affichage.
  Future<Map<String, dynamic>> fetchVarAnalysis({
    required String methode,
    required String typePortefeuille,
    required double niveauConfiance,
    required int horizonJours,
    required int fenetreJours,
    double? volatilite,
    double? durationModifiee,
    double? valeurPortefeuille,
    double? beta,
    int? nbSimulations,
    int? graine,
  }) async {
    final query = StringBuffer(
      '/api/var/$methode'
      '?type_portefeuille=$typePortefeuille'
      '&niveau_confiance=$niveauConfiance'
      '&horizon_jours=$horizonJours'
      '&fenetre_jours=$fenetreJours',
    );
    if (volatilite != null) {
      query.write('&volatilite=$volatilite');
    }
    if (durationModifiee != null) {
      query.write('&duration_modifiee=$durationModifiee');
    }
    if (valeurPortefeuille != null) {
      query.write('&valeur_portefeuille=$valeurPortefeuille');
    }
    if (beta != null) {
      query.write('&beta=$beta');
    }
    if (nbSimulations != null) {
      query.write('&nb_simulations=$nbSimulations');
    }
    if (graine != null) {
      query.write('&graine=$graine');
    }
    final payload = await _client.get(query.toString());
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    throw StateError('Réponse VaR invalide.');
  }

  Future<MarketPortfolioPayloadResponse> fetchMarketPortfolioPayload() async {
    final response = await _client.get('/market/portfolios');
    if (response is! Map) {
      throw StateError('Réponse portefeuille marché invalide.');
    }
    final map = Map<String, dynamic>.from(response);
    if (map['empty'] == true) {
      return const MarketPortfolioPayloadResponse(isEmpty: true);
    }
    final data = map['payload'];
    if (data is Map<String, dynamic>) {
      return MarketPortfolioPayloadResponse(isEmpty: false, payload: data);
    }
    if (data is Map) {
      return MarketPortfolioPayloadResponse(
        isEmpty: false,
        payload: Map<String, dynamic>.from(data),
      );
    }
    throw StateError('Payload portefeuille marché invalide.');
  }

  Future<void> saveMarketPortfolioPayload(
    Map<String, Object?> payload,
  ) async {
    await _client.put('/market/portfolios', {'payload': payload});
  }

  Future<void> uploadVarHistory(
    Uint8List bytes,
    String fileName,
  ) async {
    await _client.uploadBytes(
      '/market/upload-var-history',
      bytes,
      fileName,
    );
  }

  Future<Uint8List> downloadVarHistoryTemplate() async {
    return _client.getBytes('/market/var-history-template');
  }

  /// Actualise en ligne la courbe de taux UEMOA (UMOA-Titres) pour le pays
  /// demandé et l'installe comme courbe active du calcul VaR obligataire.
  /// Retourne le résumé de la courbe récupérée (pays, date, nombre de points).
  Future<Map<String, dynamic>> actualiserCourbeUemoa(String pays) async {
    final payload = await _client.post(
      '/api/var/actualiser-courbe?pays=${Uri.encodeQueryComponent(pays)}',
      const {},
    );
    return payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
  }

  /// Liste des pays UEMOA dont la courbe de taux est actualisable en ligne.
  Future<List<String>> fetchPaysCourbe() async {
    final payload = await _client.get('/api/var/courbe/pays');
    if (payload is! Map) return const [];
    final pays = payload['pays'];
    return pays is List ? pays.map((e) => e.toString()).toList() : const [];
  }

  Future<List<Map<String, dynamic>>> fetchFxPositions() async {
    final payload = await _client.get('/market/fx-positions');
    if (payload is! Map) return [];
    final map = Map<String, dynamic>.from(payload);
    final data = map['payload'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> saveFxPositions(List<Map<String, Object?>> positions) async {
    await _client.put('/market/fx-positions', {'payload': positions});
  }

  /// Persiste le capital requis marché, et sa ventilation par nature quand
  /// elle est connue.
  ///
  /// Les quatre natures correspondent aux lignes RM044, RM057, RM067 et RM123
  /// de l'EP08 du FODEP : sans elles, le formulaire ne peut déclarer que le
  /// total et laisse ses lignes de détail à zéro.
  Future<void> saveMarketCapitalRequirement({
    required double rwaMarche,
    required double capitalRequis,
    double? exigenceTaux,
    double? exigenceActions,
    double? exigenceChange,
    double? exigenceProduitsDeBase,
    Map<String, Object?>? positions,
  }) async {
    final detailConnu = exigenceTaux != null &&
        exigenceActions != null &&
        exigenceChange != null &&
        exigenceProduitsDeBase != null;
    await _client.put('/market/capital-requirement', {
      'rwa_marche': rwaMarche,
      'capital_requis': capitalRequis,
      if (detailConnu)
        'ventilation': {
          'taux': exigenceTaux,
          'actions': exigenceActions,
          'change': exigenceChange,
          'produits_de_base': exigenceProduitsDeBase,
        },
      // Positions longues et courtes : sans elles, les états EP26 et EP27 ne
      // peuvent déclarer que leur exigence, pas l'assiette qui la produit.
      if (positions != null) 'positions': positions,
    });
    // Le RWA Marché stocké ici alimente directement rwa_total côté dashboard
    // (resolve_market_capital) - même raison d'invalidation que pour le BIC.
    _dashboardFuture = null;
  }

  // ─── Participations (EP34, EP35, normes RA006 à RA008 de l'EP01) ─────────

  Future<List<Participation>> fetchParticipations() async {
    final json = await _client.get('/participations') as List<dynamic>;
    return json
        .map((item) => Participation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Synthèse des participations : totaux, fonds propres, immobilisations et
  /// les cinq limites de l'EP01 qui les encadrent.
  Future<SyntheseParticipations> fetchSyntheseParticipations() async {
    final json = await _client.get('/participations/synthese');
    return SyntheseParticipations.fromJson(
      Map<String, dynamic>.from(json as Map),
    );
  }

  Future<void> createParticipation(Participation participation) async {
    await _client.post('/participations', participation.toPayload());
  }

  Future<void> updateParticipation(Participation participation) async {
    await _client.put(
      '/participations/${participation.id}',
      participation.toPayload(),
    );
  }

  Future<void> deleteParticipation(int id) async {
    await _client.delete('/participations/$id');
  }

  // ─── Groupes de clients liés (EP30, division des risques) ────────────────

  Future<List<GroupeClients>> fetchGroupesClients() async {
    final json = await _client.get('/groupes-clients') as List<dynamic>;
    return json
        .map((item) => GroupeClients.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Concentration des risques par groupe, pour l'écran de détail.
  Future<ConcentrationGroupes> fetchConcentrationGroupes() async {
    final json = await _client.get('/groupes-clients/concentration');
    return ConcentrationGroupes.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> createGroupeClients({
    required String nom,
    String? numeroCentraleRisques,
  }) async {
    await _client.post('/groupes-clients', {
      'nom': nom,
      if (numeroCentraleRisques != null && numeroCentraleRisques.isNotEmpty)
        'numero_centrale_risques': numeroCentraleRisques,
    });
  }

  Future<void> updateGroupeClients({
    required int id,
    String? nom,
    String? numeroCentraleRisques,
  }) async {
    await _client.put('/groupes-clients/$id', {
      if (nom != null && nom.isNotEmpty) 'nom': nom,
      'numero_centrale_risques':
          (numeroCentraleRisques ?? '').isEmpty ? null : numeroCentraleRisques,
    });
  }

  Future<void> deleteGroupeClients(int id) async {
    await _client.delete('/groupes-clients/$id');
  }

  /// Contreparties du portefeuille ; [sansGroupe] ne retient que celles qui
  /// ne sont encore rattachées à aucun groupe.
  Future<List<ContrepartieRattachement>> fetchContrepartiesRattachement({
    bool sansGroupe = false,
  }) async {
    final chemin = '/groupes-clients/contreparties/liste'
        '${sansGroupe ? '?sans_groupe=true' : ''}';
    final json = await _client.get(chemin) as List<dynamic>;
    return json
        .map((item) =>
            ContrepartieRattachement.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Rattache une contrepartie à un groupe et complète son identification.
  /// [groupeId] à null la détache.
  Future<void> rattacherContrepartie({
    required String contrepartieId,
    int? groupeId,
    CategorieLien? categorieLien,
    String? numeroCentraleRisques,
    String? secteurActivite,
    CategoriePartieLiee? categoriePartieLiee,
  }) async {
    await _client.put('/groupes-clients/contreparties/$contrepartieId', {
      'groupe_id': groupeId,
      'categorie_lien': categorieLien?.wire,
      'numero_centrale_risques': numeroCentraleRisques,
      'secteur_activite': secteurActivite,
      'categorie_partie_liee': categoriePartieLiee?.wire,
    });
  }

  // ─── Risque Opérationnel ─────────────────────────────────────────────────

  Future<RoDashboardData> fetchRoDashboard() async {
    final json = await _client.get('/risque-operationnel/dashboard')
        as Map<String, dynamic>;
    return RoDashboardData.fromJson(json);
  }

  Future<List<RoIncident>> fetchRoIncidents(
      {String? statut, String? ligneMetier}) async {
    var path = '/risque-operationnel/incidents';
    final params = <String>[];
    if (statut != null) params.add('statut=${Uri.encodeComponent(statut)}');
    if (ligneMetier != null) {
      params.add('ligne_metier=${Uri.encodeComponent(ligneMetier)}');
    }
    if (params.isNotEmpty) path = '$path?${params.join('&')}';
    final json = await _client.get(path) as List<dynamic>;
    return json
        .map((e) => RoIncident.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RoIncident> createRoIncident(Map<String, dynamic> data) async {
    final json = await _client.post('/risque-operationnel/incidents', data)
        as Map<String, dynamic>;
    return RoIncident.fromJson(json);
  }

  Future<RoIncident> updateRoIncident(
      String id, Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/incidents/$id', data)
        as Map<String, dynamic>;
    return RoIncident.fromJson(json);
  }

  Future<void> deleteRoIncident(String id) async {
    await _client.delete('/risque-operationnel/incidents/$id');
  }

  Future<Uint8List> downloadRoImportTemplate() async {
    return _client.getBytes('/risque-operationnel/incidents/import/template');
  }

  Future<Map<String, dynamic>> importRoIncidents(
    List<Map<String, dynamic>> incidents, {
    String mode = 'merge',
  }) async {
    final json = await _client.post('/risque-operationnel/incidents/import', {
      'incidents': incidents,
      'mode': mode,
    }) as Map<String, dynamic>;
    return json;
  }

  Future<RoKriModuleData> fetchRoKri() async {
    final json =
        await _client.get('/risque-operationnel/kri') as Map<String, dynamic>;
    return RoKriModuleData.fromJson(json);
  }

  Future<RoKriValeur> addRoKriValeur(Map<String, dynamic> data) async {
    final json = await _client.post('/risque-operationnel/kri/valeurs', data)
        as Map<String, dynamic>;
    return RoKriValeur.fromJson(json);
  }

  Future<List<RoRisque>> fetchRoRisques() async {
    final json =
        await _client.get('/risque-operationnel/risques') as List<dynamic>;
    return json
        .map((e) => RoRisque.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RoRisque> createRoRisque(Map<String, dynamic> data) async {
    final json = await _client.post('/risque-operationnel/risques', data)
        as Map<String, dynamic>;
    return RoRisque.fromJson(json);
  }

  Future<RoRisque> updateRoRisque(String id, Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/risques/$id', data)
        as Map<String, dynamic>;
    return RoRisque.fromJson(json);
  }

  Future<void> deleteRoRisque(String id) async {
    await _client.delete('/risque-operationnel/risques/$id');
  }

  Future<List<RoControle>> fetchRoControles() async {
    final json =
        await _client.get('/risque-operationnel/controles') as List<dynamic>;
    return json
        .map((e) => RoControle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RoControle> createRoControle(Map<String, dynamic> data) async {
    final json = await _client.post('/risque-operationnel/controles', data)
        as Map<String, dynamic>;
    return RoControle.fromJson(json);
  }

  Future<RoControle> updateRoControle(
      String id, Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/controles/$id', data)
        as Map<String, dynamic>;
    return RoControle.fromJson(json);
  }

  Future<void> deleteRoControle(String id) async {
    await _client.delete('/risque-operationnel/controles/$id');
  }

  Future<List<RoPlan>> fetchRoPlans() async {
    final json =
        await _client.get('/risque-operationnel/plans') as List<dynamic>;
    return json.map((e) => RoPlan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RoPlan> createRoPlan(Map<String, dynamic> data) async {
    final json = await _client.post('/risque-operationnel/plans', data)
        as Map<String, dynamic>;
    return RoPlan.fromJson(json);
  }

  Future<RoPlan> updateRoPlan(String id, Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/plans/$id', data)
        as Map<String, dynamic>;
    return RoPlan.fromJson(json);
  }

  Future<void> deleteRoPlan(String id) async {
    await _client.delete('/risque-operationnel/plans/$id');
  }

  Future<List<RoHistorique>> fetchRoHistorique({int limit = 200}) async {
    final json = await _client
        .get('/risque-operationnel/historique?limit=$limit') as List<dynamic>;
    return json
        .map((e) => RoHistorique.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void dispose() {
    _portfolioRefreshController.close();
  }

  void _notifyPortfolioChanged() {
    _invalidatePortfolioCaches();
    if (_portfolioRefreshController.isClosed) {
      return;
    }
    _portfolioRefreshController.add(++_portfolioRefreshTick);
  }

  void _invalidatePortfolioCaches() {
    _dashboardFuture = null;
    _horsBilanFuture = null;
    _crmFuture = null;
    _expositionsFuture = null;
  }

  Future<T> _memoizeFuture<T>({
    required Future<T>? cached,
    required Future<T>? Function() getCache,
    required void Function(Future<T>? value) setCache,
    required Future<T> Function() load,
  }) {
    if (cached != null) {
      return cached;
    }

    final future = load();
    setCache(future);
    future.then<void>((_) {}, onError: (_) {
      if (identical(getCache(), future)) {
        setCache(null);
      }
    });
    return future;
  }

  Future<DashboardSnapshot> fetchDashboard({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _dashboardFuture = null;
    }
    return _memoizeFuture<DashboardSnapshot>(
      cached: _dashboardFuture,
      getCache: () => _dashboardFuture,
      setCache: (value) => _dashboardFuture = value,
      load: () async {
        final json = await _client.get('/dashboard') as Map<String, dynamic>;
        return DashboardSnapshot.fromJson(json);
      },
    );
  }

  Future<DashboardSnapshot> updateFondsPropres(
      FondsPropresUpdate update) async {
    final json = await _client.put(
      '/dashboard/fonds-propres',
      update.toJson(),
    ) as Map<String, dynamic>;

    _dashboardFuture = null; // invalidation
    return DashboardSnapshot.fromJson(json);
  }

  /// Modèle Excel d'import des Fonds Propres Réglementaires (CET1/AT1/Tier2).
  Future<Uint8List> downloadFondsPropresImportTemplate() async {
    return _client.getBytes('/dashboard/fonds-propres/import/template');
  }

  Future<ExposureModuleData> fetchExpositionsModule() async {
    return _memoizeFuture<ExposureModuleData>(
      cached: _expositionsFuture,
      getCache: () => _expositionsFuture,
      setCache: (value) => _expositionsFuture = value,
      load: () async {
        final exposuresJson =
            await _client.get('/expositions') as List<dynamic>;
        final summaryJson =
            await _client.get('/expositions/summary') as Map<String, dynamic>;
        return ExposureModuleData(
          exposures: exposuresJson
              .map(
                (item) => ExposureRecord.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
          summary: ExposureSummary.fromJson(summaryJson),
        );
      },
    );
  }

  Future<RwaCreditAnalysis> fetchRwaCreditAnalysis() async {
    final json =
        await _client.get('/rwa-credit/analyse') as Map<String, dynamic>;
    return RwaCreditAnalysis.fromJson(json);
  }

  Future<String> fetchNextExposureId() async {
    final response = Map<String, dynamic>.from(
      await _client.get('/expositions/next-id') as Map,
    );
    final identifier = (response['id'] ?? '').toString().trim();
    if (identifier.isNotEmpty) {
      return identifier;
    }
    final module = await fetchExpositionsModule();
    return _nextExposureIdFromIdentifiers(
      module.exposures.map((item) => item.id),
    );
  }

  Future<Uint8List> downloadExposureExcelExport() async {
    return _client.getBytes('/expositions/export/excel/download');
  }

  /// Télécharge le Formulaire de Déclaration Prudentielle (FODEP) renseigné.
  ///
  /// [dateArrete] fixe la date d'arrêté portée par l'attestation ; sans elle,
  /// le backend retient la date d'analyse la plus récente du portefeuille.
  Future<FodepExport> downloadFodep({DateTime? dateArrete}) async {
    final parametres = dateArrete == null
        ? ''
        : '?date_arrete=${dateArrete.toIso8601String().split('T').first}';
    final reponse =
        await _client.getBytesAvecEntetes('/rapports/fodep/export$parametres');
    return FodepExport(
      bytes: reponse.bytes,
      fileName: _nomDeFichierDepuisEnTetes(reponse.headers) ?? 'FODEP.xlsx',
      anomalies: _anomaliesFodep(reponse.headers),
    );
  }

  /// Contenu du FODEP renseigné, état par état, pour en produire un PDF.
  ///
  /// L'extraction est faite par le backend : la bibliothèque Excel du poste de
  /// travail échoue à décoder ce formulaire, qu'openpyxl vient pourtant
  /// d'écrire. Le classeur reste la seule source — le PDF n'est pas un second
  /// calcul.
  Future<ContenuFodep> fetchContenuFodep({DateTime? dateArrete}) async {
    final parametres = dateArrete == null
        ? ''
        : '?date_arrete=${dateArrete.toIso8601String().split('T').first}';
    final json = await _client.get('/rapports/fodep/contenu$parametres');
    return ContenuFodep.fromJson(json as Map<String, dynamic>);
  }

  /// Analyse une déclaration FODEP au regard du dispositif prudentiel UMOA.
  ///
  /// Le PDF n'a pas à venir de cet outil : une déclaration d'un exercice
  /// précédent ou d'une autre entité s'analyse aussi bien. Seules les onze
  /// normes de l'EP01 sont confrontées à leurs seuils.
  Future<AnalyseDeclaration> analyserDeclarationFodep(
    Uint8List pdf,
    String nomFichier,
  ) async {
    final json = await _client.uploadBytes(
      '/rapports/fodep/analyse',
      pdf,
      nomFichier,
    );
    return AnalyseDeclaration.fromJson(json as Map<String, dynamic>);
  }

  /// Cases du FODEP que l'application ne calcule pas, et valeurs déjà saisies.
  ///
  /// Le catalogue est lu dans le formulaire lui-même : ce sont les cases que
  /// la BCEAO a laissées déverrouillées sur les états dont l'application n'a
  /// pas la source.
  Future<SaisiesFodep> fetchSaisiesFodep() async {
    final json = await _client.get('/rapports/fodep/saisies');
    return SaisiesFodep.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Enregistre des saisies. Une valeur nulle efface la case, qui retombe
  /// alors au zéro automatique de l'export.
  ///
  /// La date d'arrêté part du même écran et du même bouton : la transmettre
  /// ici évite qu'une partie de la saisie soit retenue et l'autre non.
  Future<int> enregistrerSaisiesFodep(
    List<CaseFodep> saisies, {
    DateTime? dateArrete,
  }) async {
    final reponse = await _client.put('/rapports/fodep/saisies', {
      'saisies': [for (final saisie in saisies) saisie.toPayload()],
      if (dateArrete != null)
        'date_arrete': '${dateArrete.year.toString().padLeft(4, '0')}-'
            '${dateArrete.month.toString().padLeft(2, '0')}-'
            '${dateArrete.day.toString().padLeft(2, '0')}',
    });
    return ((reponse as Map)['enregistrees'] as num?)?.toInt() ?? 0;
  }

  String? _nomDeFichierDepuisEnTetes(Map<String, String> headers) {
    final disposition = headers['content-disposition'];
    if (disposition == null) return null;
    final correspondance =
        RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    return correspondance?.group(1)?.trim();
  }

  List<ReserveFodep> _anomaliesFodep(Map<String, String> headers) {
    final brut = headers['x-fodep-anomalies'];
    if (brut == null || brut.isEmpty) return const [];
    try {
      final decode = jsonDecode(brut);
      if (decode is List) {
        return decode.map(ReserveFodep.depuisJson).toList();
      }
    } on FormatException {
      // Un en-tête illisible ne doit pas empêcher de récupérer le fichier :
      // c'est le classeur qui compte, les réserves n'en sont qu'un commentaire.
    }
    return const [];
  }

  Map<String, dynamic> _buildExposurePayload(ExposureDraft draft) {
    return {
      'id': draft.id,
      'analysis_date': draft.analysisDate.toIso8601String().split('T').first,
      'grant_date': draft.grantDate?.toIso8601String().split('T').first,
      'maturity_date': draft.maturityDate?.toIso8601String().split('T').first,
      'counterparty_name': draft.counterpartyName,
      'country': draft.country,
      'country_rating': draft.countryRating,
      'category': draft.backendCategory,
      'rating': draft.rating,
      'gross_amount': draft.grossAmount,
      'loan_total_amount': draft.loanTotalAmount,
      'on_balance_exposure_amount': draft.onBalanceExposureAmount,
      'off_balance_exposure_amount': draft.offBalanceExposureAmount,
      'provisions_amount': draft.provisionsAmount,
      'currency': draft.currency,
      'status': draft.status,
      'sovereign_special_case': draft.sovereignSpecialCase,
      'sovereign_preferential_zero_weight':
          draft.sovereignPreferentialZeroWeight,
      'sovereign_oce_established': draft.sovereignOceEstablished,
      'sovereign_oce_note': draft.sovereignOceNote,
      'public_body_uemoa_fcfa_case': draft.publicBodyUemoaFcfaCase,
      'public_body_non_public_activity':
          draft.publicBodyFinancesNonPublicActivity,
      'bmd_high_quality_case': draft.bmdHighQualityCase,
      'bmd_uemoa_fcfa_case': draft.bmdUemoaFcfaCase,
      'bmd_uemoa_criteria_satisfied': draft.bmdUemoaCriteriaSatisfied,
      'bmd_listed_institution_fcfa_case': draft.bmdListedInstitutionFcfaCase,
      'bank_institution_case': draft.bankInstitutionCase,
      'other_asset_type': draft.otherAssetType,
      'off_balance_risk_level': draft.offBalanceRiskLevel,
      'retail_eligibility_criteria_satisfied':
          draft.retailEligibilityCriteriaSatisfied,
      'residential_mortgage_eligible': draft.residentialMortgageEligible,
      'commercial_real_estate_eligible': draft.commercialRealEstateEligible,
      'defaulted_exposure_initial_risk_weight':
          draft.defaultedExposureInitialRiskWeight,
      'defaulted_exposure_residential_mortgage_in_default':
          draft.defaultedExposureResidentialMortgageInDefault,
      'defaulted_exposure_provision_at_least_twenty_percent':
          draft.defaultedExposureProvisionAtLeastTwentyPercent,
      'enterprise_exceeds_bceao_degradation_threshold':
          draft.enterpriseExceedsBceaoDegradationThreshold,
      'enterprise_prudential_procedure': draft.enterprisePrudentialProcedure,
      'enterprise_investment_firm_without_banking_law':
          draft.enterpriseInvestmentFirmWithoutBankingLaw,
      'crm_type': draft.backendCrmType,
      'crm_coverage_percent': _effectiveCrmCoverage(draft),
      'crm_details': draft.crmDetailsJson,
      'comment': draft.comment,
    };
  }

  Future<ExposureRecord> createExposure(ExposureDraft draft) async {
    final response = Map<String, dynamic>.from(
      await _client.post('/expositions', _buildExposurePayload(draft)) as Map,
    );
    _notifyPortfolioChanged();
    return ExposureRecord.fromJson(response);
  }

  Future<ExposureRecord> updateExposure(ExposureDraft draft) async {
    final id = draft.id;
    if (id == null || id.isEmpty) {
      throw ArgumentError(
        "La mise à jour d'une exposition exige un identifiant valide.",
      );
    }

    final response = Map<String, dynamic>.from(
      await _client.put('/expositions/$id', _buildExposurePayload(draft))
          as Map,
    );
    _notifyPortfolioChanged();
    return ExposureRecord.fromJson(response);
  }

  Future<ExposureRecord> previewExposure(ExposureDraft draft) async {
    final response = Map<String, dynamic>.from(
      await _client.post('/expositions/preview', _buildExposurePayload(draft))
          as Map,
    );
    return ExposureRecord.fromJson(response);
  }

  Future<ExpositionSuivi> fetchExpositionSuivi(String exposureId) async {
    final response = Map<String, dynamic>.from(
      await _client.get('/expositions/$exposureId/suivi') as Map,
    );
    return ExpositionSuivi.fromJson(response);
  }

  Future<ExpositionSuivi> recordVersement(
    String exposureId, {
    required String periode,
    required String statut,
    double? montantVerse,
    String? commentaire,
  }) async {
    final response = Map<String, dynamic>.from(
      await _client.post('/expositions/$exposureId/suivi/versements', {
        'periode': periode,
        'statut': statut,
        if (montantVerse != null) 'montant_verse': montantVerse,
        if (commentaire != null && commentaire.isNotEmpty)
          'commentaire': commentaire,
      }) as Map,
    );
    _notifyPortfolioChanged();
    return ExpositionSuivi.fromJson(response);
  }

  Future<ExpositionSuivi> declasserExposition(
    String exposureId, {
    required String motif,
  }) async {
    final response = Map<String, dynamic>.from(
      await _client.post('/expositions/$exposureId/declassement', {
        'motif': motif,
      }) as Map,
    );
    _notifyPortfolioChanged();
    return ExpositionSuivi.fromJson(response);
  }

  Future<ExpositionSuivi> leverDeclassement(
    String exposureId, {
    required String motif,
  }) async {
    final response = Map<String, dynamic>.from(
      await _client.post('/expositions/$exposureId/declassement/levee', {
        'motif': motif,
      }) as Map,
    );
    _notifyPortfolioChanged();
    return ExpositionSuivi.fromJson(response);
  }

  Future<Map<String, dynamic>> deleteExposures(
    List<String> ids, {
    bool reindexIds = false,
  }) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedIds.isEmpty) {
      return {
        'requested_ids': const <String>[],
        'deleted_ids': const <String>[],
        'missing_ids': const <String>[],
        'deleted_count': 0,
        'missing_count': 0,
      };
    }

    final response = Map<String, dynamic>.from(
      await _client.post('/expositions/delete', {
        'ids': normalizedIds,
        'reindex_ids': reindexIds,
      }) as Map,
    );
    _notifyPortfolioChanged();
    return response;
  }

  Future<Map<String, dynamic>> importExposureCsvContent(
    String csvContent,
  ) async {
    final response = Map<String, dynamic>.from(
      await _client.post('/expositions/import/csv', {'content': csvContent})
          as Map<String, dynamic>,
    );
    _notifyPortfolioChanged();
    return response;
  }

  Future<Map<String, dynamic>> importExposureExcelFile(
    Uint8List bytes,
    String filename, {
    String mode = 'merge',
  }) async {
    final response = Map<String, dynamic>.from(
      await _client.uploadBytes(
        '/expositions/import/upload',
        bytes,
        filename,
        fields: {'mode': mode},
      ) as Map<String, dynamic>,
    );
    _notifyPortfolioChanged();
    return response;
  }

  Future<Map<String, dynamic>> inspectExposureExcelFile(
    Uint8List bytes,
    String filename,
  ) async {
    return Map<String, dynamic>.from(
      await _client.uploadBytes(
        '/expositions/import/upload/inspect',
        bytes,
        filename,
      ) as Map,
    );
  }

  Future<Map<String, dynamic>> fetchExcelImportSpec() async {
    return Map<String, dynamic>.from(
      await _client.get('/expositions/import/spec') as Map,
    );
  }

  Future<Uint8List> downloadExcelImportTemplate() async {
    return _client.getBytes('/expositions/import/template');
  }

  Future<OffBalanceModuleData> fetchHorsBilanModule() async {
    return _memoizeFuture<OffBalanceModuleData>(
      cached: _horsBilanFuture,
      getCache: () => _horsBilanFuture,
      setCache: (value) => _horsBilanFuture = value,
      load: () async {
        final itemsJson = await _client.get('/hors-bilan') as List<dynamic>;
        final summaryJson =
            await _client.get('/hors-bilan/summary') as Map<String, dynamic>;
        return OffBalanceModuleData(
          items: itemsJson
              .map(
                (item) =>
                    OffBalanceRecord.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
          summary: OffBalanceSummary.fromJson(summaryJson),
        );
      },
    );
  }

  Future<void> createOffBalance(OffBalanceDraft draft) async {
    await _client.post('/hors-bilan', {
      'analysis_date': draft.analysisDate.toIso8601String().split('T').first,
      'counterparty_id': draft.counterpartyId,
      'engagement_type': draft.engagementType,
      'nominal_amount': draft.nominalAmount,
      'comment': draft.comment,
    });
    _notifyPortfolioChanged();
  }

  Future<CrmModuleData> fetchCrmModule() async {
    return _memoizeFuture<CrmModuleData>(
      cached: _crmFuture,
      getCache: () => _crmFuture,
      setCache: (value) => _crmFuture = value,
      load: () async {
        final json = await _client.get('/crm') as Map<String, dynamic>;
        return CrmModuleData.fromJson(json);
      },
    );
  }

  Future<ReferentielsModuleData> fetchReferentiels() async {
    return _memoizeFuture<ReferentielsModuleData>(
      cached: _referentielsFuture,
      getCache: () => _referentielsFuture,
      setCache: (value) => _referentielsFuture = value,
      load: () async {
        final json = await _client.get('/referentiels') as Map<String, dynamic>;
        return ReferentielsModuleData.fromJson(json);
      },
    );
  }

  Future<ReportsModuleData> fetchReports() async {
    return _memoizeFuture<ReportsModuleData>(
      cached: _reportsFuture,
      getCache: () => _reportsFuture,
      setCache: (value) => _reportsFuture = value,
      load: () async {
        final json = await _client.get('/rapports') as List<dynamic>;
        return ReportsModuleData(
          reports: json
              .map(
                (item) => ReportRecord.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> generateReport(ReportDraft draft) async {
    await _client.post('/rapports', draft.toJson());
    _reportsFuture = null;
  }

  double _effectiveCrmCoverage(ExposureDraft draft) {
    if (draft.crmMode == 'CRM financee') {
      return computeFinancedCrmSnapshot(draft).coveragePercent;
    }
    if (draft.crmMode == 'CRM non financee') {
      return draft.crmCoveragePercent.clamp(0.0, 1.0).toDouble();
    }
    return 0.0;
  }

  String _nextExposureIdFromIdentifiers(Iterable<String> identifiers) {
    var max = 0;
    for (final identifier in identifiers) {
      if (!identifier.startsWith('CP')) {
        continue;
      }
      final parsed = int.tryParse(identifier.substring(2));
      if (parsed != null && parsed > max) {
        max = parsed;
      }
    }
    return 'CP${(max + 1).toString().padLeft(3, '0')}';
  }

  // ── BIC - Approche Standard CRR3 ────────────────────────────────────────────

  Future<OpRiskInput> fetchBicInput(int annee) async {
    final json = await _client.get('/risque-operationnel/bic/inputs/$annee')
        as Map<String, dynamic>;
    return OpRiskInput.fromJson(json);
  }

  Future<OpRiskInput> upsertBicInput(
      int annee, Map<String, dynamic> data) async {
    final json = await _client.put(
        '/risque-operationnel/bic/inputs/$annee', data) as Map<String, dynamic>;
    // Le RWA Opérationnel du dashboard (métrique 'rwa_op' et 'rwa' total,
    // donc aussi les ratios CET1/Tier1/Solvabilité/Levier) dépend directement
    // de calcul_bic() côté backend. Sans cette invalidation, un écran déjà
    // ouvert (Tableau de bord, Reporting) continue d'afficher les anciens
    // chiffres tant qu'il n'est pas rechargé manuellement.
    _dashboardFuture = null;
    return OpRiskInput.fromJson(json);
  }

  Future<OpRiskParametres> fetchBicParametres() async {
    final json = await _client.get('/risque-operationnel/bic/parametres')
        as Map<String, dynamic>;
    return OpRiskParametres.fromJson(json);
  }

  /// Toutes les années ayant des postes BIC/CCR3 enregistrés (saisie ou
  /// import Excel), sans se limiter à la fenêtre N-2/N-1/N par défaut de
  /// [calculeOpRiskBic]. Utilisé par l'onglet "Données importées" pour
  /// retrouver un exercice importé même hors des 3 derniers exercices.
  Future<List<OpRiskInput>> listBicInputs() async {
    final json =
        await _client.get('/risque-operationnel/bic/inputs') as List<dynamic>;
    return json
        .map((e) => OpRiskInput.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Uint8List> downloadBicImportTemplate() async {
    return _client.getBytes('/risque-operationnel/bic/import/template');
  }

  Future<OpRiskParametres> updateBicParametres(
      Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/bic/parametres', data)
        as Map<String, dynamic>;
    // Mêmes raisons que dans upsertBicInput() : les paramètres BIC/CCR3
    // (seuils, coefficients) affectent aussi le RWA Opérationnel du dashboard.
    _dashboardFuture = null;
    return OpRiskParametres.fromJson(json);
  }

  Future<OpRiskCalculResult> calculeOpRiskBic({int? anneeN}) async {
    final path = anneeN != null
        ? '/risque-operationnel/bic/calcul?annee_n=$anneeN'
        : '/risque-operationnel/bic/calcul';
    final json = await _client.get(path) as Map<String, dynamic>;
    return OpRiskCalculResult.fromJson(json);
  }

  // ── UEMOA - AIB (Approche Indicateur de Base) ────────────────────────────────

  Future<List<PnbAnnuelView>> fetchPnbAnnuel() async {
    final list =
        await _client.get('/risque-operationnel/aib/pnb') as List<dynamic>;
    return list
        .map((e) => PnbAnnuelView.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PnbAnnuelView> upsertPnbAnnuel(
      int annee, Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/aib/pnb/$annee', data)
        as Map<String, dynamic>;
    // Le RWA Opérationnel du dashboard global (métrique 'rwa_op', donc aussi
    // 'rwa' total et les ratios qui en découlent) vaut `apr_operationnel_retenu`
    // côté backend, c'est-à-dire l'approche indicateur de base ou l'approche
    // standard — jamais le BIC. Seules les écritures BIC invalidaient pourtant
    // le cache : le tableau de bord global gardait son ancien RWA opérationnel
    // pendant que l'onglet Risque Opérationnel affichait le nouveau.
    _dashboardFuture = null;
    return PnbAnnuelView.fromJson(json);
  }

  Future<void> deletePnbAnnuel(int annee) async {
    await _client.delete('/risque-operationnel/aib/pnb/$annee');
    _dashboardFuture = null;
  }

  /// Corrige le millésime d'un exercice sans toucher aux montants : une année
  /// saisie de travers se rattrapait sinon par une suppression suivie d'une
  /// ressaisie complète.
  Future<void> renommerExerciceAib(int annee, int nouvelleAnnee) async {
    await _client.put(
      '/risque-operationnel/aib/exercices/$annee/millesime',
      {'nouvelle_annee': nouvelleAnnee},
    );
    // Renommer un exercice change la fenêtre des trois derniers, donc la
    // moyenne : le RWA opérationnel bouge.
    _dashboardFuture = null;
  }

  Future<ParametresAib> fetchAibParametres() async {
    final json = await _client.get('/risque-operationnel/aib/parametres')
        as Map<String, dynamic>;
    return ParametresAib.fromJson(json);
  }

  Future<ParametresAib> updateAibParametres(Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/aib/parametres', data)
        as Map<String, dynamic>;
    // Alpha et multiplicateur entrent directement dans l'exigence de
    // l'indicateur de base, donc dans le RWA opérationnel du dashboard.
    _dashboardFuture = null;
    return ParametresAib.fromJson(json);
  }

  Future<AibCalculResult> calculeAib() async {
    final json = await _client.get('/risque-operationnel/aib/calcul')
        as Map<String, dynamic>;
    return AibCalculResult.fromJson(json);
  }

  Future<DecisionPilotageResult> fetchDecisionAib() async {
    final json = await _client.get('/risque-operationnel/aib/decision')
        as Map<String, dynamic>;
    return DecisionPilotageResult.fromJson(json);
  }

  // ── UEMOA - AS (Approche Standard) ───────────────────────────────────────────

  Future<List<BetaLigneView>> fetchBetaLignes() async {
    final list = await _client.get('/risque-operationnel/as/beta-lignes')
        as List<dynamic>;
    return list
        .map((e) => BetaLigneView.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BetaLigneView> updateBetaLigne(String ligneMetier, double beta) async {
    final json = await _client.put(
      '/risque-operationnel/as/beta-lignes/${Uri.encodeComponent(ligneMetier)}',
      {'beta': beta},
    ) as Map<String, dynamic>;
    _dashboardFuture = null;
    return BetaLigneView.fromJson(json);
  }

  Future<List<PnbParLigneView>> fetchPnbLignes(int annee) async {
    final list = await _client.get('/risque-operationnel/as/pnb-lignes/$annee')
        as List<dynamic>;
    return list
        .map((e) => PnbParLigneView.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PnbParLigneView> upsertPnbLigne(
      int annee, String ligneMetier, double pnb) async {
    final json = await _client.put(
      '/risque-operationnel/as/pnb-lignes/$annee/${Uri.encodeComponent(ligneMetier)}',
      {'produit_brut_ligne': pnb},
    ) as Map<String, dynamic>;
    // Sans effet sur le dashboard tant que l'approche standard n'est pas
    // autorisée, mais l'autorisation se pose sur un autre écran : mieux vaut
    // invalider que dépendre de l'ordre dans lequel on passe d'un à l'autre.
    _dashboardFuture = null;
    return PnbParLigneView.fromJson(json);
  }

  Future<void> deletePnbLignes(int annee) async {
    await _client.delete('/risque-operationnel/as/pnb-lignes/$annee');
    _dashboardFuture = null;
  }

  /// Corrige le millésime d'un exercice : les huit lignes de métier suivent,
  /// c'est l'année qui change et pas les montants.
  Future<void> renommerExerciceAs(int annee, int nouvelleAnnee) async {
    await _client.put(
      '/risque-operationnel/as/exercices/$annee/millesime',
      {'nouvelle_annee': nouvelleAnnee},
    );
    _dashboardFuture = null;
  }

  Future<ParametresAs> fetchAsParametres() async {
    final json = await _client.get('/risque-operationnel/as/parametres')
        as Map<String, dynamic>;
    return ParametresAs.fromJson(json);
  }

  Future<ParametresAs> updateAsParametres(Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/as/parametres', data)
        as Map<String, dynamic>;
    // `as_autorisee` décide laquelle des deux approches alimente le RWA
    // opérationnel : c'est le paramètre qui déplace le plus ce chiffre.
    _dashboardFuture = null;
    return ParametresAs.fromJson(json);
  }

  Future<AsCalculResult> calculeAs() async {
    final json = await _client.get('/risque-operationnel/as/calcul')
        as Map<String, dynamic>;
    return AsCalculResult.fromJson(json);
  }

  Future<DecisionPilotageResult> fetchDecisionAs() async {
    final json = await _client.get('/risque-operationnel/as/decision')
        as Map<String, dynamic>;
    return DecisionPilotageResult.fromJson(json);
  }

  // ── UEMOA - Seuils + Synthèse ─────────────────────────────────────────────────

  Future<ParametresSeuils> fetchPertesSeuils() async {
    final json = await _client.get('/risque-operationnel/pertes/seuils')
        as Map<String, dynamic>;
    return ParametresSeuils.fromJson(json);
  }

  Future<ParametresSeuils> updatePertesSeuils(Map<String, dynamic> data) async {
    final json = await _client.put('/risque-operationnel/pertes/seuils', data)
        as Map<String, dynamic>;
    return ParametresSeuils.fromJson(json);
  }

  Future<SyntheseResult> fetchSynthese() async {
    final json = await _client.get('/risque-operationnel/synthese')
        as Map<String, dynamic>;
    return SyntheseResult.fromJson(json);
  }

  Future<DecisionPilotageResult> fetchDecisionPilotage() async {
    final json = await _client.get('/risque-operationnel/pilotage/decision')
        as Map<String, dynamic>;
    return DecisionPilotageResult.fromJson(json);
  }
}
