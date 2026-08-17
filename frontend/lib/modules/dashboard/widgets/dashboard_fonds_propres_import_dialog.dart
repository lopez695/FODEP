// Dialog d'import Excel pour les Fonds Propres Réglementaires (CET1/AT1/Tier2).
//
// Contrairement à l'import BIC/CCR3, il n'y a pas de dimension "année" ici :
// le modèle représente UNE seule photo des fonds propres, et l'import
// remplace entièrement les valeurs actuellement enregistrées - exactement
// comme le fait le formulaire "Mettre à jour" (DashboardFondsPropresDialog).
//
// Format attendu : un onglet avec 3 colonnes "Groupe" / "Poste" / "Valeur".
// Chaque ligne correspond à l'un des 11 postes (CET1/AT1/Tier2) ; le
// libellé "Poste" doit rester synchronisé avec FONDS_PROPRES_INPUT_FIELDS
// côté backend (app/dashboard/services.py).
import 'dart:io' show PathAccessException;
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/import/shared_import_layout.dart';
import '../models/dashboard_models.dart';

// ─── Les 11 postes attendus (doit rester synchronisé avec
// FONDS_PROPRES_INPUT_FIELDS côté backend) ──────────────────────────────────

const _fpFields = [
  'capital_ordinaire', 'reserves', 'resultats_report', 'resultat_eligible',
  'deductions_prud_cet1',
  'instruments_at1', 'primes_emission_at1', 'deductions_prud_at1',
  'dettes_subordonnees_t2', 'provisions_generales_t2', 'deductions_prud_t2',
];

const _fpLabels = [
  'Capital ordinaire', 'Réserves', 'Résultats en report', 'Résultat éligible',
  'Réduction prudentielle (CET1)',
  'Instruments additionnels (AT1)', 'Primes d\'émission (AT1)', 'Réduction prudentielle (AT1)',
  'Dettes subordonnées (Tier 2)', 'Provisions générales (Tier 2)', 'Réduction prudentielle (Tier 2)',
];

// ─── Point d'entrée ───────────────────────────────────────────────────────────

Future<bool?> showFondsPropresImportDialog(
  BuildContext context, {
  required RwaApiService api,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _FondsPropresImportDialog(api: api),
  );
}

// ─── Dialog ───────────────────────────────────────────────────────────────────

class _FondsPropresImportDialog extends StatefulWidget {
  const _FondsPropresImportDialog({required this.api});
  final RwaApiService api;

  @override
  State<_FondsPropresImportDialog> createState() => _FondsPropresImportDialogState();
}

class _FondsPropresImportDialogState extends State<_FondsPropresImportDialog> {
  bool _isDragging = false;
  bool _isParsing = false;
  bool _isImporting = false;
  bool _isDownloadingTemplate = false;
  bool _rowsReady = false;
  bool _showExpectedFormat = true;

  XFile? _selectedFile;
  List<String>? _unmatchedWarnings;
  String? _importError;
  bool? _importSuccess;

  final List<TextEditingController> _ctrl =
      List.generate(_fpFields.length, (_) => TextEditingController());

  ThemeData get _theme => Theme.of(context);
  bool get _isDark => _theme.brightness == Brightness.dark;
  Color get _bg =>
      _theme.cardTheme.color ?? (_isDark ? AppTheme.darkCard : AppTheme.card);
  Color get _border => _theme.dividerColor;
  Color get _text =>
      _theme.textTheme.bodyLarge?.color ??
      (_isDark ? AppTheme.darkText : AppTheme.text);
  Color get _muted => _isDark ? AppTheme.darkMuted : AppTheme.muted;
  Color get _accent => _theme.colorScheme.primary;

  @override
  void dispose() {
    for (final c in _ctrl) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Fichier ──────────────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    setState(() => _isDownloadingTemplate = true);
    try {
      final bytes = await widget.api.downloadFondsPropresImportTemplate();
      if (!mounted) return;
      final location = await getSaveLocation(
        suggestedName: 'modele_import_fonds_propres.xlsx',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Excel', extensions: ['xlsx']),
        ],
      );
      if (location == null) return;
      await saveBytesAtLocation(location, bytes, requiredExtension: '.xlsx');
      if (mounted) _showMsg('Modèle enregistré.');
    } on PathAccessException {
      if (mounted) {
        _showMsg(
          'Impossible d\'enregistrer : le fichier est probablement déjà ouvert '
          '(par exemple dans Excel). Fermez-le puis réessayez, ou choisissez '
          'un autre emplacement.',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) _showMsg('Téléchargement impossible: $e', error: true);
    } finally {
      if (mounted) setState(() => _isDownloadingTemplate = false);
    }
  }

  Future<void> _pickFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (file == null) return;
    await _loadFile(file);
  }

  Future<void> _loadFile(XFile file) async {
    if (!file.name.toLowerCase().endsWith('.xlsx')) {
      _showMsg('Seuls les fichiers .xlsx sont acceptés.', error: true);
      return;
    }
    setState(() {
      _isParsing = true;
      _rowsReady = false;
      _unmatchedWarnings = null;
      _selectedFile = file;
      _importSuccess = null;
      _importError = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final warnings = _parseExcel(bytes);
      if (mounted) {
        setState(() {
          _unmatchedWarnings = warnings;
          _rowsReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rowsReady = false;
          _unmatchedWarnings = ['Lecture impossible: $e'];
        });
      }
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  // ─── Parsing Excel (client-side) ──────────────────────────────────────────

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static const _valeurAliases = ['valeur', 'montant', 'value', 'val', 'fcfa'];

  static String _cellStr(dynamic cell) {
    if (cell == null) return '';
    return cell.toString().trim();
  }

  static double _parseNum(String s) {
    if (s.isEmpty) return 0;
    final clean = s.replaceAll(' ', '').replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0;
  }

  /// Trouve l'index de champ (0..10) correspondant au libellé brut d'une
  /// ligne "Poste", en comparant d'abord exactement puis par proximité.
  int? _matchFieldIndex(String rawLabel) {
    final n = _norm(rawLabel);
    if (n.isEmpty) return null;
    for (var i = 0; i < _fpLabels.length; i++) {
      if (_norm(_fpLabels[i]) == n) return i;
    }
    final minLen = math.min(8, n.length);
    for (var i = 0; i < _fpLabels.length; i++) {
      final ln = _norm(_fpLabels[i]);
      if (ln.contains(n.substring(0, minLen)) || n.contains(ln.substring(0, math.min(8, ln.length)))) {
        return i;
      }
    }
    return null;
  }

  List<String> _parseExcel(Uint8List bytes) {
    final SpreadsheetDecoder excel;
    try {
      excel = SpreadsheetDecoder.decodeBytes(bytes);
    } catch (e) {
      throw Exception('Fichier illisible ou corrompu : $e');
    }
    if (excel.tables.isEmpty) throw Exception('Aucune feuille trouvée.');

    SpreadsheetTable? sheet;
    for (final key in excel.tables.keys) {
      if (key.toLowerCase().contains('fonds') || key.toLowerCase().contains('propres')) {
        final candidate = excel.tables[key];
        if (candidate != null) {
          sheet = candidate;
          break;
        }
      }
    }
    sheet ??= excel.tables.values.firstWhere((s) => s.rows.isNotEmpty, orElse: () => excel.tables.values.first);

    final allRows = sheet.rows;
    if (allRows.isEmpty) throw Exception('Feuille vide.');

    // ── Étape 1 : trouver la ligne d'en-têtes (colonnes Poste/Valeur) ──────
    int headerRowIdx = -1;
    int posteCol = -1;
    int valeurCol = -1;

    for (var ri = 0; ri < math.min(6, allRows.length); ri++) {
      final row = allRows[ri];
      int? pCol, vCol;
      for (var ci = 0; ci < row.length; ci++) {
        final raw = _cellStr(row[ci]);
        if (raw.isEmpty) continue;
        final n = _norm(raw);
        if (pCol == null && n.contains('poste')) {
          pCol = ci;
        } else if (vCol == null && _valeurAliases.any((a) => n == a || n.contains(a))) {
          vCol = ci;
        }
      }
      if (pCol != null && vCol != null) {
        headerRowIdx = ri;
        posteCol = pCol;
        valeurCol = vCol;
        break;
      }
    }

    if (headerRowIdx == -1) {
      throw Exception(
          'Colonnes introuvables. Le fichier doit contenir une colonne "Poste" '
          'et une colonne "Valeur".');
    }

    // ── Étape 2 : lire chaque ligne de données ─────────────────────────────
    final values = <int, double>{};
    final unmatched = <String>[];

    for (var ri = headerRowIdx + 1; ri < allRows.length; ri++) {
      final row = allRows[ri];
      if (row.every((c) => _cellStr(c).isEmpty)) continue;

      final posteRaw = posteCol < row.length ? _cellStr(row[posteCol]) : '';
      if (posteRaw.isEmpty) continue;

      final fieldIdx = _matchFieldIndex(posteRaw);
      if (fieldIdx == null) {
        unmatched.add(posteRaw);
        continue;
      }

      final valeurRaw = valeurCol < row.length ? _cellStr(row[valeurCol]) : '';
      values[fieldIdx] = _parseNum(valeurRaw);
    }

    if (values.isEmpty) {
      throw Exception(
          'Aucune ligne exploitable : vérifiez que la colonne "Poste" contient '
          'les libellés attendus.');
    }

    for (final entry in values.entries) {
      final v = entry.value;
      _ctrl[entry.key].text = v == 0 ? '' : v.toStringAsFixed(0);
    }

    final missing = <String>[
      for (var i = 0; i < _fpLabels.length; i++)
        if (!values.containsKey(i)) _fpLabels[i],
    ];

    return [
      ...unmatched.map((l) => 'Poste non reconnu, ignoré : "$l"'),
      if (missing.isNotEmpty) 'Postes absents (laissés à 0) : ${missing.join(', ')}',
    ];
  }

  // ─── Calculs en direct (aperçu) ────────────────────────────────────────────

  double _parse(int idx) => _parseNum(_ctrl[idx].text);

  double get _cet1 {
    final v = _parse(0) + _parse(1) + _parse(2) + _parse(3) - _parse(4);
    return v < 0 ? 0 : v;
  }

  double get _at1 {
    final v = _parse(5) + _parse(6) - _parse(7);
    return v < 0 ? 0 : v;
  }

  double get _tier2 {
    final v = _parse(8) + _parse(9) - _parse(10);
    return v < 0 ? 0 : v;
  }

  double get _total => _cet1 + _at1 + _tier2;

  // ─── Import ───────────────────────────────────────────────────────────────

  Future<void> _runImport() async {
    setState(() {
      _isImporting = true;
      _importError = null;
    });
    try {
      final update = FondsPropresUpdate(
        capitalOrdinaire: _parse(0),
        reserves: _parse(1),
        resultatsReport: _parse(2),
        resultatEligible: _parse(3),
        deductionsPrudCet1: _parse(4),
        instrumentsAt1: _parse(5),
        primesEmissionAt1: _parse(6),
        deductionsPrudAt1: _parse(7),
        dettesSubordonneesT2: _parse(8),
        provisionsGeneralesT2: _parse(9),
        deductionsPrudT2: _parse(10),
      );
      await widget.api.updateFondsPropres(update);
      if (!mounted) return;
      setState(() => _importSuccess = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _importSuccess = false;
          _importError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.success,
    ));
  }

  // ─── Build principal ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SharedImportDialogCard(
      maxWidth: 900,
      maxHeight: 660,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SharedImportHeader(
            title: 'Importation Fonds Propres',
            isImporting: _isImporting,
            onClose: () => Navigator.pop(context, false),
          ),
          Divider(height: 1, color: _border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
              child: _buildBody(),
            ),
          ),
          Divider(height: 1, color: _border),
          SharedImportFooter(
            isImporting: _isImporting,
            onClose: () => Navigator.pop(context, false),
            canValidate: _rowsReady && !_isImporting && _importSuccess == null,
            onRunImport: _runImport,
          ),
        ],
      ),
    );
  }



  Widget _buildBody() {
    if (_importSuccess != null) return _buildResultScreen();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_rowsReady) _buildImportZone(),
          if (!_rowsReady) const SizedBox(height: 4),
          if (_rowsReady) _buildPreviewScreen(),
          if (_rowsReady) const SizedBox(height: 4),
          _buildExpectedFormatSection(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: !_showExpectedFormat && _selectedFile == null && !_rowsReady
                ? Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: _buildEmptyStatePlaceholder(),
                  )
                : const SizedBox.shrink(),
          ),
          if (!_rowsReady &&
              (_unmatchedWarnings != null &&
                  _unmatchedWarnings!.isNotEmpty &&
                  _unmatchedWarnings!.first.startsWith('Lecture impossible')))
            _buildParseErrorContent(),
        ],
      ),
    );
  }

  Widget _buildImportZone() {
    return SharedImportSectionCard(
      icon: CupertinoIcons.doc_text,
      title: 'Zone d’import',
      child: SharedImportDropZone(
        selectedFile: _selectedFile,
        isDragging: _isDragging,
        isInspecting: _isParsing,
        isImporting: _isImporting,
        onPickFile: _pickFile,
        onDragEntered: () => setState(() => _isDragging = true),
        onDragExited: () => setState(() => _isDragging = false),
        onDroppedFiles: (files) async {
          setState(() => _isDragging = false);
          if (files.isNotEmpty) await _loadFile(files.first);
        },
      ),
    );
  }

  Widget _buildExpectedFormatSection({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SharedExpectedActionButton(
              icon: _showExpectedFormat
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              label: 'Format attendu',
              selected: _showExpectedFormat,
              onPressed: () => setState(() => _showExpectedFormat = !_showExpectedFormat),
            ),
            SharedExpectedActionButton(
              icon: CupertinoIcons.arrow_down_doc,
              label: _isDownloadingTemplate
                  ? 'Préparation du modèle'
                  : 'Télécharger le modèle',
              onPressed: _isDownloadingTemplate ? null : _downloadTemplate,
            ),
          ],
        ),
        const SizedBox(height: 3),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: !_showExpectedFormat
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: _border),
                  ),
                  child: _buildExpectedFormat(),
                ),
        ),
      ],
    );
  }

  Widget _buildExpectedFormat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkbookSummaryCard(),
        const SizedBox(height: 3),
        _buildSheetSpecTile(),
      ],
    );
  }

  Widget _buildWorkbookSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF161F2E) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Classeur complet requis',
            style: TextStyle(
              color: _text,
              fontSize: 11.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '1 feuille doit être présente et conservée dans le fichier importé.',
            style: TextStyle(color: _muted, fontSize: 10.2),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _buildSheetNameChip('Fonds Propres', backgroundColor: const Color(0xFFEDF2FB)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSheetNameChip(String sheetName, {required Color backgroundColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: backgroundColor.withValues(alpha: 0.78)),
      ),
      child: Text(
        sheetName,
        style: TextStyle(
          color: _text,
          fontSize: 9.7,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSheetSpecTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF161F2E) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Fonds Propres',
                style: TextStyle(color: _text, fontSize: 11.8, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Saisie',
                  style: TextStyle(color: _text, fontSize: 9.8, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Une ligne = un poste. 11 lignes attendues (CET1, AT1, Tier 2).',
            style: TextStyle(color: _muted, fontSize: 10.2),
          ),
          const SizedBox(height: 8),
          _buildColumnGroup(
            title: 'Colonnes attendues',
            count: 3,
            items: ['Groupe', 'Poste', 'Valeur'],
            color: _accent,
          ),
        ],
      ),
    );
  }

  Widget _buildColumnGroup({required String title, required int count, required List<dynamic> items, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
              ),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: _text, fontSize: 9.9, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Text('($count)', style: TextStyle(color: _muted, fontSize: 9.0, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5, runSpacing: 4,
            children: items.map((item) => _buildMarkerChip(item.toString(), color)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerChip(String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        value,
        style: TextStyle(color: _text, fontSize: 9.15, fontWeight: FontWeight.w500),
      ),
    );
  }


  Widget _buildEmptyStatePlaceholder() {
    return DropTarget(
      onDragDone: (details) async {
        if (mounted) setState(() => _isDragging = false);
        if (details.files.isNotEmpty) await _loadFile(details.files.first);
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isParsing || _isImporting ? null : _pickFile,
          borderRadius: BorderRadius.circular(3),
          child: AnimatedContainer(
            width: double.infinity,
            height: 178,
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _isDragging ? Color.lerp(_bg, _accent, 0.05) : _bg,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: _isDragging ? _accent : _border, width: _isDragging ? 1.3 : 1),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _isDragging ? _accent.withValues(alpha: 0.14) : _accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: _accent.withValues(alpha: 0.18)),
                    ),
                    child: Icon(
                      _isDragging ? Icons.file_download_done_rounded : Icons.upload_file_rounded,
                      color: _accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isDragging ? 'Relâchez pour charger le fichier' : 'Sélectionnez votre fichier ici',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _text, fontSize: 12.2, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cliquez pour choisir un fichier .xlsx',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 10.6, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF172130) : const Color(0xFFF4F7FC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: _accent),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: _text, fontSize: 12.8, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  Widget _buildImportHintChip({required IconData icon, required String label}) {
    final chipBackground = _isDark ? const Color(0xFF1A2638) : const Color(0xFFF2F6FB);
    final chipForeground = _isDark ? const Color(0xFFC9D6EA) : const Color(0xFF5B6A81);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: chipBackground, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: chipForeground),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: chipForeground, fontSize: 10.2, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildParseErrorContent() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 44, color: AppTheme.danger),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _unmatchedWarnings!.first,
              style: const TextStyle(color: AppTheme.danger, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _unmatchedWarnings = null;
              _selectedFile = null;
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Choisir un autre fichier'),
          ),
        ],
      );

  Widget _buildPreviewScreen() {
    return _buildSectionCard(
      icon: Icons.checklist_rtl_rounded,
      title: 'Vérification du fichier',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFileInfoBar(),
          const SizedBox(height: 12),
          if (_unmatchedWarnings != null && _unmatchedWarnings!.isNotEmpty) ...[
            _buildWarningPanel(_unmatchedWarnings!),
            const SizedBox(height: 10),
          ],
          _buildEditableGroups(),
        ],
      ),
    );
  }

  Widget _buildFileInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(Icons.table_chart_outlined, size: 18, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedFile?.name ?? '',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: _text, fontSize: 13),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              _rowsReady = false;
              _selectedFile = null;
              _unmatchedWarnings = null;
              for (final c in _ctrl) {
                c.clear();
              }
            }),
            icon: const Icon(Icons.swap_horiz, size: 15),
            label: const Text('Changer'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningPanel(List<String> warnings) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppTheme.warning),
              const SizedBox(width: 6),
              Text('À vérifier',
                  style: TextStyle(fontSize: 12, color: _text, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ...warnings.map((w) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $w', style: TextStyle(fontSize: 11.5, color: _muted)),
              )),
        ],
      ),
    );
  }

  Widget _buildEditableGroups() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _groupCard('CET1', 'Fonds propres de base', const Color(0xFF1E40AF), 0, 5)),
            const SizedBox(width: 12),
            Expanded(child: _groupCard('AT1', 'Fonds propres additionnels', const Color(0xFF1E3A8A), 5, 8)),
            const SizedBox(width: 12),
            Expanded(child: _groupCard('Tier 2', 'Fonds propres complémentaires', const Color(0xFF475569), 8, 11)),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem('Total CET1', _cet1, const Color(0xFF1E40AF)),
              _summaryItem('Total AT1', _at1, const Color(0xFF1E3A8A)),
              _summaryItem('Total Tier 2', _tier2, const Color(0xFF475569)),
              Container(width: 1, height: 28, color: _border),
              _summaryItem('Fonds Propres Globaux', _total, const Color(0xFF10B981), isTotal: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _groupCard(String title, String subtitle, Color color, int from, int to) {
    return Container(
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1B273A) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: color),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _text)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 10.5, color: _muted)),
              ],
            ),
          ),
          Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                for (var i = from; i < to; i++) _fieldRow(i),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldRow(int idx) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_fpLabels[idx], style: TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 3),
          TextField(
            controller: _ctrl[idx],
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d .,]'))],
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _text),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '0',
              suffixText: ' FCFA',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double val, Color color, {bool isTotal = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _muted)),
        const SizedBox(height: 4),
        Text(
          '${(val / 1e9).toStringAsFixed(3)} Md',
          style: TextStyle(fontSize: isTotal ? 15 : 13, fontWeight: FontWeight.w800, color: isTotal ? color : _text),
        ),
      ],
    );
  }

  // ─── Écran 3 : Résultat ────────────────────────────────────────────────────

  Widget _buildResultScreen() {
    final ok = _importSuccess == true;
    return Center(
      child: Container(
        width: 430,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                  size: 28,
                  color: ok ? AppTheme.success : AppTheme.danger,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ok ? 'Import terminé' : 'Échec de l\'import',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              ok
                  ? 'Les fonds propres réglementaires ont été mis à jour.'
                  : (_importError ?? 'Une erreur est survenue.'),
              style: TextStyle(fontSize: 14, color: _text),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, ok),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualiser le tableau de bord'),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
