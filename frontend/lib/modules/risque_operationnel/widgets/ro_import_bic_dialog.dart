// Dialog d'import Excel pour le formulaire BIC / CCR3 (Risque Opérationnel).
//
// Format attendu : UN ONGLET (feuille) PAR EXERCICE. Le nom de l'onglet est
// l'année concernée (ex : "2024"), et chaque feuille contient deux colonnes,
// "Poste" et "Valeur" - il n'y a donc jamais de mélange ni d'ambiguïté entre
// les données de plusieurs exercices : chacun est physiquement séparé dans
// sa propre feuille. Le fichier peut contenir n'importe quel nombre
// d'onglets/exercices (pas forcément 3) ; les onglets sans année reconnue
// (ex : "Instructions") sont simplement ignorés.
//
// Par souci de compatibilité, l'ancien format « long » (une feuille unique
// avec les colonnes Année / Poste / Valeur, une ligne = un exercice) reste
// aussi accepté en repli, pour les feuilles qui ne portent pas de nom
// d'année reconnaissable mais qui possèdent une colonne "Année".
//
// L'import ne crée pas de nouvelle route backend : il réutilise
// `upsertBicInput(annee, data)` pour chaque exercice trouvé, exactement
// comme le fait déjà l'onglet "Saisie".
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

// ─── Les 13 postes attendus (doit rester synchronisé avec _kFields/_kLabels
// dans risque_operationnel_screen.dart, classe _Ccr3TabViewState) ────────────

const _bicFields = [
  'interets_percus', 'interets_verses', 'dividendes_percus',
  'tresorerie_et_banques_centrales', 'creances_etablissements_credit',
  'creances_clientele', 'provisions',
  'autres_produits_exploitation', 'autres_charges_exploitation',
  'commissions_percues', 'commissions_versees',
  'resultat_portefeuille_negociation', 'resultat_portefeuille_bancaire',
  'pnb',
];

const _bicLabels = [
  'Intérêts perçus', 'Intérêts versés', 'Dividendes perçus',
  'Trésorerie & Banques centrales', 'Créances sur Étab. de crédit',
  'Créances clientèle (brut)', 'Provisions sur créances',
  'Autres produits d\'exploitation', 'Autres charges d\'exploitation',
  'Commissions perçues', 'Commissions versées',
  'Résultat net Ptf négociation', 'Résultat net Ptf bancaire',
  // Doit être identique au libellé généré par le modèle Excel
  // (BIC_INPUT_FIELDS côté backend), sinon la colonne "Poste" ne matche
  // jamais et le PNB reste systématiquement à 0 après import.
  'PNB (BIA - si non calculé automatiquement)',
];

// ─── Point d'entrée ───────────────────────────────────────────────────────────

Future<bool?> showRoImportBicDialog(
  BuildContext context, {
  required RwaApiService api,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RoImportBicDialog(api: api),
  );
}

// ─── Dialog ───────────────────────────────────────────────────────────────────

class _RoImportBicDialog extends StatefulWidget {
  const _RoImportBicDialog({required this.api});
  final RwaApiService api;

  @override
  State<_RoImportBicDialog> createState() => _RoImportBicDialogState();
}

class _RoImportBicDialogState extends State<_RoImportBicDialog> {
  bool _isDragging = false;
  bool _isParsing = false;
  bool _isImporting = false;
  bool _isDownloadingTemplate = false;
  String _importStage = '';

  XFile? _selectedFile;
  List<String>? _unmatchedWarnings;
  Map<String, dynamic>? _importResult; // {"imported": [annees...], "errors": [...]}

  // Années effectivement trouvées dans le fichier (une colonne "Année" par
  // ligne, pas un en-tête générique) - triées, modifiables individuellement,
  // et on peut en ajouter/retirer manuellement.
  List<int> _years = [];

  // Contrôleurs [fieldIndex][yearColIndex] - reconstruits à chaque parsing
  // ou ajout/suppression d'exercice, puisque le nombre d'années est variable.
  List<List<TextEditingController>> _ctrl = [];
  bool _rowsReady = false;

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
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final row in _ctrl) {
      for (final c in row) {
        c.dispose();
      }
    }
  }

  /// (Re)construit `_ctrl` avec une colonne par année de `_years`, en
  /// conservant les valeurs déjà saisies quand une année est simplement
  /// ajoutée/retirée (les contrôleurs des autres colonnes sont recréés à
  /// vide puis republiés par `_fillControllersFromData`).
  void _rebuildControllers() {
    _disposeControllers();
    _ctrl = List.generate(
      _bicFields.length,
      (_) => List.generate(_years.length, (_) => TextEditingController()),
    );
  }

  void _fillControllersFromData(Map<int, Map<int, double>> dataByYear) {
    for (var yi = 0; yi < _years.length; yi++) {
      final values = dataByYear[_years[yi]];
      if (values == null) continue;
      for (final entry in values.entries) {
        final fieldIdx = entry.key;
        final value = entry.value;
        _ctrl[fieldIdx][yi].text = value == 0 ? '' : value.toStringAsFixed(0);
      }
    }
  }

  // ─── Fichier ──────────────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    setState(() => _isDownloadingTemplate = true);
    try {
      final bytes = await widget.api.downloadBicImportTemplate();
      if (!mounted) return;
      final location = await getSaveLocation(
        suggestedName: 'modele_import_bic_ccr3.xlsx',
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
      _importResult = null;
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

  static const _anneeAliases = ['annee', 'année', 'exercice', 'year', 'ex'];
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

  /// Extrait une année plausible (1900-2100) d'un texte de cellule.
  static int? _parseYear(String s) {
    final m = RegExp(r'(19|20)\d{2}').firstMatch(s);
    if (m == null) return null;
    return int.tryParse(m.group(0)!);
  }

  /// Trouve l'index de champ (0..12) correspondant au libellé brut d'une
  /// ligne "Poste", en comparant d'abord exactement puis par proximité.
  int? _matchFieldIndex(String rawLabel) {
    final n = _norm(rawLabel);
    if (n.isEmpty) return null;
    for (var i = 0; i < _bicLabels.length; i++) {
      if (_norm(_bicLabels[i]) == n) return i;
    }
    // Le PNB est référencé sous plusieurs libellés selon l'écran (« PNB
    // (Produit Net Bancaire) » dans l'onglet Saisie, « PNB (BIA - si non
    // calculé automatiquement) » dans le modèle Excel). Un fichier créé à la
    // main avec l'un ou l'autre libellé - ou juste « PNB » - doit matcher
    // dans tous les cas, sans quoi le poste reste systématiquement à 0 après
    // import (symptôme : la colonne PNB n'affiche que des tirets).
    if (n == 'pnb' || n.startsWith('pnb_')) {
      return _bicFields.indexOf('pnb');
    }
    final minLen = math.min(6, n.length);
    for (var i = 0; i < _bicLabels.length; i++) {
      final ln = _norm(_bicLabels[i]);
      if (ln.contains(n.substring(0, minLen)) || n.contains(ln.substring(0, math.min(6, ln.length)))) {
        return i;
      }
    }
    return null;
  }

  /// Détermine l'année représentée par un onglet, à partir de son nom
  /// (ex : "2024", "Exercice 2024"). Retourne `null` si aucune année
  /// plausible n'y figure (ex : "Instructions", "Feuil1").
  static int? _yearFromSheetName(String name) {
    final trimmed = name.trim();
    final asInt = int.tryParse(trimmed);
    if (asInt != null && asInt >= 1900 && asInt <= 2100) return asInt;
    return _parseYear(trimmed);
  }

  /// Parse le classeur au format « un onglet par exercice » : le nom de
  /// chaque feuille porte l'année, et la feuille contient les colonnes
  /// « Poste » / « Valeur ». Une feuille sans année reconnaissable dans son
  /// nom mais dotée d'une colonne "Année" est lue à l'ancien format « long »
  /// (une ligne = un exercice), par compatibilité. Retourne les
  /// avertissements non bloquants.
  List<String> _parseExcel(Uint8List bytes) {
    final SpreadsheetDecoder excel;
    try {
      excel = SpreadsheetDecoder.decodeBytes(bytes);
    } catch (e) {
      throw Exception('Fichier illisible ou corrompu : $e');
    }
    if (excel.tables.isEmpty) throw Exception('Aucune feuille trouvée.');

    final dataByYear = <int, Map<int, double>>{};
    final matchedFieldsByYear = <int, Set<int>>{};
    final unmatched = <String>[];
    final skippedSheets = <String>[];

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null) continue;
      final allRows = sheet.rows;
      if (allRows.isEmpty) continue;

      final sheetYear = _yearFromSheetName(sheetName);

      // ── Cherche une ligne d'en-tête (Poste / Valeur, +Année optionnelle) ──
      int headerRowIdx = -1;
      int anneeCol = -1, posteCol = -1, valeurCol = -1;
      for (var ri = 0; ri < math.min(6, allRows.length); ri++) {
        final row = allRows[ri];
        int? aCol, pCol, vCol;
        for (var ci = 0; ci < row.length; ci++) {
          final raw = _cellStr(row[ci]);
          if (raw.isEmpty) continue;
          final n = _norm(raw);
          if (aCol == null && _anneeAliases.any((a) => n == a || n.contains(a))) {
            aCol = ci;
          } else if (pCol == null && n.contains('poste')) {
            pCol = ci;
          } else if (vCol == null && _valeurAliases.any((a) => n == a || n.contains(a))) {
            vCol = ci;
          }
        }
        if (pCol != null && vCol != null) {
          headerRowIdx = ri;
          anneeCol = aCol ?? -1;
          posteCol = pCol;
          valeurCol = vCol;
          break;
        }
      }

      // Pas de colonnes Poste/Valeur reconnues (ex : feuille "Instructions").
      if (headerRowIdx == -1) continue;

      final usesRowLevelYear = sheetYear == null && anneeCol != -1;
      if (sheetYear == null && !usesRowLevelYear) {
        // Ni le nom de l'onglet ni une colonne "Année" ne permettent de
        // déterminer l'exercice : on ignore cette feuille.
        skippedSheets.add(sheetName);
        continue;
      }

      for (var ri = headerRowIdx + 1; ri < allRows.length; ri++) {
        final row = allRows[ri];
        if (row.every((c) => _cellStr(c).isEmpty)) continue;

        final posteRaw = posteCol < row.length ? _cellStr(row[posteCol]) : '';
        if (posteRaw.isEmpty) continue;

        int? annee = sheetYear;
        if (usesRowLevelYear) {
          final anneeRaw = anneeCol < row.length ? _cellStr(row[anneeCol]) : '';
          annee = _parseYear(anneeRaw);
        }
        if (annee == null) continue;

        final fieldIdx = _matchFieldIndex(posteRaw);
        if (fieldIdx == null) {
          unmatched.add('$posteRaw (onglet "$sheetName")');
          continue;
        }

        final valeurRaw = valeurCol < row.length ? _cellStr(row[valeurCol]) : '';
        final value = _parseNum(valeurRaw);

        dataByYear.putIfAbsent(annee, () => {})[fieldIdx] = value;
        matchedFieldsByYear.putIfAbsent(annee, () => {}).add(fieldIdx);
      }
    }

    if (dataByYear.isEmpty) {
      throw Exception(
          'Aucune donnée exploitable. Chaque exercice doit être un onglet '
          'nommé avec l\'année (ex : "2023"), contenant les colonnes '
          '"Poste" et "Valeur".');
    }

    _years = dataByYear.keys.toList()..sort();
    _rebuildControllers();
    _fillControllersFromData(dataByYear);

    final warnings = <String>[
      if (skippedSheets.isNotEmpty)
        'Onglet(s) ignoré(s), aucune année reconnaissable (renommez l\'onglet '
            'avec l\'année, ex "2023") : ${skippedSheets.join(', ')}',
      ...unmatched.map((l) => 'Poste non reconnu, ignoré : "$l"'),
    ];
    for (final annee in _years) {
      final matched = matchedFieldsByYear[annee] ?? {};
      final missing = <String>[
        for (var i = 0; i < _bicLabels.length; i++)
          if (!matched.contains(i)) _bicLabels[i],
      ];
      if (missing.isNotEmpty) {
        warnings.add('Exercice $annee - postes absents (laissés à 0) : ${missing.join(', ')}');
      }
    }
    return warnings;
  }

  // ─── Gestion manuelle des exercices ────────────────────────────────────────

  void _addYear() {
    setState(() {
      final suggestion = _years.isEmpty
          ? DateTime.now().year - 1
          : _years.last + 1;
      var next = suggestion;
      while (_years.contains(next)) {
        next++;
      }
      _years.add(next);
      _years.sort();
      final insertedAt = _years.indexOf(next);
      for (final row in _ctrl) {
        row.insert(insertedAt, TextEditingController());
      }
      _rowsReady = true;
    });
  }

  void _removeYear(int yearColIdx) {
    setState(() {
      _years.removeAt(yearColIdx);
      for (final row in _ctrl) {
        row.removeAt(yearColIdx).dispose();
      }
    });
  }

  void _changeYear(int yearColIdx, int delta) {
    setState(() {
      final newYear = _years[yearColIdx] + delta;
      if (_years.contains(newYear)) return; // évite les doublons
      _years[yearColIdx] = newYear;
      _years.sort();
    });
  }

  // ─── Import ───────────────────────────────────────────────────────────────

  Future<void> _runImport() async {
    setState(() {
      _isImporting = true;
      _importStage = 'Envoi des données au serveur…';
    });
    final errors = <String>[];
    final importedYears = <int>[];
    try {
      for (var yi = 0; yi < _years.length; yi++) {
        final annee = _years[yi];
        final data = <String, dynamic>{};
        for (var fi = 0; fi < _bicFields.length; fi++) {
          data[_bicFields[fi]] = _parseNum(_ctrl[fi][yi].text);
        }
        try {
          setState(() => _importStage = 'Enregistrement de l\'exercice $annee…');
          await widget.api.upsertBicInput(annee, data);
          importedYears.add(annee);
        } catch (e) {
          errors.add('Exercice $annee : $e');
        }
      }
      if (!mounted) return;
      setState(() {
        _importResult = {'imported': importedYears, 'errors': errors};
      });
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
            title: 'Importation BIC / CCR3',
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
            canValidate: _rowsReady && !_isImporting && _importResult == null,
            onRunImport: _runImport,
            centerWidget: Text(
              _rowsReady
                  ? 'Vérifiez les valeurs ci-dessus avant d\'enregistrer.'
                  : 'Sélectionnez un fichier pour lancer la lecture.',
              textAlign: TextAlign.end,
              style: TextStyle(color: _muted, fontSize: 10.2, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Corps ────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_importResult != null) return _buildResultScreen();
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
          if (!_rowsReady && _unmatchedWarnings != null &&
              _unmatchedWarnings!.length == 1 &&
              _unmatchedWarnings!.first.startsWith('Lecture impossible'))
            _buildParseErrorContent(),
        ],
      ),
    );
  }

  bool _showExpectedFormat = true;

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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: !_showExpectedFormat && _selectedFile == null
              ? Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: DropTarget(
                    onDragDone: (d) async {
                      setState(() => _isDragging = false);
                      if (d.files.isNotEmpty) await _loadFile(d.files.first);
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
                  ),
                )
              : !_showExpectedFormat
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(3), border: Border.all(color: _border)),
                        child: _buildExpectedFormat(),
                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Structure requise', style: TextStyle(color: _text, fontSize: 11.8, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            'Un onglet par exercice. L\'onglet doit être renommé avec l\'année correspondante.',
            style: TextStyle(color: _muted, fontSize: 10.2),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _buildSheetNameChip('Ex : 2024', backgroundColor: const Color(0xFFEDF2FB)),
              _buildSheetNameChip('Ex : 2023', backgroundColor: const Color(0xFFEDF2FB)),
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
      child: Text(sheetName, style: TextStyle(color: _text, fontSize: 9.7, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildSheetSpecTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Onglet d\'exercice', style: TextStyle(color: _text, fontSize: 11.8, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                child: Text('Saisie', style: TextStyle(color: _text, fontSize: 9.8, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Chaque onglet doit contenir 13 lignes (les libellés du formulaire BIC).',
            style: TextStyle(color: _muted, fontSize: 10.2),
          ),
          const SizedBox(height: 8),
          _buildColumnGroup(
            title: 'Colonnes attendues',
            count: 2,
            items: ['Poste', 'Valeur (FCFA)'],
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
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
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
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.28))),
      child: Text(value, style: TextStyle(color: _text, fontSize: 9.15, fontWeight: FontWeight.w500)),
    );
  }



  Widget _buildImportHintChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF161F2E) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _isDark ? const Color(0xFF2A3850) : const Color(0xFFDCE5F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _muted),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: _muted, fontSize: 9.8, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyStatePlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF161F2E) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 38, color: _muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('Aucun fichier sélectionné', style: TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildParseErrorContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 32, color: AppTheme.danger),
            const SizedBox(height: 6),
            Text(
              _unmatchedWarnings!.first,
              style: const TextStyle(color: AppTheme.danger, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  // ─── Écran 2 : Prévisualisation / édition ─────────────────────────────────

  Widget _buildPreviewScreen() {
    return SharedImportSectionCard(
      icon: CupertinoIcons.check_mark_circled,
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
          _buildEditableTable(),
        ],
      ),
    );
  }

  Widget _buildFileInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(4),
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
          const SizedBox(width: 10),
          _badge('${_years.length} exercice(s) détecté(s)', const Color(0xFF1D4ED8)),
          TextButton.icon(
            onPressed: () => setState(() {
              _rowsReady = false;
              _selectedFile = null;
              _unmatchedWarnings = null;
              _years = [];
              _disposeControllers();
              _ctrl = [];
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

  // Largeurs FIXES (plutôt que Flex) : avec beaucoup d'exercices, les
  // colonnes ne doivent pas se comprimer jusqu'à devenir illisibles - le
  // tableau devient plus large que le dialogue et défile horizontalement
  // (voir SingleChildScrollView ci-dessous), en plus du défilement vertical
  // déjà en place au niveau de l'écran de prévisualisation.
  static const _posteColWidth = 220.0;
  static const _yearColWidth = 108.0;

  Widget _buildEditableTable() {
    return Container(
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF13233E) : Colors.white,
        border: Border.all(color: _isDark ? const Color(0xFF304764) : AppTheme.border),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
            columnWidths: {
              0: const FixedColumnWidth(_posteColWidth),
              for (var i = 0; i < _years.length; i++) i + 1: const FixedColumnWidth(_yearColWidth),
            },
            children: [
              _tHeader(),
              for (var fi = 0; fi < _bicFields.length; fi++) _tRow(fi),
            ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: _addYear,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Ajouter un exercice'),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _tHeader() {
    // Rétréci via FittedBox : avec beaucoup d'exercices, chaque colonne
    // devient étroite (largeur flexible) et ce cluster de 3 boutons + année
    // ne doit jamais déborder (cause du RenderFlex overflow observé) - on le
    // laisse donc se redimensionner proportionnellement plutôt que de fixer
    // des tailles qui ne rentrent plus.
    Widget yearCell(int yi) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 11,
                    color: Colors.white70,
                    icon: const Icon(Icons.remove),
                    onPressed: () => _changeYear(yi, -1),
                  ),
                ),
                const SizedBox(width: 2),
                Text('${_years[yi]}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(width: 2),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 11,
                    color: Colors.white70,
                    icon: const Icon(Icons.add),
                    onPressed: () => _changeYear(yi, 1),
                  ),
                ),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 11,
                    color: Colors.white70,
                    icon: const Icon(Icons.close),
                    tooltip: 'Retirer cet exercice',
                    onPressed: () => _removeYear(yi),
                  ),
                ),
              ],
            ),
          ),
        );

    return TableRow(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A518A), Color(0xFF23477A)],
        ),
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Text(
            'Poste',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF5F8FF),
              letterSpacing: 0.18,
            ),
          ),
        ),
        for (var yi = 0; yi < _years.length; yi++) yearCell(yi),
      ],
    );
  }

  TableRow _tRow(int fieldIndex) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border.withValues(alpha: 0.4))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            _bicLabels[fieldIndex],
            style: TextStyle(fontSize: 11.5, color: _text, fontWeight: FontWeight.w600),
          ),
        ),
        for (var yi = 0; yi < _years.length; yi++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: TextField(
              controller: _ctrl[fieldIndex][yi],
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d .,]'))],
              style: TextStyle(fontSize: 12, color: _text),
              decoration: const InputDecoration(
                isDense: true,
                hintText: '0',
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                border: OutlineInputBorder(),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Écran 3 : Résultat ────────────────────────────────────────────────────

  Widget _buildResultScreen() {
    final r = _importResult!;
    final imported = (r['imported'] as List?)?.cast<int>() ?? [];
    final errors = (r['errors'] as List?)?.cast<String>() ?? [];
    final ok = errors.isEmpty;

    return Center(
      child: Container(
        width: 430,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(4),
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
                    ok ? 'Import terminé' : 'Import partiel',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              imported.isEmpty
                  ? 'Aucun exercice mis à jour.'
                  : 'Exercice(s) mis à jour : ${imported.join(', ')}.',
              style: TextStyle(fontSize: 14, color: _text),
            ),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in errors)
                          Text('• $e',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.danger)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, imported.isNotEmpty),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualiser les résultats'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────

Widget _buildFooter() {
    if (_importResult != null) return const SizedBox.shrink();

    final canImport = _rowsReady && _years.isNotEmpty && !_isImporting;

    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _border))),
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (_isImporting) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_importStage, style: TextStyle(fontSize: 11, color: _muted)),
                  const SizedBox(height: 4),
                  const LinearProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ] else
            Expanded(
              child: Text(
                _rowsReady
                    ? 'Vérifiez les années et les valeurs ci-dessus avant d\'enregistrer.'
                    : 'Sélectionnez un fichier pour lancer la lecture.',
                style: TextStyle(fontSize: 11.5, color: _muted),
              ),
            ),
          TextButton(
            onPressed: _isImporting ? null : () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: canImport ? _runImport : null,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.upload_rounded, size: 18),
            label: const Text('Enregistrer dans le formulaire'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Utilitaires visuels ──────────────────────────────────────────────────

  Widget _badge(String label, Color color) => Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      );
}
