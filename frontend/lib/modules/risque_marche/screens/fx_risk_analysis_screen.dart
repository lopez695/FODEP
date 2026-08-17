/// Écran d'analyse du Risque de Change - Version refactorisée
/// Présentation multi-niveaux: Titres, Agrégation Devise, Calculs Prudentiels
/// Conforme à la spécification BCEAO
library fx_risk_analysis_screen;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/currency_registry.dart';
import '../models/fx_security_analysis.dart';
import '../services/fx_rate_service.dart';
import '../services/fx_security_analysis_service.dart';
import '../services/market_data_import_store.dart';

const Color _fxPrimary = Color(0xFF2563EB);
const Color _fxSuccess = Color(0xFF10B981);
const Color _fxDanger = Color(0xFFEF4444);
const Color _fxText = Color(0xFF1F2937);
const Color _fxMuted = Color(0xFF6B7280);
const Color _fxBorder = Color(0xFFE5E7EB);

bool _isFxDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _fxSurfaceFor(BuildContext context) =>
    _isFxDark(context) ? const Color(0xFF1F2937) : Colors.white;

Color _fxBorderFor(BuildContext context) =>
    _isFxDark(context) ? const Color(0xFF374151) : _fxBorder;

Color _fxTextFor(BuildContext context) =>
    _isFxDark(context) ? const Color(0xFFF3F4F6) : _fxText;

Color _fxMutedFor(BuildContext context) =>
    _isFxDark(context) ? const Color(0xFFD1D5DB) : _fxMuted;

/// Écran principal d'analyse du Risque de Change
class FxRiskAnalysisScreen extends StatefulWidget {
  const FxRiskAnalysisScreen({
    super.key,
    this.initialData,
    this.rateService,
  });

  final FxRiskAnalysisResult? initialData;

  /// Service de cotation en ligne. Injectable pour les tests ; en production il
  /// est instancié à la volée (accès ouvert ExchangeRate-API, sans clé).
  final FxRateService? rateService;

  @override
  State<FxRiskAnalysisScreen> createState() => _FxRiskAnalysisScreenState();
}

class _FxRiskAnalysisScreenState extends State<FxRiskAnalysisScreen> {
  FxRiskAnalysisResult _analysisResult = _emptyFxRiskAnalysisResult();
  final _service = FxSecurityAnalysisService();
  bool _loadingMarketData = true;

  /// Taux de change COURANTS (spot), en XOF pour 1 unité de devise. Éditables
  /// par l'utilisateur ; initialisés depuis le registre des devises. Ils
  /// servent de taux de valorisation : la variation et le gain/perte de change
  /// sont calculés par rapport au taux d'acquisition de chaque titre.
  ///
  /// `static` volontairement : l'écran est recréé à chaque changement de vue
  /// dans `RisqueMarcheScreen` (switch sur un widget différent par onglet),
  /// ce qui détruirait sinon la dernière actualisation à chaque navigation.
  /// La dernière valeur connue doit rester jusqu'à la prochaine actualisation
  /// explicite, pas jusqu'à la prochaine visite de l'écran.
  static final Map<String, double> _currentRates = {};

  /// Origine et horodatage de chaque taux courant (référence interne, saisie
  /// manuelle ou cotation en ligne), pour traçabilité dans la barre. Même
  /// raison de `static` que `_currentRates`.
  static final Map<String, _RateMeta> _rateMeta = {};

  /// Service de cotation en ligne (injectable via le widget pour les tests).
  late final FxRateService _rateService = widget.rateService ?? FxRateService();

  /// Une devise à parité fixe avec le XOF (EUR) ne porte aucun risque de change :
  /// son taux n'est pas éditable.
  static bool _isFixedParity(String code) => code == 'EUR';

  List<MarketPortfolioRecord> get _records {
    final snapshot = MarketDataImportStore.instance.snapshotNotifier.value;
    final bonds = snapshot.datasetFor(MarketPortfolioType.bonds)?.records ?? [];
    return bonds;
  }

  @override
  void initState() {
    super.initState();
    // Devises principales toujours proposées dans la barre des taux ; les
    // autres devises du registre n'y apparaissent que si le portefeuille en
    // contient (cf. _ensurePortfolioCurrencies).
    for (final code in const ['EUR', 'USD']) {
      // Une actualisation précédente (saisie ou cotation en ligne) est
      // déjà présente dans la map statique : on ne l'écrase pas avec la
      // valeur par défaut du référentiel à chaque recréation de l'écran.
      if (_currentRates.containsKey(code)) continue;
      final rate = CurrencyRegistry().getRate(code);
      if (rate == null) continue;
      _currentRates[code] = rate.rateToXof;
      _rateMeta[code] =
          _RateMeta(origin: FxRateOrigin.registry, asOf: rate.lastUpdate);
    }
    MarketDataImportStore.instance.snapshotNotifier.addListener(_onDataChanged);
    // Analyse immédiate des données DÉJÀ présentes dans le snapshot (sans
    // setState : on est dans initState, le premier build suivra).
    _analysisResult = _computeAnalysis();
    // Restauration des données persistées en arrière-plan : best-effort. Le
    // rendu ne dépend QUE du snapshot courant (cf. `_runAnalysis` rebranché sur
    // le listener), donc si ce future ne se complète jamais - typiquement en
    // test widget, où l'I/O fichier de `initialized` n'est pas pompée - l'écran
    // affiche malgré tout les données disponibles au lieu de rester bloqué sur
    // le spinner.
    _awaitRestore();
  }

  void _onDataChanged() {
    if (mounted) _runAnalysis();
  }

  Future<void> _awaitRestore() async {
    await MarketDataImportStore.instance.initialized;
    if (!mounted) return;
    setState(() => _loadingMarketData = false);
    _runAnalysis();
  }

  /// Calcule le résultat d'analyse à partir du snapshot courant, sans toucher à
  /// l'état (utilisable depuis `initState`).
  FxRiskAnalysisResult _computeAnalysis() {
    final records = _records;
    if (records.isEmpty) return _emptyFxRiskAnalysisResult();
    try {
      final result = _service.analyzePortfolio(
        records: records,
        analysisDate: DateTime.now(),
        exchangeRates: _currentRates,
      );
      _ensurePortfolioCurrencies(result);
      return result;
    } catch (_) {
      return _emptyFxRiskAnalysisResult();
    }
  }

  void _runAnalysis() {
    final result = _computeAnalysis();
    if (mounted) setState(() => _analysisResult = result);
  }

  /// Actualisation groupée : cote en ligne le taux courant de toutes les
  /// devises de la barre (hors parités fixes), puis relance l'analyse.
  bool _refreshingRates = false;

  Future<void> _refreshAllRates() async {
    if (_refreshingRates) return;
    setState(() => _refreshingRates = true);
    final codes = _currentRates.keys
        .where((c) => !_isFixedParity(c))
        .toList(growable: false);
    final failures = <String>[];
    for (final code in codes) {
      try {
        final live = await _rateService.fetchRateToXof(code);
        _currentRates[code] = live.rateToXof;
        _rateMeta[code] = _RateMeta(
          origin: FxRateOrigin.online,
          asOf: live.asOf,
          provider: live.provider,
        );
        // Le référentiel partagé doit refléter le taux actualisé : les
        // calculs agrégés hors de cet écran (tableau de bord Analyse
        // portefeuille Marché, etc.) s'appuient sur lui, pas sur cette
        // map locale à l'écran.
        CurrencyRegistry().updateRate(code, live.rateToXof);
      } catch (_) {
        failures.add(code);
      }
    }
    if (!mounted) return;
    setState(() => _refreshingRates = false);
    _runAnalysis();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(failures.isEmpty
          ? 'Contre-valeurs actualisées (${codes.length} devises).'
          : 'Contre-valeurs actualisées. Cotation indisponible pour : '
              '${failures.join(', ')}.'),
      duration: const Duration(seconds: 4),
    ));
  }

  /// Ajoute à la barre des taux les devises du portefeuille absentes du
  /// registre : leur contre-valeur (inconnue = 1) devient ainsi éditable par
  /// l'utilisateur au lieu de rester figée.
  void _ensurePortfolioCurrencies(FxRiskAnalysisResult result) {
    for (final s in result.securities) {
      final code = s.currency;
      if (code == 'XOF' || _currentRates.containsKey(code)) continue;
      _currentRates[code] =
          CurrencyRegistry().getRate(code)?.rateToXof ?? 1.0;
      _rateMeta[code] = const _RateMeta(origin: FxRateOrigin.registry);
    }
  }

  @override
  void dispose() {
    MarketDataImportStore.instance.snapshotNotifier
        .removeListener(_onDataChanged);
    // Le client HTTP n'est fermé que si nous en sommes propriétaires : un
    // service injecté (tests) reste à la charge de l'appelant.
    if (widget.rateService == null) _rateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasExposure = _analysisResult.securities.isNotEmpty;
    // Le spinner ne s'affiche QUE pendant la restauration ET tant qu'aucune
    // donnée n'est disponible : dès que le snapshot porte des titres, on rend
    // l'analyse, même si la restauration persistée n'a pas (encore) abouti.
    final showSpinner = _loadingMarketData && _records.isEmpty;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPIs fixes en haut
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding,
                AppTheme.pagePadding, AppTheme.pagePadding, 0),
            child: _FxKpiSection(result: _analysisResult),
          ),
          const SizedBox(height: 12),
          // Titre de section + barre des taux courants éditables sur la même
          // ligne (les taux ne sont affichés que s'il y a une exposition en
          // devise étrangère à valoriser).
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pagePadding, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Flexible(
                        child: Text(
                          'Titres exposés au risque de change',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                      ),
                      // Nature de la position affichée UNE fois : un
                      // portefeuille de titres achetés est long par nature,
                      // inutile de le répéter sur chaque ligne du tableau.
                      if (hasExposure) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _fxSuccess.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text('POSITIONS LONGUES',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: _fxSuccess)),
                        ),
                      ],
                      const SizedBox(width: 12),
                      _FxInfoButton(result: _analysisResult),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tableau - occupe toute la hauteur restante (scroll interne + pied
          // figé) au lieu d'une hauteur fixe qui paraissait coincée en bas.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 0,
                  AppTheme.pagePadding, AppTheme.pagePadding),
              child: showSpinner
                  ? const Center(child: CupertinoActivityIndicator())
                  : !hasExposure
                      ? _FxEmptyState(hasMarketData: _records.isNotEmpty)
                      : _FxContentSplit(
                          result: _analysisResult,
                          onRefreshRates: _refreshAllRates,
                          onManageRates: _openRatesManager,
                          refreshingRates: _refreshingRates,
                        ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ouvre le gestionnaire des contre-valeurs : toutes les devises du
  /// portefeuille, éditables (saisie manuelle ou cotation en ligne). Ouvert
  /// depuis le bouton d'actualisation de l'en-tête de colonne
  /// « VALEUR DEVISE ACTUELLE ».
  Future<void> _openRatesManager() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _fxSurfaceFor(context),
          title: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text('Contre-valeurs des devises',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _fxTextFor(context))),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Une pastille par devise du portefeuille. Cliquez sur une '
                    'devise pour saisir son taux courant ou le coter en ligne : '
                    'la table et le profil de choc se recalculent aussitôt.',
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: _fxMutedFor(context)),
                  ),
                  const SizedBox(height: 12),
                  _FxRatesBar(
                    rates: _currentRates,
                    meta: _rateMeta,
                    isFixedParity: _isFixedParity,
                    onEdit: (code) {
                      _editRate(code).then((_) {
                        if (context.mounted) setDialogState(() {});
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre l'éditeur de taux courant (saisie manuelle + cotation en ligne).
  Future<void> _editRate(String code) async {
    final result = await showDialog<_RateEditResult>(
      context: context,
      builder: (ctx) => _RateEditorDialog(
        code: code,
        initialRate: _currentRates[code] ?? 0,
        rateService: _rateService,
      ),
    );
    if (result != null && result.rate > 0) {
      setState(() {
        _currentRates[code] = result.rate;
        _rateMeta[code] = _RateMeta(
          origin: result.origin,
          asOf: result.asOf,
          provider: result.provider,
        );
      });
      // Même raison que dans _refreshAllRates : garder le référentiel
      // partagé aligné sur le taux courant affiché ici.
      CurrencyRegistry().updateRate(code, result.rate);
      _runAnalysis();
    }
  }
}

/// Convertit une saisie (acceptant la virgule décimale et les espaces) en taux
/// numérique, ou `null` si la saisie est invalide.
double? _parseRateInput(String raw) {
  final cleaned = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}

/// Formate un horodatage de cotation de façon compacte : `HH:mm` si c'est
/// aujourd'hui, sinon `jj/MM HH:mm`.
String _formatRateAsOf(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(local.hour)}:${two(local.minute)}';
  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  return sameDay ? time : '${two(local.day)}/${two(local.month)} $time';
}

FxRiskAnalysisResult _emptyFxRiskAnalysisResult() {
  final now = DateTime.now();
  return FxRiskAnalysisResult(
    securities: const [],
    currencyExposures: const [],
    totalExposure: 0,
    globalFxGainLoss: 0,
    totalLongPositions: 0,
    totalShortPositions: 0,
    globalNetPosition: 0,
    capitalRequirement: 0,
    rwaChange: 0,
    marketRiskContribution: 0,
    analysisDate: now,
  );
}

/// Bouton d'information (ⓘ) ouvrant la méthodologie et les formules du risque
/// de change - placé près du titre du tableau pour rendre les chiffres
/// (notamment les 0) compréhensibles.
class _FxInfoButton extends StatelessWidget {
  const _FxInfoButton({required this.result});

  final FxRiskAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1E3A5F);
    final accent = _isFxDark(context)
        ? Colors.white.withValues(alpha: 0.75)
        : navy;
    return InkWell(
      borderRadius: BorderRadius.circular(2),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _FxMethodologyDialog(result: result),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
              color: accent.withValues(alpha: 0.35), width: 0.8),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text('MÉTHODOLOGIE',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: accent)),
      ),
    );
  }
}

/// Dialogue présentant la méthodologie du risque de change : périmètre de
/// l'analyse (parités fixes) et définition de la position longue.
class _FxMethodologyDialog extends StatelessWidget {
  const _FxMethodologyDialog({required this.result});

  final FxRiskAnalysisResult result;

  static const Color _navy = Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    final textColor = _fxTextFor(context);
    final muted = _fxMutedFor(context);
    final isDark = _isFxDark(context);

    return Dialog(
      backgroundColor: _fxSurfaceFor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: _fxBorderFor(context)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bandeau d'en-tête navy, aligné sur les en-têtes de tableaux.
            Container(
              color: _navy,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MÉTHODOLOGIE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.65))),
                  const SizedBox(height: 3),
                  const Text('Risque de change',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: Colors.white)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Le risque de change mesure l\'impact des variations de '
                      'cours des devises sur la valeur en XOF des positions '
                      'détenues en devise étrangère.',
                      style: TextStyle(
                          fontSize: 12.5, color: textColor, height: 1.55),
                    ),
                    const SizedBox(height: 14),
                    // Panneau « périmètre » : liseré navy, fond neutre.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : _navy.withValues(alpha: 0.04),
                        border: Border(
                          left: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : _navy,
                              width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PÉRIMÈTRE DE L\'ANALYSE',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: isDark ? textColor : _navy)),
                          const SizedBox(height: 5),
                          Text(
                            'La devise de référence (XOF) et l\'euro, lié au '
                            'XOF par une parité fixe (1 EUR = 655,957 FCFA), '
                            'ne portent aucun risque de change : leurs lignes '
                            'restent à zéro. Seuls les titres libellés dans '
                            'les autres devises alimentent le calcul.',
                            style: TextStyle(
                                fontSize: 12, color: muted, height: 1.55),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('DÉFINITIONS',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? textColor : _navy)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 5, right: 8),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.55)
                              : _navy,
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.55,
                                  color: textColor),
                              children: [
                                TextSpan(
                                    text: 'Position longue : ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? textColor : _navy)),
                                TextSpan(
                                  text: 'la banque détient la devise au '
                                      'travers des titres achetés (actif). '
                                      'Elle gagne si la devise s\'apprécie '
                                      'face au XOF, elle perd si la devise '
                                      'se déprécie.',
                                  style: TextStyle(color: muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // Pied de dialogue sobre.
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: _fxBorderFor(context)),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? textColor : _navy,
                    textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3),
                  ),
                  child: const Text('Fermer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FxEmptyState extends StatelessWidget {
  const _FxEmptyState({required this.hasMarketData});

  /// `true` : un portefeuille marché est importé mais ne contient AUCUN titre en
  /// devise étrangère (donc aucun risque de change). `false` : aucune donnée
  /// marché n'a encore été importée.
  final bool hasMarketData;

  @override
  Widget build(BuildContext context) {
    // Deux situations bien distinctes - il est important de ne pas les
    // confondre : « pas de risque de change » est un RÉSULTAT valide (et non une
    // absence de données), car la devise de référence (XOF) ne porte aucun
    // risque de change.
    final icon =
        hasMarketData ? CupertinoIcons.checkmark_shield : CupertinoIcons.tray;
    final accent = hasMarketData ? _fxSuccess : _fxPrimary;
    final title = hasMarketData
        ? 'Aucune exposition au risque de change'
        : 'Aucune donnée marché importée';
    final message = hasMarketData
        ? 'Le portefeuille est entièrement libellé en devise de référence (XOF) : '
            'il ne génère aucun risque de change. L\'exigence de fonds propres et '
            'le RWA change sont donc nuls (résultat normal). Le risque de change '
            'n\'apparaît que pour des titres en devise étrangère (USD, etc.).'
        : 'Importez le portefeuille depuis la base risque marché pour analyser '
            'les titres libellés en devise étrangère.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _fxSurfaceFor(context),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _fxBorderFor(context)),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _fxTextFor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _fxMutedFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Origine et horodatage d'un taux courant, pour traçabilité.
class _RateMeta {
  const _RateMeta({required this.origin, this.asOf, this.provider});

  final FxRateOrigin origin;
  final DateTime? asOf;
  final String? provider;
}

/// Barre des taux de change courants (spot), éditables. L'EUR (parité fixe avec
/// le XOF) est verrouillé : il ne porte aucun risque de change. Pour les devises
/// éditables (USD), l'utilisateur peut saisir le taux manuellement ou le coter
/// en ligne.
/// Met côte à côte le tableau (gauche) et le graphique de choc (droite).
/// Empile verticalement sur les fenêtres étroites. Porte la sélection de ligne
/// du tableau : le graphique de choc reflète le titre sélectionné.
class _FxContentSplit extends StatefulWidget {
  const _FxContentSplit({
    required this.result,
    this.onRefreshRates,
    this.onManageRates,
    this.refreshingRates = false,
  });

  final FxRiskAnalysisResult result;

  /// Actualisation en ligne des contre-valeurs courantes (bouton porté par
  /// l'en-tête de colonne du tableau).
  final Future<void> Function()? onRefreshRates;

  /// Saisie manuelle des contre-valeurs (même menu d'en-tête de colonne).
  final VoidCallback? onManageRates;
  final bool refreshingRates;

  @override
  State<_FxContentSplit> createState() => _FxContentSplitState();
}

class _FxContentSplitState extends State<_FxContentSplit> {
  FxSecurityAnalysis? _selected;

  @override
  void didUpdateWidget(covariant _FxContentSplit oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Après un nouvel import/calcul, la sélection peut référencer un titre
    // qui n'existe plus : on la réinitialise.
    if (_selected != null && !widget.result.securities.contains(_selected)) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return LayoutBuilder(
      builder: (context, c) {
        final hasFx =
            (result.totalLongPositions - result.totalShortPositions).abs() >
                0.01;
        final table = _FxSecuritiesTable(
          securities: result.securities,
          onSelectionChanged: (s) => setState(() => _selected = s),
          onRefreshRates: widget.onRefreshRates,
          onManageRates: widget.onManageRates,
          refreshingRates: widget.refreshingRates,
        );
        final right = _FxRightPanel(result: result, selected: _selected);
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: table),
              const SizedBox(height: 4),
              SizedBox(height: hasFx ? 500 : 300, child: right),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 6, child: table),
            const SizedBox(width: 4),
            Expanded(flex: 4, child: right),
          ],
        );
      },
    );
  }
}

/// Graphique « Scénario de choc de change » : profil de gain/perte de change
/// selon une variation (choc) de la devise vs XOF. Le périmètre suit la
/// sélection du tableau : titre sélectionné = profil de SA devise ; sinon,
/// position nette de l'ensemble des devises flottantes du portefeuille.
/// Le graphique est TOUJOURS affiché : sans sensibilité, la droite est plate.
class _FxShockChart extends StatefulWidget {
  const _FxShockChart({required this.result, this.selected});

  final FxRiskAnalysisResult result;
  final FxSecurityAnalysis? selected;

  @override
  State<_FxShockChart> createState() => _FxShockChartState();
}

class _FxShockChartState extends State<_FxShockChart> {
  static const double _baseMaxShock = 0.20; // ±20 % par défaut
  static const Color _navy = Color(0xFF1E3A5F);

  /// Borne d'affichage de l'axe des chocs. Reste à ±20 % tant que le choc
  /// réalisé y tient ; sinon s'étend à une valeur « ronde » qui englobe le
  /// choc courant avec 10 % de marge (ex. +76 % → axe ±80 %).
  double _resolveMaxShock(double currentShockAbs) {
    final needed = currentShockAbs * 1.1;
    if (needed <= _baseMaxShock) return _baseMaxShock;
    const steps = <double>[
      0.25, 0.30, 0.40, 0.50, 0.60, 0.75, 0.80, 1.0, 1.25, 1.5, 2.0, 3.0
    ];
    for (final s in steps) {
      if (needed <= s) return s;
    }
    return (needed / 0.5).ceilToDouble() * 0.5;
  }

  /// Position nette sensible au change = positions en devises FLOTTANTES vs XOF
  /// (USD…). L'EUR est exclu : sa parité fixe (1 EUR = 655,957 FCFA) annule tout
  /// risque de change ; le XOF/XAF (devise de référence) est exclu par nature.
  double _floatingNet() {
    var net = 0.0;
    for (final s in widget.result.securities) {
      final c = s.currency;
      if (c == 'XOF' || c == 'XAF' || c == 'EUR') continue;
      if (s.positionType == FxPositionType.short) {
        net -= s.currentValueInXof;
      } else if (s.positionType == FxPositionType.long) {
        net += s.currentValueInXof;
      }
    }
    return net;
  }

  /// Gain/perte de change RÉALISÉ du périmètre (devises flottantes seulement).
  double _floatingGain() {
    var gain = 0.0;
    for (final s in widget.result.securities) {
      final c = s.currency;
      if (c == 'XOF' || c == 'XAF' || c == 'EUR') continue;
      gain += s.fxGainLoss;
    }
    return gain;
  }

  /// Position nette, libellé de devise et gain réalisé du périmètre courant.
  (double, String, double) _scope() {
    final sel = widget.selected;
    if (sel != null) {
      // Parité fixe : un titre EUR ne porte aucune sensibilité au change.
      if (sel.currency == 'EUR') return (0.0, 'EUR', 0.0);
      final signed = sel.positionType == FxPositionType.short
          ? -sel.currentValueInXof
          : sel.currentValueInXof;
      return (signed, sel.currency, sel.fxGainLoss);
    }
    return (_floatingNet(), 'Devises', _floatingGain());
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final (net, curLabel, realizedGain) = _scope();
    final flat = net.abs() <= 0.01;
    // Choc équivalent au gain réalisé (gain = net × choc). L'axe s'adapte à ce
    // choc : pour un choc de +76 %, l'échelle s'étend à ±80 % au lieu de coller
    // le point au bord.
    final trueShock = flat ? 0.0 : realizedGain / net;
    final maxShock = _resolveMaxShock(trueShock.abs());
    final currentShock =
        flat ? 0.0 : trueShock.clamp(-maxShock, maxShock).toDouble();
    final isDark = _isFxDark(context);
    final accent = isDark ? Colors.white.withValues(alpha: 0.75) : _navy;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: _fxSurfaceFor(context),
        border: Border.all(color: _fxBorderFor(context)),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      // Carte adaptative : quand la hauteur disponible se réduit (petite
      // fenêtre), on replie d'abord le panneau d'interprétation puis le
      // sous-titre, pour toujours préserver le graphique sans débordement.
      child: LayoutBuilder(builder: (context, box) {
        final showInterpretation = box.maxHeight >= 280;
        final showSubtitle = box.maxHeight >= 150;
        return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête : barre d'accent navy + titre + pastille de périmètre.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 14,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text('Profil de gain et de perte de change',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: _fxTextFor(context))),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: accent.withValues(alpha: 0.35), width: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  (sel != null ? sel.currency : 'PORTEFEUILLE').toUpperCase(),
                  style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: accent),
                ),
              ),
            ],
          ),
          if (showSubtitle) ...[
            const SizedBox(height: 3),
            Text(
              sel != null
                  ? 'Choc appliqué au titre ${sel.titleName} (${sel.currency}).'
                  : 'Choc appliqué à la position nette du portefeuille. '
                      'Sélectionnez une ligne du tableau pour isoler un titre.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: _fxMutedFor(context)),
            ),
          ],
          if (showInterpretation) ...[
            const SizedBox(height: 6),
            // Panneau d'interprétation : liseré navy, fond neutre.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : _navy.withValues(alpha: 0.04),
                border: Border(
                  left: BorderSide(color: accent, width: 3),
                ),
              ),
              child: flat
                  ? Text(
                      sel != null && sel.currency == 'EUR'
                          ? 'Parité fixe (1 EUR = 655,957 FCFA) : ce titre ne '
                              'porte aucune sensibilité au change.'
                          : 'Aucune position en devise flottante : le profil '
                              'de gain et de perte est nul.',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                          color: _fxMutedFor(context)),
                    )
                  : _interpretationWidget(context, net, curLabel),
            ),
          ],
          const SizedBox(height: 4),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: net),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutQuart,
              builder: (context, animatedNet, child) {
                return CustomPaint(
                  painter: _FxShockPainter(
                    netSensitivity: animatedNet,
                    maxShock: maxShock,
                    currentShock: currentShock,
                    isDark: _isFxDark(context),
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ],
      );
      }),
    );
  }

  /// Encart d'interprétation : la position nette du périmètre, puis les DEUX
  /// scénarios ±10 % sur des lignes distinctes (gain en vert, perte en rouge),
  /// et le sens de la position.
  Widget _interpretationWidget(
      BuildContext context, double net, String curLabel) {
    final long = net >= 0;
    final isDark = _isFxDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POSITION NETTE ${curLabel.toUpperCase()}',
          style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? _fxTextFor(context) : _navy),
        ),
        const SizedBox(height: 3),
        Text(
          '${_compact(net.abs())} XOF (${long ? 'longue' : 'courte'})',
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _fxTextFor(context)),
        ),
        const SizedBox(height: 5),
        _scenarioLine(context, '$curLabel +10 %', net * 0.10),
        const SizedBox(height: 2),
        _scenarioLine(context, '$curLabel −10 %', net * -0.10),
      ],
    );
  }

  /// Une ligne de scénario : libellé du choc puis impact signé (gain/perte).
  Widget _scenarioLine(BuildContext context, String scenario, double pnl) {
    final gain = pnl >= 0;
    final color = gain ? _fxSuccess : _fxDanger;
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(scenario,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _fxTextFor(context))),
        ),
        Text('${_signed(pnl)} XOF',
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 4),
        Text('(${gain ? 'gain' : 'perte'})',
            style: TextStyle(fontSize: 10, color: _fxMutedFor(context))),
      ],
    );
  }

  String _signed(double v) => '${v >= 0 ? '+' : '−'}${_compact(v.abs())}';

  String _compact(double v) {
    final a = v.abs();
    if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(1)} Md';
    if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(0)} M';
    if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(0)} k';
    return v.toStringAsFixed(0);
  }
}

/// Peintre du profil de choc : droite de P&L = sensibilité nette × choc, avec
/// aires gain (vert) / perte (rouge), grille, axes et points repères.
class _FxShockPainter extends CustomPainter {
  _FxShockPainter({
    required this.netSensitivity,
    required this.maxShock,
    required this.currentShock,
    required this.isDark,
  });

  final double netSensitivity;
  final double maxShock;

  /// Choc équivalent à la position actuelle (variation réalisée) : le point
  /// ambre est placé sur la droite à cette abscisse, 0 si aucune variation.
  final double currentShock;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 54.0, padR = 14.0, padT = 12.0, padB = 26.0;
    final plot =
        Rect.fromLTRB(padL, padT, size.width - padR, size.height - padB);
    if (plot.width <= 0 || plot.height <= 0) return;
    final cx = plot.center.dx;
    final cy = plot.center.dy;
    final yMax = netSensitivity.abs() * maxShock;
    // Sensibilité nulle : le graphique reste affiché, la droite est plate sur
    // l'axe zéro (échelle neutre pour éviter la division par zéro).
    final flat = yMax <= 0;
    final yScale = flat ? 1.0 : yMax;

    final baseColor = isDark ? Colors.white : Colors.black;
    final gridPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final axisColor = baseColor.withValues(alpha: 0.40);

    double xFor(double shock) => cx + (shock / maxShock) * (plot.width / 2);
    double yFor(double pnl) => cy - (pnl / yScale) * (plot.height / 2);

    TextPainter label(String s, {bool bold = false, Color? color}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: 9.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? axisColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    }

    // Grille verticale + libellés X : 5 graduations réparties sur la plage
    // dynamique (-max, -max/2, 0, +max/2, +max).
    final ticks = <double>[
      -maxShock,
      -maxShock / 2,
      0.0,
      maxShock / 2,
      maxShock,
    ];
    for (final s in ticks) {
      final x = xFor(s);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      final l = label('${s > 0 ? '+' : ''}${(s * 100).toStringAsFixed(0)} %');
      l.paint(canvas, Offset(x - l.width / 2, plot.bottom + 6));
    }

    // Ligne de base (P&L = 0) + libellés Y.
    canvas.drawLine(
        Offset(plot.left, cy),
        Offset(plot.right, cy),
        Paint()
          ..color = axisColor
          ..strokeWidth = 1.2);
    if (!flat) {
      final topL = label('+${_compact(yMax)}');
      topL.paint(canvas, Offset(plot.left - topL.width - 6, plot.top - 2));
      final botL = label('-${_compact(yMax)}');
      botL.paint(canvas,
          Offset(plot.left - botL.width - 6, plot.bottom - botL.height + 2));
    }
    final zeroL = label('0');
    zeroL.paint(
        canvas, Offset(plot.left - zeroL.width - 6, cy - zeroL.height / 2));

    // Aires gain/perte (deux triangles autour du centre).
    void fillHalf(double xEnd, double yEnd) {
      final gain = yEnd < cy;
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(xEnd, cy)
        ..lineTo(xEnd, yEnd)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..color = (gain ? _fxSuccess : _fxDanger).withValues(alpha: 0.16));
    }

    final yL = yFor(netSensitivity * -maxShock);
    final yR = yFor(netSensitivity * maxShock);
    if (!flat) {
      fillHalf(plot.right, yR);
      fillHalf(plot.left, yL);
    }

    // Droite de P&L (plate sur l'axe zéro quand la sensibilité est nulle).
    canvas.drawLine(
        Offset(plot.left, yL),
        Offset(plot.right, yR),
        Paint()
          ..color = _fxPrimary
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);

    // Points repères (les ±10 % n'apportent rien sur une droite plate).
    // Le point CENTRAL (position actuelle, choc 0 %) porte une couleur
    // distincte (ambre) avec un halo, pour ne pas se fondre dans la droite.
    const currentColor = Color(0xFFF9A825);
    void dot(double shock, {bool current = false}) {
      final pnl = netSensitivity * shock;
      final p = Offset(xFor(shock), yFor(pnl));
      final c = current ? currentColor : (pnl >= 0 ? _fxSuccess : _fxDanger);
      if (current) {
        canvas.drawCircle(
            p, 8, Paint()..color = currentColor.withValues(alpha: 0.25));
      }
      canvas.drawCircle(p, current ? 5 : 3.5, Paint()..color = c);
      canvas.drawCircle(
          p,
          current ? 5 : 3.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      if (!current) {
        final l = label('${pnl >= 0 ? '+' : ''}${_compact(pnl)}',
            bold: true, color: c);
        final dx = shock > 0 ? p.dx - l.width - 6 : p.dx + 6;
        l.paint(canvas, Offset(dx, p.dy - l.height - 2));
      } else if (shock.abs() > 0.0005) {
        // Position actuelle décalée du centre : afficher son gain réalisé.
        final l = label('${pnl >= 0 ? '+' : ''}${_compact(pnl)}',
            bold: true, color: currentColor);
        final dx = shock > 0 ? p.dx - l.width - 8 : p.dx + 8;
        l.paint(canvas, Offset(dx, p.dy + 4));
      }
    }

    if (!flat) {
      // Points repères alignés sur les graduations intermédiaires (±max/2).
      // Pour l'échelle par défaut ±20 %, ils tombent sur ±10 % comme avant.
      dot(-maxShock / 2);
      dot(maxShock / 2);
    }
    dot(flat ? 0.0 : currentShock, current: true);
  }

  String _compact(double v) {
    final a = v.abs();
    if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(1)} Md';
    if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(0)} M';
    if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(0)} k';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _FxShockPainter old) =>
      old.netSensitivity != netSensitivity ||
      old.maxShock != maxShock ||
      old.currentShock != currentShock ||
      old.isDark != isDark;
}

/// Colonne de droite : le profil de choc de change, calé sur le titre
/// sélectionné dans le tableau (ou sur le portefeuille entier à défaut).
class _FxRightPanel extends StatelessWidget {
  const _FxRightPanel({required this.result, this.selected});

  final FxRiskAnalysisResult result;
  final FxSecurityAnalysis? selected;

  @override
  Widget build(BuildContext context) =>
      _FxShockChart(result: result, selected: selected);
}

class _FxRatesBar extends StatelessWidget {
  const _FxRatesBar({
    required this.rates,
    required this.meta,
    required this.isFixedParity,
    required this.onEdit,
  });

  final Map<String, double> rates;
  final Map<String, _RateMeta> meta;
  final bool Function(String) isFixedParity;
  final void Function(String) onEdit;

  @override
  Widget build(BuildContext context) {
    final entries = rates.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries) _rateChip(context, e.key, e.value),
      ],
    );
  }

  /// Pastille compacte d'un taux : `CODE  valeur XOF  ⟳`. L'origine (référence /
  /// saisie / en ligne) est portée par l'icône de fin et détaillée en infobulle.
  Widget _rateChip(BuildContext context, String code, double rate) {
    final fixed = isFixedParity(code);
    final accent = fixed ? _fxMutedFor(context) : _fxPrimary;
    final info = meta[code];
    final statusIcon = _statusIconFor(fixed, info);

    return InkWell(
      onTap: fixed ? null : () => onEdit(code),
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: fixed ? 0.04 : 0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(code,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: accent)),
            const SizedBox(width: 4),
            Text(formatDecimal(rate, 2),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: _fxTextFor(context))),
            const SizedBox(width: 2),
            Text('XOF',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: _fxMutedFor(context))),
            const SizedBox(width: 4),
            Icon(statusIcon,
                size: 12, color: accent.withValues(alpha: fixed ? 0.6 : 0.9)),
          ],
        ),
      ),
    );
  }

  /// Icône d'origine du taux : cadenas (parité fixe), nuage (coté en ligne) ou
  /// crayon (saisie manuelle / taux de référence).
  IconData _statusIconFor(bool fixed, _RateMeta? info) {
    if (fixed) return CupertinoIcons.lock_fill;
    return switch (info?.origin) {
      FxRateOrigin.online => CupertinoIcons.cloud_download,
      _ => CupertinoIcons.pencil,
    };
  }
}

/// Résultat de l'éditeur de taux : valeur retenue + origine (saisie ou en ligne)
/// avec son horodatage et sa source.
class _RateEditResult {
  const _RateEditResult({
    required this.rate,
    required this.origin,
    this.asOf,
    this.provider,
  });

  final double rate;
  final FxRateOrigin origin;
  final DateTime? asOf;
  final String? provider;
}

/// Dialogue d'édition d'un taux courant : saisie manuelle OU cotation en ligne.
class _RateEditorDialog extends StatefulWidget {
  const _RateEditorDialog({
    required this.code,
    required this.initialRate,
    required this.rateService,
  });

  final String code;
  final double initialRate;
  final FxRateService rateService;

  @override
  State<_RateEditorDialog> createState() => _RateEditorDialogState();
}

class _RateEditorDialogState extends State<_RateEditorDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialRate == 0 ? '' : formatDecimal(widget.initialRate, 4),
  );

  bool _fetching = false;
  String? _error;
  LiveFxRate? _fetched;
  // Devient `true` dès que l'utilisateur retouche le champ après une cotation :
  // la valeur n'est alors plus considérée comme « en ligne ».
  bool _editedSinceFetch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchOnline() async {
    setState(() {
      _fetching = true;
      _error = null;
    });
    try {
      final quote = await widget.rateService.fetchRateToXof(widget.code);
      if (!mounted) return;
      setState(() {
        _fetched = quote;
        _editedSinceFetch = false;
        _controller.text = formatDecimal(quote.rateToXof, 4);
        _controller.selection =
            TextSelection.collapsed(offset: _controller.text.length);
      });
    } on FxRateException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Échec inattendu de la récupération en ligne.');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _submit() {
    final rate = _parseRateInput(_controller.text);
    if (rate == null || rate <= 0) {
      setState(
          () => _error = 'Saisissez un taux numérique strictement positif.');
      return;
    }
    final usedOnline = _fetched != null && !_editedSinceFetch;
    Navigator.of(context).pop(_RateEditResult(
      rate: rate,
      origin: usedOnline ? FxRateOrigin.online : FxRateOrigin.manual,
      asOf: usedOnline ? _fetched!.asOf : DateTime.now(),
      provider: usedOnline ? _fetched!.provider : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final showSuccess =
        _fetched != null && !_editedSinceFetch && _error == null;
    return AlertDialog(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _fxPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(CupertinoIcons.money_dollar_circle_fill,
                size: 20, color: _fxPrimary),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Taux courant - ${widget.code}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Mise à jour de la valorisation',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: _fxMutedFor(context))),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: _fxPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                const Icon(CupertinoIcons.arrow_right_arrow_left,
                    size: 14, color: _fxPrimary),
                const SizedBox(width: 2),
                Text('1 ${widget.code} = ? XOF',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _fxPrimary)),
              ]),
            ),
            const SizedBox(height: 3),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Taux de change',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                suffix: Text('XOF',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _fxTextFor(context))),
              ),
              onChanged: (_) {
                if (_editedSinceFetch && _error == null) return;
                setState(() {
                  _editedSinceFetch = true;
                  _error = null;
                });
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _fetching ? null : _fetchOnline,
                icon: _fetching
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CupertinoActivityIndicator(radius: 7),
                      )
                    : const Icon(CupertinoIcons.cloud_download_fill, size: 16),
                label: Text(_fetching
                    ? 'Récupération en cours…'
                    : 'Récupérer le taux en ligne'),
              ),
            ),
            if (showSuccess) ...[
              const SizedBox(height: 3),
              _banner(
                context,
                icon: CupertinoIcons.check_mark_circled_solid,
                color: _fxSuccess,
                message:
                    'Coté le ${_formatRateAsOf(_fetched!.asOf)} · ${_fetched!.provider}',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 3),
              _banner(
                context,
                icon: CupertinoIcons.exclamationmark_triangle_fill,
                color: _fxDanger,
                message: _error!,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _fetching ? null : _submit,
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('Valider',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _banner(BuildContext context,
      {required IconData icon, required Color color, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _fxTextFor(context))),
          ),
        ],
      ),
    );
  }
}

class _FxKpiSection extends StatelessWidget {
  const _FxKpiSection({required this.result});

  final FxRiskAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final gain = result.globalFxGainLoss;
    // S'abonne à l'unité d'affichage globale (M / Md) : la carte se reconstruit
    // quand l'utilisateur change l'unité via le sélecteur du bandeau supérieur.
    final unit = PortfolioAmountUnitScope.of(context);
    // Précision adaptative : plus la valeur est petite dans l'unité choisie,
    // plus on garde de décimales (jusqu'à 3), afin qu'un basculement d'unité
    // ne déforme pas le chiffre - 973 M doit se lire « 0,973 Md », pas
    // « 1 Md ». Les décimales inutiles (zéros de fin) ne s'affichent pas.
    int decimalesPour(double scaled) {
      final abs = scaled.abs();
      if (abs >= 100) return 0;
      if (abs >= 10) return 1;
      if (abs >= 1) return 2;
      return 3;
    }

    String fmt(double value) {
      final scaled = value / unit.divisor;
      return '${AppFormatters.decimalNumber(scaled, maxDecimals: decimalesPour(scaled))} '
          '${unit.label}';
    }

    // Variante signée : le total de la table ci-dessous affiche déjà la
    // perte/gain avec son signe (ex. -346 037 069), la carte doit montrer
    // le même nombre plutôt que sa valeur absolue à côté d'un libellé
    // « Perte » - sinon les deux se contredisent visuellement. Une perte
    // qui s'arrondit à zéro à la précision affichée n'affiche pas « -0,0 ».
    String fmtSigned(double value) {
      final scaled = value / unit.divisor;
      final decimals = decimalesPour(scaled);
      final rounded = double.parse(scaled.toStringAsFixed(decimals));
      final normalized = rounded == 0 ? 0.0 : rounded;
      return '${AppFormatters.decimalNumber(normalized, maxDecimals: decimals)} '
          '${unit.label}';
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FxKpiCard(
              label: 'Exposition Totale',
              value: fmt(result.totalExposure),
              unit: 'FCFA',
              subtitle: 'Valeur nominale de l\'ensemble des titres exposés',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FxKpiCard(
              label: 'Gain/Perte Global',
              value: fmtSigned(gain),
              unit: 'FCFA',
              subtitle: gain >= 0 ? 'Gain net de change sur le portefeuille' : 'Perte nette de change sur le portefeuille',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FxKpiCard(
              label: 'Exigence FP Change',
              value: fmt(result.capitalRequirement),
              unit: 'FCFA',
              subtitle: 'Position nette globale × 9 %',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FxKpiCard(
              label: 'RWA Change',
              value: fmt(result.rwaChange),
              unit: 'FCFA',
              subtitle: 'Exigence FP × 11,11',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FxKpiCard(
              label: 'Contribution Risque Marché',
              value: result.marketRiskContribution.toStringAsFixed(1),
              unit: '%',
              subtitle: 'Part du risque de change dans le RWA marché',
            ),
          ),
        ],
      ),
    );
  }
}

class _FxKpiCard extends StatefulWidget {
  const _FxKpiCard({
    required this.label,
    required this.value,
    required this.unit,
    this.subtitle,
  });

  final String label;
  final String value;
  final String unit;
  final String? subtitle;

  @override
  State<_FxKpiCard> createState() => _FxKpiCardState();
}

class _FxKpiCardState extends State<_FxKpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const deepBlue = Color(0xFF0F172A);
    const line = Color(0xFFE2E8F0);
    const muted = Color(0xFF64748B);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: line),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: deepBlue.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        // Anneau de survol au premier plan, couleur opaque : évite la bordure
        // entrecoupée (anti-aliasing sur largeurs fractionnaires).
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: _hovered
                ? Color.alphaBlend(
                    deepBlue.withValues(alpha: 0.30), Colors.white)
                : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Label
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: muted,
                ),
              ),
            ),
            // Séparateur
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, thickness: 0.7, color: line),
            ),
            // Valeur
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: widget.value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: deepBlue,
                      ),
                    ),
                    if (widget.unit.isNotEmpty)
                      TextSpan(
                        text: ' ${widget.unit}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: deepBlue,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Sous-titre
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.subtitle!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: muted,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tableau des titres exposés - colonnes TITRE et STATUT fixes
class _FxSecuritiesTable extends StatefulWidget {
  const _FxSecuritiesTable({
    required this.securities,
    this.onSelectionChanged,
    this.onRefreshRates,
    this.onManageRates,
    this.refreshingRates = false,
  });

  final List<FxSecurityAnalysis> securities;

  /// Notifie le parent quand une ligne est sélectionnée (null = désélection),
  /// pour que le graphique de choc reflète le titre concerné.
  final ValueChanged<FxSecurityAnalysis?>? onSelectionChanged;

  /// Actualise en ligne les contre-valeurs courantes ; menu logé dans
  /// l'en-tête de la colonne VALEUR DEVISE ACTUELLE.
  final Future<void> Function()? onRefreshRates;

  /// Ouvre la saisie manuelle des contre-valeurs (même menu).
  final VoidCallback? onManageRates;
  final bool refreshingRates;

  @override
  State<_FxSecuritiesTable> createState() => _FxSecuritiesTableState();
}

class _FxSecuritiesTableState extends State<_FxSecuritiesTable> {
  // Défilement VERTICAL : une seule liste virtualisée (ListView.builder) pour
  // tout le corps. Chaque ligne est UN widget unique qui contient à la fois la
  // colonne gauche figée, le milieu et la colonne droite figée ; comme tout
  // partage l'unique position de défilement vertical, les colonnes figées ne
  // peuvent JAMAIS dériver par rapport au milieu - l'alignement est garanti par
  // construction, sans aucune synchronisation à maintenir. La virtualisation
  // est conservée : seules les lignes visibles sont construites (indispensable
  // pour un portefeuille de plusieurs milliers de titres).
  final ScrollController _bodyVSC = ScrollController();

  // Défilement HORIZONTAL du milieu : UN SEUL contrôleur partagé, source unique
  // de l'offset. Seule l'entête est un vrai défilable (elle porte ce contrôleur
  // et reste glissable) ; le pied et chaque ligne visible se contentent de se
  // translater de ce même offset (Transform.translate). On ne crée donc JAMAIS
  // de contrôleur par ligne.
  //
  // Pourquoi c'est essentiel : avec un `LinkedScrollControllerGroup` alimenté
  // par un contrôleur par ligne, le recyclage permanent des lignes par la
  // `ListView` ajoutait/retirait sans fin des contrôleurs au groupe, ce qui
  // empêchait la file de microtâches de se vider - `pumpAndSettle` ne
  // convergeait jamais (timeout) et le défilement saccadait en production.
  final ScrollController _midHSC = ScrollController();

  int? _selectedIndex;
  static const Color _selColor = Color(0xFFE3F2FD);

  /// Tri par colonne (index visuel 0..7) ; null = ordre d'import.
  int? _sortColumn;
  bool _sortAscending = true;

  void _onSort(int column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        // Colonnes texte : ascendant par défaut ; numériques : descendant.
        _sortAscending = column == 0 || column == 1;
      }
      // La sélection référence un index de la liste triée : on la vide pour
      // éviter qu'elle saute sur une autre ligne après le tri.
      _selectedIndex = null;
    });
    widget.onSelectionChanged?.call(null);
  }

  List<FxSecurityAnalysis> get _sortedSecurities {
    final list = List<FxSecurityAnalysis>.of(widget.securities);
    final col = _sortColumn;
    if (col == null) return list;
    int compare(FxSecurityAnalysis a, FxSecurityAnalysis b) => switch (col) {
          0 => a.titleName.toLowerCase().compareTo(b.titleName.toLowerCase()),
          1 => a.currency.compareTo(b.currency),
          2 => a.currentValueInXof.compareTo(b.currentValueInXof),
          3 => a.initialRate.compareTo(b.initialRate),
          4 => a.currentRate.compareTo(b.currentRate),
          5 => a.currencyVariationPercent
              .compareTo(b.currencyVariationPercent),
          6 => a.rwa.compareTo(b.rwa),
          _ => a.fxGainLoss.compareTo(b.fxGainLoss),
        };
    list.sort((a, b) => _sortAscending ? compare(a, b) : compare(b, a));
    return list;
  }

  /// En-tête de colonne triable : libellé + chevron d'état, clic = tri.
  Widget _sortableHCell(
      int column, String text, TextAlign align, TextStyle style) {
    final sorted = _sortColumn == column;
    final icon = sorted
        ? (_sortAscending
            ? CupertinoIcons.chevron_up
            : CupertinoIcons.chevron_down)
        : CupertinoIcons.arrow_up_arrow_down;
    final iconWidget = Icon(icon,
        size: 10, color: Colors.white.withValues(alpha: sorted ? 1.0 : 0.45));
    final labelWidget = Text(text, style: style, maxLines: 1);
    return InkWell(
      onTap: () => _onSort(column),
      child: Container(
        height: 40,
        alignment: _cellAlignment(align),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: _cellAlignment(align),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: align == TextAlign.right
                ? [iconWidget, const SizedBox(width: 3), labelWidget]
                : [labelWidget, const SizedBox(width: 3), iconWidget],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _midHSC.dispose();
    _bodyVSC.dispose();
    super.dispose();
  }

  /// Offset horizontal courant du milieu (0 si pas encore attaché).
  double get _midOffset => _midHSC.hasClients ? _midHSC.offset : 0.0;

  /// Enveloppe un contenu de largeur fixe [contentWidth] (≥ largeur du viewport)
  /// pour qu'il se translate du même offset horizontal que l'entête, en restant
  /// rogné à la largeur disponible. Utilisé par le pied et chaque ligne : aucun
  /// contrôleur supplémentaire, l'alignement avec l'entête est garanti.
  Widget _syncedMiddle(double contentWidth, Widget child) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _midHSC,
        builder: (_, __) => Transform.translate(
          offset: Offset(-_midOffset, 0),
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: contentWidth,
            maxWidth: contentWidth,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final securities = _sortedSecurities;

    const rowH = 40.0;
    const headerTextLight = TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 0.5);
    const cellText = TextStyle(
        fontSize: 11, color: Color(0xFF1E3A5F), fontWeight: FontWeight.w500);

    return LayoutBuilder(builder: (context, constraints) {
      // Largeurs naturelles des colonnes.
      const naturalColW = <int, double>{
        0: 180, // ÉMETTEUR (Left fixed)
        1: 80, // DEVISE
        2: 190, // VALEUR NOMINALE (XOF)
        3: 160, // VALEUR DEVISE ACHAT (1 USD = 584,34)
        4: 160, // VALEUR DEVISE ACTUELLE
        5: 140, // VARIATION DEVISE (%)
        6: 150, // RWA (XOF)
        7: 120, // GAIN/PERTE DE CHANGE (Right fixed)
      };
      const naturalMiddle = 80 + 190 + 160 + 160 + 140 + 150; // 880
      // Quand le tableau dispose de plus d'espace que sa largeur naturelle, on
      // étire proportionnellement les colonnes du milieu pour occuper toute la
      // largeur : plus d'espace vide entre RWA (XOF) et GAIN/PERTE DE CHANGE.
      // Sinon (écran étroit) on garde les largeurs naturelles et le milieu
      // défile horizontalement comme avant.
      final availableMiddle =
          constraints.maxWidth - naturalColW[0]! - naturalColW[7]!;
      final stretch =
          constraints.maxWidth.isFinite && availableMiddle > naturalMiddle
              ? availableMiddle / naturalMiddle
              : 1.0;
      final colW = <int, double>{
        0: naturalColW[0]!,
        1: naturalColW[1]! * stretch,
        2: naturalColW[2]! * stretch,
        3: naturalColW[3]! * stretch,
        4: naturalColW[4]! * stretch,
        5: naturalColW[5]! * stretch,
        6: naturalColW[6]! * stretch,
        7: naturalColW[7]!,
      };
      // Les 5 séparateurs _VDiv (0.7 px chacun) s'ajoutent à la largeur réelle
      // du Row du milieu ; middleWidth doit les inclure pour que l'OverflowBox
      // de _syncedMiddle corresponde exactement au contenu réel et évite
      // l'erreur « ScrollController attached to multiple scroll views ».
      const vDivW = 0.7;
      const vDivCount = 5; // entre les 6 colonnes du milieu
      final middleWidth = colW[1]! +
          colW[2]! +
          colW[3]! +
          colW[4]! +
          colW[5]! +
          colW[6]! +
          vDivCount * vDivW;
      // build header cells for scrollable middle (cols 1-8), sized with colW
      final headerMiddle = Row(children: [
        SizedBox(
            width: colW[1]!,
            child: _sortableHCell(1, 'DEVISE', TextAlign.left,
                headerTextLight)),
        const _VDiv(isHeader: true),
        SizedBox(
            width: colW[2]!,
            child: _sortableHCell(2, 'VALEUR NOMINALE (XOF)', TextAlign.right,
                headerTextLight)),
        const _VDiv(isHeader: true),
        SizedBox(
            width: colW[3]!,
            child: _sortableHCell(3, 'VALEUR DEVISE ACHAT', TextAlign.right,
                headerTextLight)),
        const _VDiv(isHeader: true),
        SizedBox(
            width: colW[4]!,
            child: Row(children: [
              Expanded(
                  child: _sortableHCell(4, 'VALEUR DEVISE ACTUELLE',
                      TextAlign.right, headerTextLight)),
              if (widget.onRefreshRates != null || widget.onManageRates != null)
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 6),
                  child: widget.refreshingRates
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white),
                        )
                      : PopupMenuButton<int>(
                          tooltip: '',
                          padding: EdgeInsets.zero,
                          position: PopupMenuPosition.under,
                          onSelected: (v) {
                            if (v == 0) {
                              widget.onRefreshRates?.call();
                            } else {
                              widget.onManageRates?.call();
                            }
                          },
                          itemBuilder: (context) => [
                            if (widget.onRefreshRates != null)
                              const PopupMenuItem(
                                value: 0,
                                height: 34,
                                child: Text('Actualiser en ligne',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            if (widget.onManageRates != null)
                              const PopupMenuItem(
                                value: 1,
                                height: 34,
                                child: Text('Saisir les contre-valeurs',
                                    style: TextStyle(fontSize: 12)),
                              ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(CupertinoIcons.arrow_clockwise,
                                size: 13, color: Colors.white),
                          ),
                        ),
                ),
            ])),
        const _VDiv(isHeader: true),
        SizedBox(
            width: colW[5]!,
            child: _sortableHCell(5, 'VARIATION DEVISE (%)', TextAlign.right,
                headerTextLight)),
        const _VDiv(isHeader: true),
        SizedBox(
            width: colW[6]!,
            child: _sortableHCell(6, 'RWA (XOF)', TextAlign.right,
                headerTextLight)),
      ]);

      // Largeurs des 6 colonnes du milieu (cols 1..6), dans l'ordre.
      final middleWidths = <double>[
        colW[1]!,
        colW[2]!,
        colW[3]!,
        colW[4]!,
        colW[5]!,
        colW[6]!,
      ];

      return Container(
        decoration: BoxDecoration(
          color: _fxSurfaceFor(context),
          border: Border.all(color: _fxBorderFor(context)),
          borderRadius: BorderRadius.circular(1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: Builder(
            builder: (context) {
              return Column(children: [
                // Header row
                Container(
                  height: rowH,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A5F), // deepBlue
                  ),
                  child: Row(children: [
                    SizedBox(
                        width: colW[0]!,
                        child: _sortableHCell(
                            0, 'ÉMETTEUR', TextAlign.left, headerTextLight)),
                    const _VDiv(isHeader: true),
                    Expanded(
                      child: SizedBox(
                        height: rowH,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _midHSC,
                            child: headerMiddle,
                          ),
                        ),
                      ),
                    ),
                    const _VDiv(isHeader: true),
                    SizedBox(
                        width: colW[7]!,
                        child: _sortableHCell(7, 'GAIN/PERTE DE CHANGE',
                            TextAlign.right, headerTextLight)),
                  ]),
                ),
                // Body - liste verticale unique et VIRTUALISÉE. Chaque ligne
                // (_FxSecurityRow) porte la colonne gauche figée, le milieu
                // défilant et la colonne droite figée ; toutes partagent
                // l'unique défilement vertical, donc l'alignement des colonnes
                // figées avec le milieu est garanti par construction. Le milieu
                // de chaque ligne se synchronise horizontalement avec l'entête,
                // le pied et les autres lignes via le groupe lié.
                Expanded(
                  child: Stack(
                    children: [
                      Scrollbar(
                        controller: _bodyVSC,
                        thumbVisibility: true,
                        child: ListView.builder(addSemanticIndexes: false,
                          controller: _bodyVSC,
                          itemExtent: rowH,
                          itemCount: securities.length,
                          itemBuilder: (context, i) {
                            final cells =
                                _buildDataCells(securities[i], i, cellText);
                            final selected = i == _selectedIndex;
                            final bg = selected
                                ? _selColor
                                : (i.isEven
                                    ? Colors.transparent
                                    : Colors.black.withValues(alpha: 0.02));
                            final middleRow = Row(
                              children: [
                                for (int j = 0;
                                    j < middleWidths.length;
                                    j++) ...[
                                  if (j > 0) const _VDiv(),
                                  SizedBox(
                                      width: middleWidths[j],
                                      child: cells[1 + j]),
                                ],
                              ],
                            );
                            return _FxSecurityRow(
                              height: rowH,
                              background: bg,
                              leftWidth: colW[0]!,
                              rightWidth: colW[7]!,
                              leftCell: cells[0],
                              middle: _syncedMiddle(middleWidth, middleRow),
                              rightCell: cells[7],
                              onTap: () {
                                setState(() => _selectedIndex =
                                    _selectedIndex == i ? null : i);
                                widget.onSelectionChanged?.call(
                                    _selectedIndex == null
                                        ? null
                                        : securities[i]);
                              },
                            );
                          },
                        ),
                      ),
                      // Reprise du défilement HORIZONTAL du milieu par glissement
                      // direct sur le corps : on pilote l'unique _midHSC partagé
                      // (l'entête en est le défilable réel). Bande limitée entre
                      // les deux colonnes figées ; translucide pour laisser passer
                      // le tap (sélection de ligne) et le défilement vertical à la
                      // liste en dessous.
                      Positioned(
                        left: colW[0]!,
                        right: colW[7]!,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (d) {
                            if (!_midHSC.hasClients) return;
                            final max = _midHSC.position.maxScrollExtent;
                            _midHSC.jumpTo(
                                (_midHSC.offset - d.delta.dx).clamp(0.0, max));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Pied de tableau (Footer row)
                Builder(
                  builder: (context) {
                    final totalFxGainLoss = securities.fold<double>(0, (sum, s) => sum + s.fxGainLoss);
                    return Container(
                      height: rowH,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withValues(alpha: 0.05),
                        border: Border(
                            top: BorderSide(
                                color: const Color(0xFF1E3A5F).withValues(alpha: 0.15))),
                      ),
                      child: Row(children: [
                        SizedBox(
                            width: colW[0]!,
                            child: _headerCell('TOTAL', TextAlign.left, headerTextLight.copyWith(color: const Color(0xFF1E3A5F), fontSize: 12))),
                        const _VDiv(),
                        Expanded(
                          child: _syncedMiddle(
                            middleWidth,
                            Row(children: [
                              SizedBox(width: middleWidths[0]), // DEVISE
                              const _VDiv(),
                              SizedBox(width: middleWidths[1]), // NOMINALE
                              const _VDiv(),
                              SizedBox(width: middleWidths[2]), // TAUX ACQUIS.
                              const _VDiv(),
                              SizedBox(width: middleWidths[3]), // TAUX ACTUEL
                              const _VDiv(),
                              SizedBox(width: middleWidths[4]), // VARIATION
                              const _VDiv(),
                              SizedBox(
                                  width: middleWidths[5], // RWA
                                  child: _dataCell(formatLargeNumber(securities.fold<double>(0, (sum, s) => sum + s.rwa)), cellText.copyWith(fontWeight: FontWeight.w700), align: TextAlign.right)),
                            ]),
                          ),
                        ),
                        const _VDiv(),
                        SizedBox(
                            width: colW[7]!,
                            child: _dataCell(formatLargeNumber(totalFxGainLoss), cellText.copyWith(fontWeight: FontWeight.w800, color: totalFxGainLoss >= 0 ? _fxSuccess : _fxDanger), align: TextAlign.right)),
                      ]),
                    );
                  }
                ),
              ]);
            },
          ),
        ),
      );
    });
  }

  /// Construit les 8 cellules d'une ligne (cols 0..7). Le fond (zébrage /
  /// sélection) est porté par la ligne elle-même (_FxSecurityRow), les cellules
  /// restent donc transparentes. La nature de la position (longue) n'est plus
  /// une colonne : elle est constante et affichée une fois dans l'en-tête.
  List<Widget> _buildDataCells(
      FxSecurityAnalysis s, int index, TextStyle baseStyle) {
    return [
      _dataCell(s.titleName, baseStyle),
      _dataCell(s.currency,
          baseStyle.copyWith(fontWeight: FontWeight.w600, color: _fxPrimary),
          chip: _fxPrimary.withValues(alpha: 0.08)),
      _dataCell(formatLargeNumber(s.currentValueInXof), baseStyle,
          align: TextAlign.right),
      _dataCell(
          '1 ${s.currency} = ${formatDecimal(s.initialRate, 2)} XOF',
          baseStyle,
          align: TextAlign.right),
      _dataCell(
          '1 ${s.currency} = ${formatDecimal(s.currentRate, 2)} XOF',
          baseStyle.copyWith(fontWeight: FontWeight.w600),
          align: TextAlign.right),
      _dataCell(
          '${s.currencyVariationPercent >= 0 ? '+' : ''}${formatDecimal(s.currencyVariationPercent, 2)}%',
          baseStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: s.currencyVariationPercent >= 0 ? _fxSuccess : _fxDanger),
          align: TextAlign.right),
      _dataCell(formatLargeNumber(s.rwa),
          baseStyle.copyWith(fontWeight: FontWeight.w600),
          align: TextAlign.right),
      _dataCell(
          formatLargeNumber(s.fxGainLoss),
          baseStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: s.fxGainLoss.abs() < 0.01
                  ? _fxTextFor(context)
                  : (s.fxGainLoss > 0 ? _fxSuccess : _fxDanger)),
          align: TextAlign.right),
    ];
  }
}

/// Une ligne du corps du tableau.
///
/// Structure : colonne gauche figée · milieu (déjà synchronisé horizontalement
/// par le parent via [Transform.translate]) · colonne droite figée - le tout
/// dans UN seul widget, donc partageant l'unique défilement vertical de la
/// liste (alignement garanti). La ligne ne possède AUCUN [ScrollController] :
/// elle se contente d'afficher le milieu fourni, ce qui rend le recyclage par
/// la `ListView` totalement inerte (pas de création/destruction de contrôleur).
class _FxSecurityRow extends StatelessWidget {
  const _FxSecurityRow({
    required this.height,
    required this.background,
    required this.leftWidth,
    required this.rightWidth,
    required this.leftCell,
    required this.middle,
    required this.rightCell,
    required this.onTap,
  });

  final double height;
  final Color background;
  final double leftWidth;
  final double rightWidth;
  final Widget leftCell;
  final Widget middle;
  final Widget rightCell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: background,
          border: Border(
            bottom:
                BorderSide(color: _fxBorder.withValues(alpha: 0.3), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: leftWidth, child: leftCell),
            const _VDiv(),
            Expanded(child: middle),
            const _VDiv(),
            SizedBox(width: rightWidth, child: rightCell),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets internes ───

/// Séparateur vertical fin entre colonnes.
/// [isHeader] = true → trait blanc semi-transparent (fond sombre du header) ;
/// false → trait bleu très clair (fond blanc des lignes et du footer).
class _VDiv extends StatelessWidget {
  const _VDiv({this.isHeader = false});
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.7,
      color: isHeader
          ? Colors.white.withValues(alpha: 0.20)
          : const Color(0xFF1E3A5F).withValues(alpha: 0.10),
    );
  }
}

/// Ligne d'entête (pas d'ellipsis, tout doit être visible)
/// Convertit un [TextAlign] horizontal en [Alignment] de cellule.
Alignment _cellAlignment(TextAlign align) => switch (align) {
      TextAlign.right => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    };

Widget _headerCell(String text, TextAlign align, TextStyle style) => Container(
      height: 40,
      alignment: _cellAlignment(align),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: _cellAlignment(align),
        child: Text(text, style: style, textAlign: align, maxLines: 1),
      ),
    );

/// Ligne de donnée
Widget _dataCell(String text, TextStyle style,
        {TextAlign align = TextAlign.left, Color? chip, Color? bg}) =>
    Container(
      height: 40,
      decoration: BoxDecoration(color: bg ?? Colors.transparent),
      alignment: _cellAlignment(align),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: chip != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                  color: chip,
                  borderRadius: BorderRadius.circular(AppTheme.radius)),
              child: Text(text,
                  style: style,
                  textAlign: align,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            )
          : Text(text,
              style: style,
              textAlign: align,
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
    );
