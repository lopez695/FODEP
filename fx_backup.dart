/// Écran d'analyse du Risque de Change - Version refactorisée
/// Présentation multi-niveaux: Titres, Agrégation Devise, Calculs Prudentiels
/// Conforme à la spécification BCEAO
library fx_risk_analysis_screen;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
const Color _fxWarning = Color(0xFFF59E0B);
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
  final Map<String, double> _currentRates = {};

  /// Origine et horodatage de chaque taux courant (référence interne, saisie
  /// manuelle ou cotation en ligne), pour traçabilité dans la barre.
  final Map<String, _RateMeta> _rateMeta = {};

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
    for (final rate in CurrencyRegistry().getAllRates()) {
      if (rate.code == 'XOF') continue;
      _currentRates[rate.code] = rate.rateToXof;
      _rateMeta[rate.code] =
          _RateMeta(origin: FxRateOrigin.registry, asOf: rate.lastUpdate);
    }
    MarketDataImportStore.instance.snapshotNotifier.addListener(_onDataChanged);
    // Analyse immédiate des données DÉJÀ présentes dans le snapshot (sans
    // setState : on est dans initState, le premier build suivra).
    _analysisResult = _computeAnalysis();
    // Restauration des données persistées en arrière-plan : best-effort. Le
    // rendu ne dépend QUE du snapshot courant (cf. `_runAnalysis` rebranché sur
    // le listener), donc si ce future ne se complète jamais — typiquement en
    // test widget, où l'I/O fichier de `initialized` n'est pas pompée — l'écran
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
      return _service.analyzePortfolio(
        records: records,
        analysisDate: DateTime.now(),
        exchangeRates: _currentRates,
      );
    } catch (_) {
      return _emptyFxRiskAnalysisResult();
    }
  }

  void _runAnalysis() {
    final result = _computeAnalysis();
    if (mounted) setState(() => _analysisResult = result);
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
          const SizedBox(height: 4),
          // Titre de section + barre des taux courants éditables sur la même
          // ligne (les taux ne sont affichés que s'il y a une exposition en
          // devise étrangère à valoriser).
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Titres exposés au risque de change',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A237E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      _FxInfoButton(result: _analysisResult),
                    ],
                  ),
                ),
                if (hasExposure) ...[
                  const SizedBox(width: 3),
                  _FxRatesBar(
                    rates: _currentRates,
                    meta: _rateMeta,
                    isFixedParity: _isFixedParity,
                    onEdit: _editRate,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 3),
          // Tableau — occupe toute la hauteur restante (scroll interne + pied
          // figé) au lieu d'une hauteur fixe qui paraissait coincée en bas.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 0,
                  AppTheme.pagePadding, AppTheme.pagePadding),
              child: showSpinner
                  ? const Center(child: CupertinoActivityIndicator())
                  : !hasExposure
                      ? _FxEmptyState(hasMarketData: _records.isNotEmpty)
                      : _FxContentSplit(result: _analysisResult),
            ),
          ),
        ],
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
/// de change — placé près du titre du tableau pour rendre les chiffres
/// (notamment les 0) compréhensibles.
class _FxInfoButton extends StatelessWidget {
  const _FxInfoButton({required this.result});

  final FxRiskAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _FxMethodologyDialog(result: result),
      ),
      child: Tooltip(
        message: 'Méthodologie et formules',
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Icon(CupertinoIcons.info_circle, size: 17, color: _fxPrimary),
        ),
      ),
    );
  }
}

/// Dialogue expliquant la méthodologie du risque de change : intuition,
/// formules prudentielles (BCEAO Art. 45) et valeurs courantes.
class _FxMethodologyDialog extends StatelessWidget {
  const _FxMethodologyDialog({required this.result});

  final FxRiskAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final textColor = _fxTextFor(context);
    final muted = _fxMutedFor(context);
    return AlertDialog(
      backgroundColor: _fxSurfaceFor(context),
      title: Row(
        children: [
          const Icon(CupertinoIcons.info_circle_fill,
              size: 18, color: _fxPrimary),
          const SizedBox(width: 2),
          Expanded(
            child: Text('Risque de change — méthodologie',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Le risque de change mesure l\'impact des variations de cours des '
                'devises sur les positions en devise étrangère.',
                style: TextStyle(fontSize: 12.5, color: textColor, height: 1.4),
              ),
              const SizedBox(height: 3),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _fxWarning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: _fxWarning.withValues(alpha: 0.30)),
                ),
                child: Text(
                  'La devise de référence (XOF) et l\'EUR — à parité fixe '
                  '(1 EUR = 655,957 FCFA) — ne portent aucun risque de change : '
                  'leurs lignes restent donc à 0.',
                  style: TextStyle(fontSize: 12, color: textColor, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),
              _section(context, 'Définitions'),
              _definition(context, 'Position longue',
                  'La banque détient la devise (actif) : elle gagne si la devise s\'apprécie face au XOF.'),
              _definition(context, 'Position courte',
                  'La banque doit / a vendu la devise (passif) : elle perd si la devise s\'apprécie.'),
              _definition(context, 'Position nette (par devise)',
                  'Positions longues − positions courtes d\'une même devise. Positive = nette longue ; négative = nette courte.'),
              _definition(context, 'Position nette globale',
                  'Sur l\'ensemble des devises : MAX(somme des nettes longues ; somme des nettes courtes). C\'est la base de l\'exigence de fonds propres.'),
              const SizedBox(height: 4),
              _section(context, 'Au niveau du portefeuille'),
              _formulaBlock(context, const [
                'Position nette / devise = Σ(longues) − Σ(courtes)   [en XOF]',
                'Position nette globale  = MAX( Σ longues ; Σ courtes )',
                'Exigence de fonds propres = Position nette globale × 8 %',
                'RWA Change = Exigence FP × 12,5',
              ]),
              const SizedBox(height: 3),
              _section(context, 'Par titre'),
              _formulaBlock(context, const [
                'Variation devise (%) =',
                '   (Taux courant − Taux acquisition) ÷ Taux acquisition × 100',
                'Gain/Perte de change =',
                '   Valeur actuelle (XOF) − Valeur d\'acquisition (XOF)',
              ]),
              const SizedBox(height: 4),
              _section(context, 'Valeurs actuelles'),
              _kv(context, 'Σ Positions longues',
                  '${formatLargeNumber(result.totalLongPositions)} XOF'),
              _kv(context, 'Σ Positions courtes',
                  '${formatLargeNumber(result.totalShortPositions)} XOF'),
              _kv(context, 'Position nette globale',
                  '${formatLargeNumber(result.globalNetPosition)} XOF'),
              _kv(context, 'Exigence de fonds propres',
                  '${formatLargeNumber(result.capitalRequirement)} XOF'),
              _kv(context, 'RWA Change',
                  '${formatLargeNumber(result.rwaChange)} XOF',
                  highlight: true),
              const SizedBox(height: 3),
              Text('Référence : BCEAO — Dispositif prudentiel, Art. 45.',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: muted)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: _fxPrimary)),
      );

  Widget _definition(BuildContext context, String term, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
                fontSize: 11.5, height: 1.35, color: _fxTextFor(context)),
            children: [
              TextSpan(
                  text: '$term : ',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(
                  text: desc, style: TextStyle(color: _fxMutedFor(context))),
            ],
          ),
        ),
      );

  Widget _formulaBlock(BuildContext context, List<String> lines) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _isFxDark(context)
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: _fxBorderFor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Text(l,
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      fontFamily: 'monospace',
                      color: _fxTextFor(context))),
          ],
        ),
      );

  Widget _kv(BuildContext context, String k, String v,
          {bool highlight = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Expanded(
              child: Text(k,
                  style: TextStyle(fontSize: 12, color: _fxMutedFor(context))),
            ),
            Text(v,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                    color: highlight ? _fxDanger : _fxTextFor(context))),
          ],
        ),
      );
}

class _FxEmptyState extends StatelessWidget {
  const _FxEmptyState({required this.hasMarketData});

  /// `true` : un portefeuille marché est importé mais ne contient AUCUN titre en
  /// devise étrangère (donc aucun risque de change). `false` : aucune donnée
  /// marché n'a encore été importée.
  final bool hasMarketData;

  @override
  Widget build(BuildContext context) {
    // Deux situations bien distinctes — il est important de ne pas les
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
/// Empile verticalement sur les fenêtres étroites.
class _FxContentSplit extends StatelessWidget {
  const _FxContentSplit({required this.result});

  final FxRiskAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final hasFx =
            (result.totalLongPositions - result.totalShortPositions).abs() >
                0.01;
        final table = _FxSecuritiesTable(securities: result.securities);
        final right = _FxRightPanel(result: result);
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

/// Graphique « Scénario de choc de change » : profil de gain/perte de change du
/// portefeuille selon une variation (choc) des devises étrangères vs XOF. Le
/// portefeuille n'étant sensible qu'à ses positions en devise étrangère, un
/// portefeuille 100 % XOF affiche un état « aucune sensibilité ».
class _FxShockChart extends StatefulWidget {
  const _FxShockChart({required this.result});

  final FxRiskAnalysisResult result;

  @override
  State<_FxShockChart> createState() => _FxShockChartState();
}

class _FxShockChartState extends State<_FxShockChart> {
  static const double _maxShock = 0.20; // ±20 %
  static const double _exampleNet = 1e9; // 1 Md XOF — position USD d'exemple
  bool _example = false;

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

  @override
  Widget build(BuildContext context) {
    final floatingNet = _floatingNet();
    final hasFx = floatingNet.abs() > 0.01;
    final showCurve = hasFx || _example;
    // Position nette (pour la courbe) ; en démo on simule une position longue.
    final effectiveNet = hasFx ? floatingNet : _exampleNet;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, size: 17, color: _fxPrimary),
              const SizedBox(width: 2),
              Expanded(
                child: Text('Profil de gain/perte - choc USD',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _fxTextFor(context))),
              ),
            ],
          ),
          if (showCurve) ...[
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              decoration: BoxDecoration(
                color: _fxPrimary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: _fxPrimary.withValues(alpha: 0.20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 15, color: _fxPrimary),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _interpretationWidget(context, effectiveNet),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 3),
          Expanded(
            child: showCurve
                ? TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: effectiveNet),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutQuart,
                    builder: (context, animatedNet, child) {
                      return CustomPaint(
                        painter: _FxShockPainter(
                          netSensitivity: animatedNet,
                          maxShock: _maxShock,
                          isDark: _isFxDark(context),
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  )
                : _buildEmpty(context),
          ),
        ],
      ),
    );
  }

  /// Encart d'interprétation : la base (position nette USD), puis les DEUX
  /// scénarios ±10 % sur des lignes distinctes (gain en vert, perte en rouge),
  /// et le sens de la position. Identique en données réelles (autres montants).
  Widget _interpretationWidget(BuildContext context, double net) {
    final long = net >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Position nette USD : ${_compact(net.abs())} XOF '
          '(${long ? 'longue' : 'courte'})',
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _fxMutedFor(context)),
        ),
        const SizedBox(height: 2),
        _scenarioLine(context, 'USD +10 %', net * 0.10),
        const SizedBox(height: 1),
        _scenarioLine(context, 'USD −10 %', net * -0.10),
        const SizedBox(height: 2),
        Text(
          'La banque ${long ? 'gagne' : 'perd'} quand le USD s\'apprécie.',
          style: TextStyle(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: _fxMutedFor(context)),
        ),
      ],
    );
  }

  /// Une ligne de scénario : flèche + libellé du choc + impact signé + (gain/perte).
  Widget _scenarioLine(BuildContext context, String scenario, double pnl) {
    final gain = pnl >= 0;
    final color = gain ? _fxSuccess : _fxDanger;
    return Row(
      children: [
        Icon(gain ? Icons.arrow_upward : Icons.arrow_downward,
            size: 13, color: color),
        const SizedBox(width: 2),
        SizedBox(
          width: 64,
          child: Text(scenario,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _fxTextFor(context))),
        ),
        Text('⇒  ',
            style: TextStyle(fontSize: 11, color: _fxMutedFor(context))),
        Text('${_signed(pnl)} XOF',
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 2),
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

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.checkmark_shield,
              size: 28, color: _fxSuccess.withValues(alpha: 0.7)),
          const SizedBox(height: 3),
          Text('Aucune sensibilité au change',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _fxTextFor(context))),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => setState(() => _example = true),
            icon: const Icon(CupertinoIcons.eye, size: 15),
            label: const Text('Voir démo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _fxPrimary,
              side: BorderSide(color: _fxPrimary.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Peintre du profil de choc : droite de P&L = sensibilité nette × choc, avec
/// aires gain (vert) / perte (rouge), grille, axes et points repères.
class _FxShockPainter extends CustomPainter {
  _FxShockPainter({
    required this.netSensitivity,
    required this.maxShock,
    required this.isDark,
  });

  final double netSensitivity;
  final double maxShock;
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
    if (yMax <= 0) return;

    final baseColor = isDark ? Colors.white : Colors.black;
    final gridPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final axisColor = baseColor.withValues(alpha: 0.40);

    double xFor(double shock) => cx + (shock / maxShock) * (plot.width / 2);
    double yFor(double pnl) => cy - (pnl / yMax) * (plot.height / 2);

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

    // Grille verticale + libellés X.
    for (final s in const [-0.20, -0.10, 0.0, 0.10, 0.20]) {
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
    final topL = label('+${_compact(yMax)}');
    topL.paint(canvas, Offset(plot.left - topL.width - 6, plot.top - 2));
    final zeroL = label('0');
    zeroL.paint(
        canvas, Offset(plot.left - zeroL.width - 6, cy - zeroL.height / 2));
    final botL = label('-${_compact(yMax)}');
    botL.paint(canvas,
        Offset(plot.left - botL.width - 6, plot.bottom - botL.height + 2));

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
    fillHalf(plot.right, yR);
    fillHalf(plot.left, yL);

    // Droite de P&L.
    canvas.drawLine(
        Offset(plot.left, yL),
        Offset(plot.right, yR),
        Paint()
          ..color = _fxPrimary
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);

    // Points repères.
    void dot(double shock, {bool current = false}) {
      final pnl = netSensitivity * shock;
      final p = Offset(xFor(shock), yFor(pnl));
      final c = current ? _fxPrimary : (pnl >= 0 ? _fxSuccess : _fxDanger);
      canvas.drawCircle(p, current ? 4.5 : 3.5, Paint()..color = c);
      canvas.drawCircle(
          p,
          current ? 4.5 : 3.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      if (!current) {
        final l = label('${pnl >= 0 ? '+' : ''}${_compact(pnl)}',
            bold: true, color: c);
        final dx = shock > 0 ? p.dx - l.width - 6 : p.dx + 6;
        l.paint(canvas, Offset(dx, p.dy - l.height - 2));
      }
    }

    dot(-0.10);
    dot(0.10);
    dot(0.0, current: true);
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
      old.isDark != isDark;
}

/// Colonne de droite : la répartition par devise (toujours affichée) et, quand
/// le portefeuille comporte des devises étrangères, le profil de choc en dessous.
class _FxRightPanel extends StatelessWidget {
  const _FxRightPanel({required this.result});

  final FxRiskAnalysisResult result;

  @override
  Widget build(BuildContext context) => _FxShockChart(result: result);
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
        padding: const EdgeInsets.fromLTRB(2, 1, 2, 1),
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
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: accent)),
            const SizedBox(width: 2),
            Text(formatDecimal(rate, 2),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: _fxTextFor(context))),
            const SizedBox(width: 1),
            Text('XOF',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: _fxMutedFor(context))),
            const SizedBox(width: 1),
            Icon(statusIcon,
                size: 11, color: accent.withValues(alpha: fixed ? 0.6 : 0.9)),
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

  String _buildCalculationTooltip(FxRiskAnalysisResult result) {
    return 'Détail du calcul prudentiel (BCEAO · Art. 45) :\n'
        '• Σ Positions longues : ${formatLargeNumber(result.totalLongPositions)} XOF (somme des positions nettes > 0)\n'
        '• Σ Positions courtes : ${formatLargeNumber(result.totalShortPositions)} XOF (somme des |positions nettes < 0|)\n'
        '• Position nette globale : ${formatLargeNumber(result.globalNetPosition)} XOF (MAX(longues ; courtes))\n'
        '• Exigence de fonds propres : ${formatLargeNumber(result.capitalRequirement)} XOF (position nette globale × 8 %)\n'
        '• RWA Change : ${formatLargeNumber(result.rwaChange)} XOF (exigence FP × 12,5)';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final itemsPerRow = w < 600
            ? 2
            : w < 1000
                ? 3
                : 5;

        final gain = result.globalFxGainLoss;
        final gainPercent = result.totalExposure > 0
            ? (gain / result.totalExposure) * 100
            : 0.0;

        final tooltip = _buildCalculationTooltip(result);

        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: itemsPerRow,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 56,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _FxKpiCard(
              icon: CupertinoIcons.money_dollar_circle_fill,
              label: 'Exposition Totale',
              value: formatLargeNumber(result.totalExposure),
              unit: 'FCFA',
              color: _fxPrimary,
            ),
            _FxKpiCard(
              icon: CupertinoIcons.chart_bar_alt_fill,
              label: 'Gain/Perte Global',
              value: formatLargeNumber(gain.abs()),
              unit: 'FCFA',
              color: gain >= 0 ? _fxSuccess : _fxDanger,
              isNegative: gain < 0,
              trend: gain.abs() < 0.01
                  ? null
                  : _FxTrend(
                      isPositive: gain >= 0,
                      label:
                          '${gain >= 0 ? '+' : '−'}${gainPercent.abs().toStringAsFixed(2)}%',
                    ),
            ),
            _FxKpiCard(
              icon: CupertinoIcons.shield_lefthalf_fill,
              label: 'Exigence FP Change',
              value: formatLargeNumber(result.capitalRequirement),
              unit: 'FCFA',
              color: _fxWarning,
              tooltipMessage: tooltip,
            ),
            _FxKpiCard(
              icon: CupertinoIcons.graph_circle_fill,
              label: 'RWA Change',
              value: formatLargeNumber(result.rwaChange),
              unit: 'FCFA',
              color: _fxDanger,
              tooltipMessage: tooltip,
            ),
            _FxKpiCard(
              icon: CupertinoIcons.chart_pie_fill,
              label: 'Contribution Risque Marché',
              value: result.marketRiskContribution.toStringAsFixed(1),
              unit: '%',
              color: _fxPrimary,
            ),
          ],
        );
      },
    );
  }
}

/// Indicateur de tendance affiché dans une puce sur la carte KPI.
class _FxTrend {
  const _FxTrend({required this.isPositive, required this.label});

  final bool isPositive;
  final String label;
}

/// Carte KPI moderne — badge dégradé, hiérarchie typographique soignée,
/// sous-titre contextuel, puce de tendance et effet de survol.
class _FxKpiCard extends StatefulWidget {
  const _FxKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.trend,
    this.isNegative = false,
    this.tooltipMessage,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final _FxTrend? trend;
  final bool isNegative;
  final String? tooltipMessage;

  @override
  State<_FxKpiCard> createState() => _FxKpiCardState();
}

class _FxKpiCardState extends State<_FxKpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = _isFxDark(context);
    final surface = _fxSurfaceFor(context);
    final color = widget.color;
    // Fond légèrement teinté par l'accent pour un rendu riche et premium.
    final tinted = Color.alphaBlend(
      color.withValues(alpha: isDark ? 0.10 : 0.045),
      surface,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [surface, tinted],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: _hovered ? 0.20 : 0.09),
              blurRadius: _hovered ? 22 : 13,
              offset: Offset(0, _hovered ? 10 : 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge d'icône en dégradé avec halo coloré.
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    Color.lerp(color, Colors.black, 0.22) ?? color,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.38),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.label.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: _fxMutedFor(context),
                                ),
                              ),
                            ),
                            if (widget.tooltipMessage != null) ...[
                              const SizedBox(width: 1),
                              Tooltip(
                                message: widget.tooltipMessage!,
                                preferBelow: false,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radius),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 2),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Icon(
                                  CupertinoIcons.info_circle,
                                  size: 11,
                                  color: _fxMutedFor(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.trend != null) ...[
                        const SizedBox(width: 2),
                        _FxTrendChip(trend: widget.trend!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          widget.isNegative ? '−${widget.value}' : widget.value,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: _fxTextFor(context),
                          ),
                        ),
                        const SizedBox(width: 1),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: Text(
                            widget.unit,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: _fxMutedFor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Puce de tendance (▲/▼) affichée en haut de carte.
class _FxTrendChip extends StatelessWidget {
  const _FxTrendChip({required this.trend});

  final _FxTrend trend;

  @override
  Widget build(BuildContext context) {
    final color = trend.isPositive ? _fxSuccess : _fxDanger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trend.isPositive
                ? CupertinoIcons.arrow_up_right
                : CupertinoIcons.arrow_down_right,
            size: 9,
            color: color,
          ),
          const SizedBox(width: 1),
          Text(
            trend.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tableau des titres exposés - colonnes TITRE et STATUT fixes
class _FxSecuritiesTable extends StatefulWidget {
  const _FxSecuritiesTable({required this.securities});

  final List<FxSecurityAnalysis> securities;

  @override
  State<_FxSecuritiesTable> createState() => _FxSecuritiesTableState();
}

class _FxSecuritiesTableState extends State<_FxSecuritiesTable> {
  // Défilement VERTICAL : une seule liste virtualisée (ListView.builder) pour
  // tout le corps. Chaque ligne est UN widget unique qui contient à la fois la
  // colonne gauche figée, le milieu et la colonne droite figée ; comme tout
  // partage l'unique position de défilement vertical, les colonnes figées ne
  // peuvent JAMAIS dériver par rapport au milieu — l'alignement est garanti par
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
  // empêchait la file de microtâches de se vider — `pumpAndSettle` ne
  // convergeait jamais (timeout) et le défilement saccadait en production.
  final ScrollController _midHSC = ScrollController();

  int? _selectedIndex;
  static const Color _selColor = Color(0xFFE3F2FD);

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
    final securities = widget.securities;

    const rowH = 40.0;
    final headerTextLight = TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: _fxPrimary.withValues(alpha: 0.9),
        letterSpacing: 0.5);
    final cellText = TextStyle(
        fontSize: 11, color: _fxTextFor(context), fontWeight: FontWeight.w500);

    return LayoutBuilder(builder: (context, constraints) {
      // Largeurs naturelles des colonnes.
      const naturalColW = <int, double>{
        0: 180, // ÉMETTEUR (Left fixed)
        1: 80, // DEVISE
        2: 190, // VALEUR NOMINALE (XOF)
        3: 140, // VARIATION DEVISE (%)
        4: 120, // GAIN/PERTE (%)
        5: 120, // POSITION
        6: 150, // RWA (XOF)
        7: 160, // GAIN/PERTE DE CHANGE (Right fixed)
      };
      const naturalMiddle = 80 + 190 + 140 + 120 + 120 + 150; // 800
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
      final middleWidth =
          colW[1]! + colW[2]! + colW[3]! + colW[4]! + colW[5]! + colW[6]!;
      // build header cells for scrollable middle (cols 1-6), sized with colW
      final headerMiddle = Row(children: [
        SizedBox(
            width: colW[1]!,
            child: _HCell('DEVISE', TextAlign.left, headerTextLight)),
        SizedBox(
            width: colW[2]!,
            child: _HCell(
                'VALEUR NOMINALE (XOF)', TextAlign.right, headerTextLight)),
        SizedBox(
            width: colW[3]!,
            child: _HCell(
                'VARIATION DEVISE (%)', TextAlign.right, headerTextLight)),
        SizedBox(
            width: colW[4]!,
            child: _HCell('GAIN/PERTE (%)', TextAlign.right, headerTextLight)),
        SizedBox(
            width: colW[5]!,
            child: _HCell('POSITION', TextAlign.center, headerTextLight)),
        SizedBox(
            width: colW[6]!,
            child: _HCell('RWA (XOF)', TextAlign.right, headerTextLight)),
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
                  decoration: BoxDecoration(
                    color: _fxPrimary.withValues(alpha: 0.05),
                    border: Border(
                        bottom: BorderSide(
                            color: _fxPrimary.withValues(alpha: 0.15))),
                  ),
                  child: Row(children: [
                    SizedBox(
                        width: colW[0]!,
                        child: _HCell(
                            'ÉMETTEUR', TextAlign.left, headerTextLight)),
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
                    SizedBox(
                        width: colW[7]!,
                        child: _HCell('GAIN/PERTE DE CHANGE', TextAlign.right,
                            headerTextLight)),
                  ]),
                ),
                // Body — liste verticale unique et VIRTUALISÉE. Chaque ligne
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
                        child: ListView.builder(
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
                                for (int j = 0; j < middleWidths.length; j++)
                                  SizedBox(
                                      width: middleWidths[j],
                                      child: cells[1 + j]),
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
                              onTap: () => setState(() => _selectedIndex =
                                  _selectedIndex == i ? null : i),
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
              ]);
            },
          ),
        ),
      );
    });
  }

  /// Construit les 8 cellules d'une ligne (cols 0..7). Le fond (zébrage /
  /// sélection) est porté par la ligne elle-même (_FxSecurityRow), les cellules
  /// restent donc transparentes.
  List<Widget> _buildDataCells(
      FxSecurityAnalysis s, int index, TextStyle baseStyle) {
    return [
      _DCell(s.titleName, baseStyle),
      _DCell(s.currency,
          baseStyle.copyWith(fontWeight: FontWeight.w600, color: _fxPrimary),
          chip: _fxPrimary.withValues(alpha: 0.08)),
      _DCell(formatLargeNumber(s.currentValueInXof), baseStyle,
          align: TextAlign.right),
      _DCell(
          '${s.currencyVariationPercent >= 0 ? '+' : ''}${formatDecimal(s.currencyVariationPercent, 2)}%',
          baseStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: s.currencyVariationPercent >= 0 ? _fxSuccess : _fxDanger),
          align: TextAlign.right),
      _DCell(
          '${s.fxGainLossPercent >= 0 ? '+' : ''}${formatDecimal(s.fxGainLossPercent, 2)}%',
          baseStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: s.fxGainLossPercent.abs() < 0.001
                  ? _fxTextFor(context)
                  : (s.fxGainLossPercent > 0 ? _fxSuccess : _fxDanger)),
          align: TextAlign.right),
      _DCell(
          s.positionLabel,
          baseStyle.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: s.positionType == FxPositionType.long
                  ? _fxSuccess
                  : (s.positionType == FxPositionType.short
                      ? _fxDanger
                      : _fxMutedFor(context))),
          align: TextAlign.center,
          chip: s.positionType == FxPositionType.long
              ? _fxSuccess.withValues(alpha: 0.1)
              : (s.positionType == FxPositionType.short
                  ? _fxDanger.withValues(alpha: 0.1)
                  : _fxBorderFor(context))),
      _DCell(formatLargeNumber(s.rwa),
          baseStyle.copyWith(fontWeight: FontWeight.w600),
          align: TextAlign.right),
      _DCell(
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
/// par le parent via [Transform.translate]) · colonne droite figée — le tout
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
            Expanded(child: middle),
            SizedBox(width: rightWidth, child: rightCell),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets internes ───

/// Ligne d'entête (pas d'ellipsis, tout doit être visible)
/// Convertit un [TextAlign] horizontal en [Alignment] de cellule.
Alignment _cellAlignment(TextAlign align) => switch (align) {
      TextAlign.right => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    };

Widget _HCell(String text, TextAlign align, TextStyle style) => Container(
      height: 40,
      alignment: _cellAlignment(align),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(text, style: style, textAlign: align, maxLines: 1),
    );

/// Ligne de donnée
Widget _DCell(String text, TextStyle style,
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
