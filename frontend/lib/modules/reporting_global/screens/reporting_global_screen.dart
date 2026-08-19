// Écran de génération du rapport global - synthèse consolidée du Dashboard,
// du Risque Crédit, du Risque de Marché et du Risque Opérationnel dans un
// même document PDF réglementaire (UMOA/BCEAO).
import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../expositions/models/exposition_models.dart';
import '../../rapports/screens/fodep_page.dart';
import '../../risque_marche/repositories/foreign_exchange_repository.dart';
import '../../risque_marche/services/market_data_import_store.dart';
import '../../risque_marche/services/market_risk_aggregation_service.dart';
import '../../risque_operationnel/models/ro_models.dart';

// ─── Constantes couleur ───────────────────────────────────────────────────
// Dupliquées depuis risque_operationnel_screen.dart (constantes privées à ce
// fichier là-bas, sans lien de dépendance entre les deux modules).
const _kBlue = AppTheme.sidebar;
const _kSuccess = AppTheme.success;
const _kDanger = AppTheme.danger;
const _kMuted = AppTheme.muted;

// ─── Articles réglementaires ──────────────────────────────────────────────
// Dupliqué depuis risque_operationnel_screen.dart pour les mêmes raisons.
const _artExplanations = <String, String>{
  'Art. 313':
      'Gestion du risque opérationnel : dispositif d\'identification, de mesure,\n'
          'de surveillance et de contrôle obligatoire (Instruction UMOA).\n\n'
          'Mesure du risque (matrice 5×5) :\n'
          '  Score = Impact × Probabilité   (échelle 1 à 5)\n'
          '  Zone rouge : Score ≥ 15   |   Zone orange : 8 à 14\n'
          '  Piliers : Identification → Mesure → Surveillance → Contrôle',
  'Art. 313.b':
      'Déclaration des incidents opérationnels : tout incident significatif\n'
          'doit être documenté (cause racine, pertes) avec suivi formel imposé.\n\n'
          'Calcul de la perte nette :\n'
          '  Perte nette = Perte brute − Récupérations\n'
          '  Récupérations : assurance + provisions + reversements\n'
          '  Délai de déclaration : ≤ J+5 ouvrés après détection',
  'Art. 313.c':
      'Plans d\'actions correctives et préventives : documentés, assignés\n'
          'à un responsable avec échéance et taux d\'avancement obligatoires.\n\n'
          'Indicateurs de suivi :\n'
          '  Avancement (%) = (Actions terminées / Actions totales) × 100\n'
          '  Taux global = Σ avancement_i / n   (n = nb plans actifs)\n'
          '  Retard = Date_échéance − Date_aujourd\'hui  < 0 → en retard',
  'Art. 314': 'Contrôle interne : dispositif permanent et périodique obligatoire.\n'
      'Conservation des documents : ≥ 7 ans (exigence UMOA).\n\n'
      'Efficacité du contrôle :\n'
      '  Taux de conformité = (Contrôles conformes / Contrôles réalisés) × 100\n'
      '  Couverture = Nb processus contrôlés / Nb processus totaux × 100\n'
      '  Fréquences : permanent (quotidien/hebdo) | périodique (mensuel/annuel)',
  'Art. 89':
      'Calcul des RWA opérationnels : méthode Indicateur de Base (BIA).\n\n'
          'Formule BIA :\n'
          '  Capital minimal = α × PNBmoy₃\n'
          '  α = 15 %   (coefficient réglementaire BCEAO)\n'
          '  PNBmoy₃ = Σ PNBᵢ (positifs) / n   sur 3 derniers exercices\n'
          '  RWA_opérationnel = Capital minimal × 12,5   (multiplicateur réglementaire)',
  'Art. 301/307':
      'Exigences minimales en fonds propres (dispositif prudentiel BCEAO).\n\n'
          'Ratios réglementaires :\n'
          '  Ratio Tier 1 = Fonds propres de catégorie 1 / RWA total  ≥ 6 %\n'
          '  Ratio global = Fonds propres totaux / RWA total   ≥ 9 %\n'
          '  RWA total = RWA_crédit + RWA_marché + RWA_opérationnel\n'
          '  Coussin de conservation : + 2,5 % des RWA (si applicable)',
  'Art. 545': 'Stress testing : simulations de scénarios de crise pour évaluer\n'
      'la résilience du dispositif de gestion des risques.\n\n'
      'Scénarios types et formule d\'impact :\n'
      '  S1 : Optimiste  |  S2 : Neutre  |  S3 : Pessimiste  |  S4 : Crise\n'
      '  Impact net = Pertes simulées − (Provisions + Couverture assurance)\n'
      '  Résilience = Fonds propres disponibles − Pertes simulées  ≥ 0\n'
      '  Ratio de résistance = FP après choc / RWA stressés  ≥ seuil',
  'Art. 546': 'Rapport annuel sur le dispositif de gestion des risques,\n'
      'transmis à la Commission Bancaire de l\'UMOA.\n\n'
      'Indicateurs clés à reporter :\n'
      '  • RWA total = RWA_crédit + RWA_marché + RWA_opérationnel\n'
      '  • Ratios réglementaires (CET1, Tier 1, solvabilité, levier)\n'
      '  • Pertes totales nettes = Σ (Perte brute − Récupérations)\n'
      '  • Résultats stress tests : ΔFP sous S3 et S4',
};

Widget _artInfo(String artRef) {
  final explanation = _artExplanations[artRef];
  if (explanation == null) return const SizedBox.shrink();
  return ExcludeSemantics(
    child: Tooltip(
      excludeFromSemantics: true,
      message: '$artRef\n$explanation',
      preferBelow: false,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 8),
      textStyle:
          const TextStyle(fontSize: 11.5, color: Colors.white, height: 1.6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Icon(Icons.info_outline_rounded, size: 14, color: _kBlue),
    ),
  );
}

Widget _dropdown<T>(BuildContext context, String label, T? value, List<T> items,
    void Function(T?) onChanged,
    {bool required = false, IconData? icon, String? hint}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final borderColor = isDark ? AppTheme.darkBorder : AppTheme.border;
  final fillColor = isDark ? AppTheme.darkCard : const Color(0xFFFBFCFF);
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTheme.radius),
    borderSide: BorderSide(color: borderColor),
  );

  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _kBlue),
            const SizedBox(width: 5)
          ],
          Text(required ? '$label *' : label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _kMuted,
                  letterSpacing: 0.1)),
        ]),
        const SizedBox(height: 5),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.toString(),
                        style: const TextStyle(fontSize: 13.5),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
            filled: true,
            fillColor: fillColor,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: outline,
            enabledBorder: outline,
            focusedBorder: outline.copyWith(
              borderSide: const BorderSide(color: _kBlue, width: 1.1),
            ),
          ),
          validator: required ? (v) => v == null ? 'Champ requis' : null : null,
        ),
      ],
    ),
  );
}

/// Lit la valeur d'une métrique du dashboard par sa clé, 0 si absente.
double _metricValue(List<DashboardMetric> metrics, String key) {
  for (final m in metrics) {
    if (m.key == key) return m.value;
  }
  return 0.0;
}

String _formatAmountForPreview(BuildContext context, double amount,
    {int maxDecimals = 1}) {
  final displayCurrency =
      PortfolioCurrencyScope.maybeOf(context, fallback: 'XOF');
  final amountUnit = PortfolioAmountUnitScope.maybeOf(context);
  return formatCurrencyInDisplayUnit(
    amount,
    fromCurrency: 'XOF',
    toCurrency: displayCurrency,
    amountUnit: amountUnit,
    maxDecimals: maxDecimals,
  );
}

// ─── Ecran ─────────────────────────────────────────────────────────────────

class ReportingGlobalScreen extends StatefulWidget {
  const ReportingGlobalScreen({super.key, required this.api});
  final RwaApiService api;
  @override
  State<ReportingGlobalScreen> createState() => _ReportingGlobalScreenState();
}

class _ReportingGlobalScreenState extends State<ReportingGlobalScreen> {
  String _periode = 'Mensuel';
  String _destinataire = 'Organe exécutif';
  bool _generating = false;
  String? _savedFileName;
  // Confirmation temporaire (grande, au centre) affichée juste après la
  // génération, puis qui disparaît toute seule - remplace le bandeau vert
  // plein écran et le petit badge permanent qui ne plaisaient pas.
  bool _showSuccessToast = false;
  Timer? _successTimer;
  // Source de vérité unique pour les dates du rapport : tout le reste
  // (champs affichés, bouton "Générer", en-tête du PDF) dérive de ces deux
  // DateTime et du même formateur _fmtDate, pour garantir que les dates
  // affichées correspondent partout, y compris après une modification.
  DateTime? _dateDebut;
  DateTime? _dateFin;
  final _dateDebutCtrl = TextEditingController();
  final _dateFinCtrl = TextEditingController();

  // ─── Aperçu de l'export (données réellement injectées dans le PDF) ────────
  DashboardSnapshot? _previewDash;
  RoDashboardData? _previewRo;
  bool _previewLoading = true;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _applyQuickPeriod('Mensuel');
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });
    try {
      final results = await Future.wait([
        widget.api.fetchDashboard(),
        widget.api.fetchRoDashboard(),
      ]);
      if (!mounted) return;
      setState(() {
        _previewDash = results[0] as DashboardSnapshot;
        _previewRo = results[1] as RoDashboardData;
        _previewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewError = '$e';
        _previewLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _dateDebutCtrl.dispose();
    _dateFinCtrl.dispose();
    _successTimer?.cancel();
    super.dispose();
  }

  void _applyQuickPeriod(String periode) {
    final now = DateTime.now();
    final DateTime debut;
    switch (periode) {
      case 'Trimestriel':
        final q = ((now.month - 1) ~/ 3) * 3 + 1;
        debut = DateTime(now.year, q, 1);
      case 'Semestriel':
        debut = DateTime(now.year, now.month <= 6 ? 1 : 7, 1);
      case 'Annuel':
        debut = DateTime(now.year, 1, 1);
      default:
        debut = DateTime(now.year, now.month, 1);
    }
    setState(() {
      _periode = periode;
      _dateDebut = debut;
      _dateFin = now;
      _dateDebutCtrl.text = _fmtDate(debut);
      _dateFinCtrl.text = _fmtDate(now);
    });
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String get _periodeLabel {
    final d = _dateDebut;
    final f = _dateFin;
    if (d != null && f != null) return '${_fmtDate(d)} - ${_fmtDate(f)}';
    return _periode;
  }

  // ─── Risque de Marché : accès direct aux singletons du module, sans passer
  // par RisqueMarcheScreen (mêmes sources que l'écran Risque de Marché,
  // voir risque_marche_screen.dart:30398-30417) ─────────────────────────────

  Future<MarketPrudentialCapitalResult> _computeMarketResult() async {
    await MarketDataImportStore.instance.initialized;
    await InMemoryForeignExchangeRepository().initialized;
    final snapshot = MarketDataImportStore.instance.snapshotNotifier.value;
    final records = [
      ...?snapshot.datasetFor(MarketPortfolioType.bonds)?.records,
      ...?snapshot.datasetFor(MarketPortfolioType.equities)?.records,
    ];
    final fxPositions = InMemoryForeignExchangeRepository().currentPositions;
    final base = calculateMarketPrudentialCapital(records: records);
    return applyRealForeignExchangeRisk(base, fxPositions);
  }

  // ─── Génération + dialog de sauvegarde ──────────────────────────────────────

  Future<void> _generateAndSave() async {
    setState(() {
      _generating = true;
      _savedFileName = null;
    });
    try {
      // 1. Récupérer les données de tous les domaines en parallèle
      final results = await Future.wait([
        widget.api.fetchRoDashboard(),
        widget.api.fetchRoIncidents(),
        widget.api.fetchRoKri(),
        widget.api.fetchRoRisques(),
        widget.api.fetchRoControles(),
        widget.api.fetchRoPlans(),
        widget.api.fetchDashboard(),
        widget.api.fetchExpositionsModule(),
        _computeMarketResult(),
      ]);
      final dash = results[0] as RoDashboardData;
      final kriData = results[2] as RoKriModuleData;
      final risques = results[3] as List<RoRisque>;
      final controles = results[4] as List<RoControle>;
      final plans = results[5] as List<RoPlan>;
      final globalDash = results[6] as DashboardSnapshot;
      final creditSummary = (results[7] as ExposureModuleData).summary;
      final marketResult = results[8] as MarketPrudentialCapitalResult;

      final debut = _dateDebut;
      final fin = _dateFin;
      final incidents = (results[1] as List<RoIncident>).where((i) {
        try {
          final d = DateTime.parse(i.dateOccurrence);
          if (debut != null && d.isBefore(debut)) return false;
          if (fin != null && d.isAfter(fin.add(const Duration(days: 1)))) {
            return false;
          }
          return true;
        } catch (_) {
          return true;
        }
      }).toList();

      if (!mounted) return;

      // 2. Construire le PDF
      final now = DateTime.now();
      final bytes = await _buildPdf(
        dash,
        incidents,
        kriData.kriList,
        risques,
        controles,
        plans,
        globalDash,
        creditSummary,
        marketResult,
        now,
      );

      if (!mounted) return;

      // 3. Dialog de sauvegarde natif Windows
      final ts =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final nomPropose = 'rapport_global_${_periode.toLowerCase()}_$ts.pdf';
      final location = await getSaveLocation(
        suggestedName: nomPropose,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf'])
        ],
      );
      if (!mounted || location == null) return;

      // 4. Enregistrer
      final saved = await saveBytesAtLocation(
        location,
        bytes,
        requiredExtension: '.pdf',
        suggestedName: nomPropose,
      );
      if (!mounted) return;

      final fileName = saved.path.split(RegExp(r'[\\/]')).last;
      setState(() {
        _savedFileName = fileName;
        _showSuccessToast = true;
      });
      _successTimer?.cancel();
      _successTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showSuccessToast = false);
      });
    } on FichierVerrouilleException catch (e) {
      // Même écueil que pour le FODEP : le rapport précédent est resté ouvert
      // dans le lecteur PDF, qui en interdit la réécriture.
      _signalerErreur(e.message);
    } catch (e) {
      _signalerErreur('Erreur : $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Affiche une erreur d'export, assez longtemps pour être lue et agie.
  void _signalerErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _kDanger,
      duration: const Duration(seconds: 8),
      content: Text(message),
    ));
  }

  // ─── Construction du document PDF ───────────────────────────────────────────

  Future<Uint8List> _buildPdf(
    RoDashboardData dash,
    List<RoIncident> incidents,
    List<RoKriView> kris,
    List<RoRisque> risques,
    List<RoControle> controles,
    List<RoPlan> plans,
    DashboardSnapshot globalDash,
    ExposureSummary creditSummary,
    MarketPrudentialCapitalResult marketResult,
    DateTime now,
  ) async {
    final doc = pw.Document();
    const headerBg = PdfColor.fromInt(0xFF0F2544);
    const accentBg = PdfColor.fromInt(0xFF2563EB);
    const borderCol = PdfColor.fromInt(0xFFE5E7EB);
    const mutedCol = PdfColor.fromInt(0xFF6B7280);

    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    // La police de base utilisée par le PDF ne sait pas afficher le tiret
    // cadratin « - » (il ressort comme un carré/tofu) - on le remplace par
    // un tiret simple partout dans le texte injecté dans le document.
    final periodePdf = _periodeLabel.replaceAll('-', '-');

    const mutedStyle = pw.TextStyle(fontSize: 8.5, color: mutedCol);
    const bodyStyle = pw.TextStyle(fontSize: 9);
    final headerStyle = pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);

    pw.Widget sectionBanner(String text) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(
              color: headerBg, borderRadius: pw.BorderRadius.circular(3)),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
        );

    pw.Widget kpiGrid(List<(String label, String value)> items) => pw.Row(
          children: items
              .map((item) => pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 6, bottom: 6),
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderCol),
                          borderRadius: pw.BorderRadius.circular(4)),
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.$1, style: mutedStyle),
                            pw.SizedBox(height: 3),
                            pw.Text(item.$2,
                                style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: headerBg)),
                          ]),
                    ),
                  ))
              .toList(),
        );

    pw.Widget table(List<String> headers, List<List<String>> rows) =>
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: headerStyle,
          headerDecoration: const pw.BoxDecoration(color: accentBg),
          cellStyle: bodyStyle,
          border: pw.TableBorder.all(color: borderCol, width: 0.4),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        );

    // Décomposition du capital requis marché - taux / actions / change (FX).
    // Conversion en équivalent RWA : multiplicateur réglementaire de 12,5
    // (assiette du ratio de solvabilité du dispositif prudentiel UMOA).
    const reaMultiplier = 12.5;
    final marketTotal = marketResult.capitalRequirement;
    String marketShare(double component) => marketTotal > 0
        ? '${(component / marketTotal * 100).toStringAsFixed(1)} %'
        : '0,0 %';

    // Montants arrondis et compacts (ex. "913,5 Md FCFA" au lieu de
    // "913 540 920 410 FCFA"), même unité (M/Md) que celle choisie par
    // l'utilisateur ailleurs dans l'app (PortfolioAmountUnitPreference).
    String amt(double v) => formatCurrencyCompact(v, toCurrency: 'XOF');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Rapport Risque Global -- $periodePdf',
                  style: mutedStyle),
              pw.Text('$_destinataire  ·  $dateStr', style: mutedStyle),
            ]),
      ),
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Confidentiel -- Usage interne', style: mutedStyle),
              pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: mutedStyle),
            ]),
      ),
      build: (_) => [
        // ── COUVERTURE ────────────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(22),
          decoration: pw.BoxDecoration(
              color: headerBg, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RAPPORT DE RISQUE GLOBAL',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.SizedBox(height: 6),
                pw.Text(
                    'Période : $periodePdf  ·  Destinataire : $_destinataire',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey300)),
                pw.Text('Date de génération : $dateStr',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey300)),
                pw.SizedBox(height: 4),
                pw.Text(
                    'Art. 301/307, 313, 313.b, 313.c, 314, 545, 546 -- UMOA/BCEAO',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey400)),
              ]),
        ),
        pw.SizedBox(height: 16),

        // ── 1. SYNTHÈSE GLOBALE ──────────────────────────────────────────────
        sectionBanner('1. SYNTHÈSE GLOBALE  '),
        kpiGrid([
          ('RWA Total', amt(_metricValue(globalDash.metrics, 'rwa'))),
          ('RWA Crédit', amt(_metricValue(globalDash.metrics, 'rwa_credit'))),
          ('RWA Marché', amt(_metricValue(globalDash.metrics, 'rwa_market'))),
          ('RWA Opérationnel', amt(_metricValue(globalDash.metrics, 'rwa_op'))),
          (
            'Capital Total (FPE)',
            amt(_metricValue(globalDash.metrics, 'capital'))
          ),
        ]),
        kpiGrid([
          (
            'Ratio CET1',
            AppFormatters.percent(
                _metricValue(globalDash.metrics, 'cet1_ratio'))
          ),
          (
            'Ratio Tier 1',
            AppFormatters.percent(
                _metricValue(globalDash.metrics, 'tier1_ratio'))
          ),
          (
            'Ratio de solvabilité',
            AppFormatters.percent(
                _metricValue(globalDash.metrics, 'solvabilite'))
          ),
          (
            'Ratio de levier',
            AppFormatters.percent(
                _metricValue(globalDash.metrics, 'ratio_levier'))
          ),
        ]),
        pw.SizedBox(height: 6),

        // ── 2. RISQUE CRÉDIT ─────────────────────────────────────────────────
        // Note : ExposureSummary.totalExpositions est en réalité le total de
        // l'exposition brute (montant, pas un décompte) - voir
        // expositions_screen.dart::_summarize et expositions/services.py::
        // get_exposition_summary. Le vrai nombre de lignes vient du portefeuille
        // complet du dashboard (globalDash.portfolioOverview), comme sur l'écran
        // Vue d'ensemble (DashboardTopMetricsGrid::exposuresCount).
        sectionBanner('2. RISQUE CRÉDIT  '),
        kpiGrid([
          (
            'Nombre d\'expositions',
            (globalDash.portfolioOverview.length).toString()
          ),
          ('EAD total', amt(creditSummary.totalEad)),
          ('RWA Crédit', amt(creditSummary.totalRwa)),
          ('Capital requis', amt(creditSummary.totalCapital)),
        ]),
        pw.SizedBox(height: 12),

        // ── 3. RISQUE DE MARCHÉ ──────────────────────────────────────────────
        sectionBanner('3. RISQUE DE MARCHÉ  '),
        kpiGrid([
          ('RWA Marché', amt(marketResult.marketRwa)),
          ('Capital requis marché', amt(marketResult.capitalRequirement)),
        ]),
        pw.SizedBox(height: 6),
        table(
          ['Composante', 'Capital requis', 'RWA', '% du total'],
          [
            [
              'Taux d\'intérêt',
              amt(marketResult.interestRateRisk),
              amt(marketResult.interestRateRisk * reaMultiplier),
              marketShare(marketResult.interestRateRisk),
            ],
            [
              'Actions',
              amt(marketResult.equityRisk),
              amt(marketResult.equityRisk * reaMultiplier),
              marketShare(marketResult.equityRisk),
            ],
            [
              'Change (FX)',
              amt(marketResult.foreignExchangeRisk),
              amt(marketResult.foreignExchangeRisk * reaMultiplier),
              marketShare(marketResult.foreignExchangeRisk),
            ],
            [
              'Total',
              amt(marketResult.capitalRequirement),
              amt(marketResult.marketRwa),
              '100,0 %',
            ],
          ],
        ),
        pw.SizedBox(height: 12),

        // ── 4. SYNTHÈSE GÉNÉRALE - RISQUE OPÉRATIONNEL ───────────────────────
        sectionBanner('4. SYNTHÈSE GÉNÉRALE - RISQUE OPÉRATIONNEL  '),
        kpiGrid([
          (
            'Exigence fonds propres (K)',
            amt(dash.widget1.exigenceFondsPropres)
          ),
          ('RWA risque opérationnel', amt(dash.widget1.aprRisqueOp)),
          ('Statut réglementaire', dash.widget1.statutReglementaire),
          ('Incidents (mois)', '${dash.widget2.totalIncidentsMois}'),
          ('Non clôturés', '${dash.widget2.incidentsNonClos}'),
          ('Actions en retard', '${dash.widget3.actionsEnRetard}'),
        ]),
        pw.SizedBox(height: 12),

        // ── 5. INCIDENTS ET PERTES ───────────────────────────────────────────
        sectionBanner('5. INCIDENTS ET PERTES  '),
        kpiGrid([
          (
            'Pertes brutes totales',
            amt(incidents.fold(0.0, (s, i) => s + i.perteBrute))
          ),
          (
            'Pertes nettes totales',
            amt(incidents.fold(0.0, (s, i) => s + i.perteNette))
          ),
          (
            'Incidents significatifs',
            '${incidents.where((i) => i.significatif).length}'
          ),
        ]),
        pw.SizedBox(height: 6),
        if (incidents.isEmpty)
          pw.Text('Aucun incident enregistré.', style: mutedStyle)
        else ...[
          table(
            [
              'Référence',
              'Date',
              'Ligne métier',
              'Perte brute',
              'Perte nette',
              'Statut'
            ],
            incidents
                .take(15)
                .map((i) => [
                      i.reference,
                      i.dateOccurrence,
                      i.ligneMetier,
                      amt(i.perteBrute),
                      amt(i.perteNette),
                      i.statut,
                    ])
                .toList(),
          ),
          if (incidents.length > 15)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                  '... et ${incidents.length - 15} autres incidents.',
                  style: mutedStyle),
            ),
        ],
        pw.SizedBox(height: 12),

        // ── 6. CONTRÔLES INTERNES ────────────────────────────────────────────
        sectionBanner('6. CONTRÔLES INTERNES  '),
        if (controles.isNotEmpty)
          kpiGrid([
            ('Total contrôles', '${controles.length}'),
            (
              'Non conformes',
              '${controles.where((c) => c.resultat == 'Non-conforme').length}'
            ),
            (
              'Taux moyen',
              '${(controles.fold(0.0, (s, c) => s + c.tauxConformite) / controles.length).toStringAsFixed(1)} %'
            ),
          ])
        else
          pw.Text('Aucun contrôle enregistré.', style: mutedStyle),
        pw.SizedBox(height: 12),

        // ── 7. PLANS D'ACTIONS ───────────────────────────────────────────────
        sectionBanner('7. PLANS D\'ACTIONS  '),
        if (plans.isNotEmpty)
          kpiGrid([
            ('Plans total', '${plans.length}'),
            ('En retard', '${plans.where((p) => p.enRetard).length}'),
            (
              'Réalisation moy.',
              '${(plans.fold(0.0, (s, p) => s + p.avancement) / plans.length).toStringAsFixed(0)} %'
            ),
          ])
        else
          pw.Text('Aucun plan d\'action enregistré.', style: mutedStyle),
        pw.SizedBox(height: 16),

        // ── PIED ─────────────────────────────────────────────────────────────
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Text(
          'Rapport fait le $dateStr -- Outil RWA -- Confidentiel',
          style: mutedStyle,
          textAlign: pw.TextAlign.center,
        ),
      ],
    ));

    return doc.save();
  }

  // ─── Interface ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildScreenContent(context),
        _buildSuccessToastOverlay(context),
      ],
    );
  }

  /// Grande confirmation temporaire, centrée en haut de l'écran, qui apparaît
  /// après la génération puis disparaît toute seule après quelques secondes
  /// (voir _generateAndSave / _successTimer) - remplace le bandeau vert et le
  /// petit badge permanent qui ne convenaient pas.
  Widget _buildSuccessToastOverlay(BuildContext context) {
    return Positioned(
      top: 24,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            offset: _showSuccessToast ? Offset.zero : const Offset(0, -0.4),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              opacity: _showSuccessToast ? 1 : 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0F2544)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8)),
                  ],
                  border: Border.all(
                      color: _kSuccess.withValues(alpha: 0.3), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: _showSuccessToast
                          ? Lottie.asset('assets/lotties/Success.json',
                              repeat: false, fit: BoxFit.contain)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rapport enregistré',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _kSuccess)),
                          if (_savedFileName != null) ...[
                            const SizedBox(height: 2),
                            Text(_savedFileName!,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: _kMuted,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ouvre la page de la déclaration prudentielle : cases à renseigner et
  /// export du formulaire.
  ///
  /// Au retour, l'aperçu est rechargé si des cases ont été renseignées : elles
  /// changent ce que l'export contiendra, et l'écran mentirait en montrant
  /// l'état d'avant.
  Future<void> _ouvrirLeFodep() async {
    // La date de fin voyage avec : l'attestation la porte sans qu'on la
    // saisisse, et la page doit montrer laquelle sera déclarée.
    final modifie = await FodepPage.ouvrir(
      context,
      widget.api,
      dateArrete: _dateFin,
    );
    if (modifie && mounted) _loadPreview();
  }

  Widget _buildScreenContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Reporting global',
            subtitle:
                'Génération du rapport consolidé : Dashboard, Crédit, Marché, Opérationnel',
            titleFontSize: 26,
            subtitleFontSize: 12.5,
            // Les cases à renseigner ont rejoint la page de la déclaration, à
            // côté de l'export qu'elles alimentent : les deux se font l'une
            // après l'autre, et les séparer aux deux coins de cet écran laissait
            // exporter sans avoir rien renseigné.
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionCard(
                    title: '',
                    child: _buildReportParametersCard(context),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Aperçu de l\'export',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded,
                              size: 17, color: _kMuted),
                          tooltip: 'Actualiser',
                          onPressed: _previewLoading ? null : _loadPreview,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                        _artInfo('Art. 301/307'),
                      ],
                    ),
                    child: _buildPreviewContent(context),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 14,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _generating ? null : _generateAndSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: _kBlue,
                          disabledBackgroundColor:
                              _kBlue.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 13),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius)),
                        ),
                        icon: _generating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.picture_as_pdf_outlined,
                                size: 18, color: Colors.white),
                        label: _generating
                            ? const Text('Génération en cours…',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white))
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Générer le rapport',
                                      style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          height: 1.2)),
                                  Text(_periodeLabel,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white
                                              .withValues(alpha: 0.75),
                                          height: 1.2)),
                                ],
                              ),
                      ),
                      // Un accès, pas une action : renseigner les cases et
                      // exporter le formulaire sont deux moments de la même
                      // tâche, et ils vivent désormais sur la page qui leur est
                      // consacrée. Cet écran a pour sujet le rapport
                      // consolidé.
                      OutlinedButton.icon(
                        onPressed: _ouvrirLeFodep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kBlue,
                          side: const BorderSide(color: _kBlue),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 13),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radius)),
                        ),
                        icon: const Icon(Icons.table_view_rounded,
                            size: 18, color: _kBlue),
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Déclaration FODEP',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2)),
                            Text(
                                _dateFin == null
                                    ? 'Cases à renseigner et export'
                                    : 'Arrêté au ${_fmtDate(_dateFin!)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: _kBlue.withValues(alpha: 0.75),
                                    height: 1.2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportParametersCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.border;
    final headerBg = isDark
        ? const Color(0xFF0F1B31)
        : AppTheme.sidebar.withValues(alpha: 0.045);
    final textColor = isDark ? AppTheme.darkText : AppTheme.text;
    final mutedColor = isDark ? AppTheme.darkMuted : _kMuted;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 840;

        final periodSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _parameterSectionTitle(
              context,
              'Période du rapport',
              'Sélection rapide',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Mensuel', 'Trimestriel', 'Semestriel', 'Annuel']
                  .map((p) => _quickPeriodButton(context, p))
                  .toList(),
            ),
          ],
        );

        final fieldsSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _parameterSectionTitle(
              context,
              'Détails de génération',
              'Dates et destinataire',
            ),
            const SizedBox(height: 10),
            if (compact)
              Column(
                children: [
                  _reportingDateField(
                      context, 'Date de début', _dateDebutCtrl, _dateDebut,
                      (picked) {
                    setState(() {
                      _dateDebut = picked;
                      _dateDebutCtrl.text = _fmtDate(picked);
                    });
                  }),
                  _reportingDateField(
                      context, 'Date de fin', _dateFinCtrl, _dateFin, (picked) {
                    setState(() {
                      _dateFin = picked;
                      _dateFinCtrl.text = _fmtDate(picked);
                    });
                  }),
                  _dropdown(
                    context,
                    'Destinataire',
                    _destinataire,
                    [
                      'Organe exécutif',
                      'Organe délibérant',
                      'Commission Bancaire'
                    ],
                    (v) =>
                        setState(() => _destinataire = v ?? 'Organe exécutif'),
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _reportingDateField(
                          context, 'Date de début', _dateDebutCtrl, _dateDebut,
                          (picked) {
                    setState(() {
                      _dateDebut = picked;
                      _dateDebutCtrl.text = _fmtDate(picked);
                    });
                  })),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _reportingDateField(
                          context, 'Date de fin', _dateFinCtrl, _dateFin,
                          (picked) {
                    setState(() {
                      _dateFin = picked;
                      _dateFinCtrl.text = _fmtDate(picked);
                    });
                  })),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _dropdown(
                    context,
                    'Destinataire',
                    _destinataire,
                    [
                      'Organe exécutif',
                      'Organe délibérant',
                      'Commission Bancaire'
                    ],
                    (v) =>
                        setState(() => _destinataire = v ?? 'Organe exécutif'),
                  )),
                ],
              ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.sidebar,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paramètres du rapport',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _periodeLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: mutedColor,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            periodSection,
            const SizedBox(height: 14),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 14),
            fieldsSection,
          ],
        );
      },
    );
  }

  Widget _parameterSectionTitle(
      BuildContext context, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? AppTheme.darkText : AppTheme.text,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkMuted : _kMuted,
          ),
        ),
      ],
    );
  }

  Widget _quickPeriodButton(BuildContext context, String period) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected =
        _periode == period && _dateDebut != null && _dateFin != null;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.border;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      onTap: () => _applyQuickPeriod(period),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 112, minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kBlue : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: selected ? _kBlue : borderColor),
        ),
        child: Text(
          period,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : (isDark ? AppTheme.darkText : AppTheme.text),
          ),
        ),
      ),
    );
  }

  // ─── Aperçu de l'export : uniquement les éléments utiles à la décision ─────
  Widget _buildPreviewContent(BuildContext context) {
    if (_previewLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_previewError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 16, color: _kDanger),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Aperçu indisponible : $_previewError',
                  style: const TextStyle(fontSize: 12, color: _kDanger))),
        ]),
      );
    }
    final dash = _previewDash;
    final ro = _previewRo;
    if (dash == null) return const SizedBox.shrink();

    final rwaTotal = _metricValue(dash.metrics, 'rwa');
    final rwaCredit = _metricValue(dash.metrics, 'rwa_credit');
    final rwaMarche = _metricValue(dash.metrics, 'rwa_market');
    final rwaOp = _metricValue(dash.metrics, 'rwa_op');
    final capital = _metricValue(dash.metrics, 'capital');
    final solvab = _metricValue(dash.metrics, 'solvabilite');
    final solvabOk = solvab >= 8.0;

    final incidentsNonClos = ro?.widget2.incidentsNonClos ?? 0;
    final actionsEnRetard = ro?.widget3.actionsEnRetard ?? 0;
    final statutReg = ro?.widget1.statutReglementaire ?? 'Non renseigné';

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 1080
            ? 3
            : maxWidth >= 700
                ? 3
                : maxWidth >= 460
                    ? 2
                    : 1;
        final cardWidth = (maxWidth - (gap * (columns - 1))) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _previewKpi(
                  context,
                  'RWA Total',
                  _formatAmountForPreview(context, rwaTotal),
                  width: cardWidth,
                ),
                _previewKpi(
                  context,
                  'Capital Total (FPE)',
                  _formatAmountForPreview(context, capital),
                  width: cardWidth,
                ),
                _previewKpi(
                  context,
                  'Ratio de solvabilité',
                  AppFormatters.percent(solvab),
                  color: solvabOk ? _kSuccess : _kDanger,
                  emphasized: true,
                  width: cardWidth,
                ),
                _previewKpi(
                  context,
                  'RWA Crédit',
                  _formatAmountForPreview(context, rwaCredit),
                  width: cardWidth,
                ),
                _previewKpi(
                  context,
                  'RWA Marché',
                  _formatAmountForPreview(context, rwaMarche),
                  width: cardWidth,
                ),
                _previewKpi(
                  context,
                  'RWA Opérationnel',
                  _formatAmountForPreview(context, rwaOp),
                  width: cardWidth,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            const SizedBox(height: 12),
            Text('Alertes à date',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkMuted
                        : _kMuted,
                    letterSpacing: 0.2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _previewAlert(
                    context, 'Incidents non clôturés', '$incidentsNonClos',
                    alert: incidentsNonClos > 0),
                _previewAlert(context, 'Actions en retard', '$actionsEnRetard',
                    alert: actionsEnRetard > 0),
                _previewAlert(context, 'Statut réglementaire', statutReg,
                    alert: statutReg.toLowerCase().contains('non')),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _previewKpi(BuildContext context, String label, String value,
      {Color? color, bool emphasized = false, double width = 168}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? _kBlue;
    final surface = isDark ? AppTheme.darkCard : AppTheme.card;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;
    final labelColor = isDark ? AppTheme.darkMuted : _kMuted;
    final valueColor =
        emphasized ? c : (isDark ? AppTheme.darkText : AppTheme.text);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border:
            Border.all(color: emphasized ? c.withValues(alpha: 0.30) : border),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF1B2559).withValues(alpha: isDark ? 0.0 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: labelColor,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Text(value,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: valueColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewAlert(BuildContext context, String label, String value,
      {required bool alert}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = alert ? _kDanger : _kSuccess;
    final surface = isDark ? AppTheme.darkCard : AppTheme.card;
    final labelColor = isDark ? AppTheme.darkMuted : _kMuted;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: c.withValues(alpha: alert ? 0.30 : 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text('$label : ',
              style: TextStyle(
                  fontSize: 11.5,
                  color: labelColor,
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: c)),
        ],
      ),
    );
  }

  Widget _reportingDateField(
      BuildContext context,
      String label,
      TextEditingController ctrl,
      DateTime? value,
      ValueChanged<DateTime> onPicked) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.border;
    final fillColor = isDark ? AppTheme.darkCard : const Color(0xFFFBFCFF);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      borderSide: BorderSide(color: borderColor),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _kMuted,
                    letterSpacing: 0.1)),
          ]),
          const SizedBox(height: 5),
          TextFormField(
            controller: ctrl,
            readOnly: true,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'jj/mm/aaaa',
              hintStyle:
                  const TextStyle(fontSize: 12.5, color: Color(0xFFB0BAD0)),
              filled: true,
              fillColor: fillColor,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: outline,
              enabledBorder: outline,
              focusedBorder: outline.copyWith(
                borderSide: const BorderSide(color: _kBlue, width: 1.1),
              ),
              suffixIcon: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: const Icon(Icons.calendar_month_outlined,
                    size: 14, color: _kBlue),
              ),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                helpText: 'Sélectionner une date',
              );
              if (picked != null) onPicked(picked);
            },
          ),
        ],
      ),
    );
  }
}
