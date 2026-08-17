// Ce fichier porte la racine de l'application et la navigation principale.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_module.dart';
import 'core/auth/session_controller.dart';
import 'core/auth/session_scope.dart';
import 'core/localization/app_language.dart';
import 'core/localization/app_localization.dart';
import 'core/services/rwa_api_service.dart';
import 'core/state/portfolio_amount_unit_scope.dart';
import 'core/state/portfolio_currency_scope.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/currency_conversion.dart';
import 'modules/analyse/screens/analyse_screen.dart';
import 'modules/concentration/screens/concentration_screen.dart';
import 'modules/crm/screens/crm_screen.dart';
import 'modules/dashboard/screens/dashboard_screen.dart';
import 'modules/defauts_impayes/screens/defauts_impayes_screen.dart';
import 'modules/expositions/screens/expositions_screen.dart';
import 'modules/garanties/screens/garanties_screen.dart';
import 'modules/hors_bilan/screens/hors_bilan_screen.dart';
import 'modules/importations/screens/importations_screen.dart';
import 'modules/rapports/screens/rapports_screen.dart';
import 'modules/reporting_credit/screens/reporting_credit_screen.dart';
import 'modules/reporting_global/screens/reporting_global_screen.dart';
import 'modules/risque_marche/repositories/foreign_exchange_repository.dart';
import 'modules/risque_marche/screens/market_data_import_screen.dart';
import 'modules/risque_marche/screens/risque_marche_screen.dart';
import 'modules/risque_marche/services/market_capital_requirement_persister.dart';
import 'modules/risque_marche/services/market_data_import_store.dart';
import 'modules/risque_operationnel/screens/risque_operationnel_screen.dart';
import 'modules/auth/screens/login_screen.dart';
import 'modules/rwa_engine/screens/rwa_engine_screen.dart';
import 'modules/vue_ensemble/screens/vue_ensemble_screen.dart';
import 'shared/widgets/app_shell.dart';
import 'shared/widgets/under_construction_screen.dart';

/// Widget racine qui pilote le thème et la navigation principale.
class RwaApp extends StatefulWidget {
  const RwaApp({super.key});

  @override
  State<RwaApp> createState() => _RwaAppState();
}

/// Etat interne qui mémorise le module courant et le mode de thème.
class _RwaAppState extends State<RwaApp> {
  /// Session partagée par toute l'application. Elle interroge le même backend
  /// que les appels métier : une seconde résolution d'URL finirait par
  /// diverger de la première.
  late final SessionController _session = SessionController(
    baseUrl: RwaApiService.resolveDefaultBaseUrl(),
  );

  /// Le service métier lit le jeton à chaque appel et sait rejouer une requête
  /// après un renouvellement : l'expiration d'un jeton reste invisible pour
  /// l'utilisateur, tant que sa session de renouvellement tient.
  late final RwaApiService _api = RwaApiService(
    tokenProvider: () => _session.accessToken,
    onUnauthorized: () async {
      final renouvele = await _session.renouveler();
      if (!renouvele) {
        _session.invalider();
      }
      return renouvele;
    },
  );
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<String> _portfolioDisplayCurrency = ValueNotifier<String>(
    'XOF',
  );
  final ValueNotifier<PortfolioAmountUnit> _portfolioAmountUnit =
      ValueNotifier<PortfolioAmountUnit>(
    PortfolioAmountUnit.billion,
  );
  final ValueNotifier<AppLanguage> _appLanguage = ValueNotifier<AppLanguage>(
    AppLanguage.francais,
  );
  // Un espace neuf est vide : le premier geste attendu est un import, pas la
  // lecture d'un tableau de bord sans chiffres. L'application s'ouvre donc sur
  // « Importations » par défaut, et bascule sur la vue d'ensemble dès que le
  // portefeuille contient des données.
  AppModule _selectedModule = AppModule.importations;
  ThemeMode _themeMode = ThemeMode.light;
  String _fontFamily = AppTheme.defaultFontFamily;
  Color _primaryColor = AppTheme.accent;
  bool _initialLandingResolved = false;
  bool _isMarketImportDialogOpen = false;
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();
  @override
  void initState() {
    super.initState();
    AppLocalizations.setCurrentLanguage(_appLanguage.value);
    unawaited(_session.initialiser());
    PortfolioAmountUnitPreference.current = _portfolioAmountUnit.value;
    _portfolioAmountUnit.addListener(_handleAmountUnitChanged);
    _appLanguage.addListener(_handleLanguageChanged);
    _session.addListener(_handleSessionChanged);
    unawaited(MarketDataImportStore.instance.configureSqlBackend(_api));
    unawaited(InMemoryForeignExchangeRepository().configureSqlBackend(_api));
    unawaited(MarketCapitalRequirementPersister.instance.start());
  }

  @override
  void dispose() {
    _portfolioAmountUnit.removeListener(_handleAmountUnitChanged);
    _appLanguage.removeListener(_handleLanguageChanged);
    _session.removeListener(_handleSessionChanged);
    _portfolioDisplayCurrency.dispose();
    _portfolioAmountUnit.dispose();
    _appLanguage.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: _appLanguage,
      builder: (context, appLanguage, _) {
        AppLocalizations.setCurrentLanguage(appLanguage);

        // La portée de session enveloppe MaterialApp, et non son contenu :
        // les boîtes de dialogue sont construites par le navigateur, au-dessus
        // de `home`. Placée plus bas, la session leur serait invisible et les
        // actions d'édition y resteraient affichées.
        return SessionScope(
          controller: _session,
          child: AppLocalizationScope(
          notifier: _appLanguage,
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Risk management',
            locale: appLanguage.locale,
            supportedLocales: AppLanguage.values
                .map((language) => language.locale)
                .toList(growable: false),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.buildTheme(
              fontFamily: _fontFamily,
              accentColor: _primaryColor,
            ),
            darkTheme: AppTheme.buildDarkTheme(
              fontFamily: _fontFamily,
              accentColor: _primaryColor,
            ),
            themeMode: _themeMode,
            home: AnimatedBuilder(
              animation: _session,
              builder: (context, _) => _buildPorte(),
            ),
          ),
          ),
        );
      },
    );
  }

  /// Porte d'entrée : vérification, connexion, ou application.
  ///
  /// Tant que la session n'est pas tranchée, rien de l'application n'est
  /// construit : aucun appel API ne part avant de savoir au nom de qui.
  Widget _buildPorte() {
    switch (_session.etat) {
      case SessionState.verification:
        return const Scaffold(
          backgroundColor: Color(0xFFF4F6FA),
          body: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      case SessionState.deconnecte:
        return LoginScreen(session: _session);
      case SessionState.connecte:
        return _buildApplication();
    }
  }

  Widget _buildApplication() {
    return PortfolioCurrencyScope(
              notifier: _portfolioDisplayCurrency,
              child: PortfolioAmountUnitScope(
                notifier: _portfolioAmountUnit,
                child: AppShell(
                  selectedModule: _selectedModule,
                  onSelectModule: _selectModule,
                  onReturnToWelcome: _navigateHome,
                  themeMode: _themeMode,
                  onThemeModeChanged: (themeMode) =>
                      setState(() => _themeMode = themeMode),
                  portfolioDisplayCurrency: _portfolioDisplayCurrency,
                  portfolioAmountUnit: _portfolioAmountUnit,
                  appLanguage: _appLanguage,
                  fontFamily: _fontFamily,
                  onFontFamilyChanged: (fontFamily) =>
                      setState(() => _fontFamily = fontFamily),
                  primaryColor: _primaryColor,
                  onPrimaryColorChanged: (primaryColor) =>
                      setState(() => _primaryColor = primaryColor),
                  child: _buildSelectedScreen(),
                ),
              ),
    );
  }

  void _handleLanguageChanged() {
    AppLocalizations.setCurrentLanguage(_appLanguage.value);
    if (!mounted) return;
    setState(() {});
  }

  void _handleAmountUnitChanged() {
    PortfolioAmountUnitPreference.current = _portfolioAmountUnit.value;
    if (!mounted) return;
    setState(() {});
  }

  void _selectModule(AppModule module) {
    if (module == AppModule.referentiels) {
      return;
    }
    if (module == AppModule.risqueMarcheImport) {
      _openMarketImportDialog();
      return;
    }
    if (module == _selectedModule) {
      return;
    }
    setState(() {
      _selectedModule = module;
    });
  }

  /// Bascule vers l'écran de démarrage : imports si le portefeuille est
  /// vide, vue d'ensemble sinon. Utilisé au premier chargement de la
  /// session et par le bouton d'accueil de la barre supérieure.
  void _handleSessionChanged() {
    if (_initialLandingResolved || _session.etat != SessionState.connecte) {
      return;
    }
    _initialLandingResolved = true;
    unawaited(_navigateHome());
  }

  Future<void> _navigateHome() async {
    try {
      final dashboard = await _api.fetchDashboard();
      if (!mounted) return;
      setState(() {
        _selectedModule = dashboard.portfolioOverview.isNotEmpty
            ? AppModule.vueEnsemble
            : AppModule.importations;
      });
    } catch (_) {
      // Portefeuille vide ou données indisponibles : les imports restent le
      // point de départ le plus sûr.
      if (!mounted) return;
      setState(() => _selectedModule = AppModule.importations);
    }
  }

  Future<void> _openMarketImportDialog() async {
    if (_isMarketImportDialogOpen) {
      return;
    }
    _isMarketImportDialogOpen = true;
    try {
      final navigatorContext = _navigatorKey.currentContext;
      if (navigatorContext != null) {
        await showMarketDataImportDialog(navigatorContext);
      }
    } finally {
      _isMarketImportDialogOpen = false;
    }
  }

  Widget _screenFor(AppModule module) {
    return switch (module) {
      AppModule.importations => ImportationsScreen(api: _api),
      AppModule.vueEnsemble => VueEnsembleScreen(
          api: _api,
          onNavigateToModule: _selectModule,
        ),
      AppModule.dashboardCredit => DashboardScreen(api: _api),
      AppModule.expositions => ExpositionsScreen(
          api: _api,
          displayCurrencyListenable: _portfolioDisplayCurrency,
        ),
      AppModule.rwaEngine => RwaEngineScreen(api: _api),
      AppModule.crm => CrmScreen(api: _api),
      AppModule.horsBilan => HorsBilanScreen(api: _api),
      AppModule.garanties => GarantiesScreen(api: _api),
      AppModule.defautsImpayes => DefautsImpayesScreen(api: _api),
      AppModule.concentrationCredit => ConcentrationScreen(api: _api),
      AppModule.reportingCredit => ReportingCreditScreen(api: _api),
      AppModule.risqueMarche => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.dashboard,
        ),
      AppModule.risqueMarcheImport => RisqueMarcheScreen(api: _api),
      AppModule.risqueMarcheCalculPrudentiel => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.calculPrudentiel,
        ),
      AppModule.risqueMarchePilotage => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.pilotage,
        ),
      AppModule.risqueMarcheVar => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.varRisk,
        ),
      AppModule.risqueMarcheCourbeTaux => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.yieldCurves,
        ),
      AppModule.risqueMarcheIndicateurs => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.indicators,
        ),
      AppModule.risqueMarcheAmortissementCrd => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.amortizationCapital,
        ),
      AppModule.risqueOperationnel => RisqueOperationnelScreen(api: _api),
      AppModule.risqueOperationnelImport =>
        RisqueOperationnelScreen(api: _api, view: OperationalRiskView.registre),
      AppModule.risqueOperationnelIncidents => RisqueOperationnelScreen(
          api: _api,
          view: OperationalRiskView.incidents,
        ),
      AppModule.risqueOperationnelPertes => RisqueOperationnelScreen(
          api: _api,
          view: OperationalRiskView.pertes,
        ),
      AppModule.risqueOperationnelHistorique => RisqueOperationnelScreen(
          api: _api,
          view: OperationalRiskView.historique,
        ),
      AppModule.risqueOperationnelReporting => ReportingGlobalScreen(api: _api),
      AppModule.risqueOperationnelUemoiCcr3 => RisqueOperationnelScreen(
          api: _api,
          view: OperationalRiskView.ccr3Uemoi,
        ),
      AppModule.analyse => AnalyseScreen(api: _api),
      AppModule.stressTest =>
        const UnderConstructionScreen(title: 'Stress Test'),
      AppModule.icap ||
      AppModule.icapCapitalEconomique ||
      AppModule.icapCapitalReglementaire ||
      AppModule.icapAppetenceRisque ||
      AppModule.icapBuffersPrudentiels ||
      AppModule.icapProjectionCapital ||
      AppModule.icapAnalyseSolvabilite ||
      AppModule.icapPlansCapital ||
      AppModule.icapReportingIcaap ||
      AppModule.icapUemoaCemac =>
        const UnderConstructionScreen(title: 'ICAAP'),
      AppModule.capitalPlaning =>
        const UnderConstructionScreen(title: 'Capital Planning'),
      AppModule.referentiels => _screenFor(AppModule.vueEnsemble),
      AppModule.rapports => RapportsScreen(api: _api),
    };
  }

  Widget _buildSelectedScreen() {
    return PageStorage(
      bucket: _pageStorageBucket,
      child: KeyedSubtree(
        key: PageStorageKey<String>(_selectedModule.name),
        child: _screenFor(_selectedModule),
      ),
    );
  }
}
