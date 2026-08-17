import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/import/shared_import_layout.dart';

Future<Map<String, dynamic>?> showExcelImportDialog(
  BuildContext context, {
  required RwaApiService api,
  required Future<void> Function() onImportApplied,
}) {
  return showDialog<Map<String, dynamic>?>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _ExcelImportDialog(
        api: api,
        onImportApplied: onImportApplied,
      );
    },
  );
}

class _ExcelImportDialog extends StatefulWidget {
  const _ExcelImportDialog({
    required this.api,
    required this.onImportApplied,
  });

  final RwaApiService api;
  final Future<void> Function() onImportApplied;

  @override
  State<_ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends State<_ExcelImportDialog> {
  bool _isDragging = false;
  bool _isLoadingSpec = true;
  bool _isInspecting = false;
  bool _isImporting = false;
  bool _isDownloadingTemplate = false;
  bool _showExpectedFormat = false;
  String _mode = 'merge';
  String _importStage = 'Prêt';
  Map<String, dynamic>? _spec;
  Map<String, dynamic>? _inspection;
  XFile? _selectedFile;
  Uint8List? _selectedBytes;

  ThemeData get _theme => Theme.of(context);
  bool get _isDark => _theme.brightness == Brightness.dark;
  Color get _background =>
      _theme.cardTheme.color ?? (_isDark ? AppTheme.darkCard : AppTheme.card);
  Color get _cardSoft =>
      _theme.inputDecorationTheme.fillColor ??
      (_isDark ? const Color(0xFF14233D) : const Color(0xFFFBFCFF));
  Color get _border => _theme.dividerColor;
  Color get _text =>
      _theme.textTheme.bodyLarge?.color ??
      (_isDark ? AppTheme.darkText : AppTheme.text);
  Color get _muted => _isDark ? AppTheme.darkMuted : AppTheme.muted;
  Color get _accent => _theme.colorScheme.primary;
  Color get _success => AppTheme.success;
  Color get _error => AppTheme.danger;

  @override
  void initState() {
    super.initState();
    _loadSpec();
  }

  Future<void> _loadSpec() async {
    setState(() => _isLoadingSpec = true);
    try {
      final spec = await widget.api.fetchExcelImportSpec();
      if (!mounted) return;
      setState(() => _spec = spec);
    } finally {
      if (mounted) {
        setState(() => _isLoadingSpec = false);
      }
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
    final lowerName = file.name.toLowerCase();
    if (!lowerName.endsWith('.xlsx')) {
      _showMessage('Seuls les fichiers .xlsx sont acceptés.', isError: true);
      return;
    }

    setState(() {
      _isInspecting = true;
      _inspection = null;
      _selectedFile = file;
      _selectedBytes = null;
    });

    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedBytes = bytes;
      });
      final inspection = await widget.api.inspectExposureExcelFile(
        bytes,
        file.name,
      );
      if (!mounted) return;
      setState(() {
        _selectedBytes = bytes;
        _inspection = inspection;
      });
    } catch (error) {
      if (mounted) {
        _showMessage('Analyse impossible: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isInspecting = false);
      }
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    await _loadFile(files.first);
  }

  Future<void> _downloadTemplate() async {
    setState(() => _isDownloadingTemplate = true);
    try {
      final bytes = await widget.api.downloadExcelImportTemplate();
      final location = await getSaveLocation(
        suggestedName: 'modele_import_rwa.xlsx',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Excel', extensions: ['xlsx']),
        ],
      );
      if (location == null) return;
      await saveBytesAtLocation(
        location,
        bytes,
        requiredExtension: '.xlsx',
      );
      if (mounted) {
        _showMessage('Modèle Excel enregistré.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Téléchargement impossible: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingTemplate = false);
      }
    }
  }

  Future<void> _runImport() async {
    if (_selectedBytes == null || _selectedFile == null) return;
    final inspection = _inspection;
    if (inspection == null || inspection['valid'] != true) {
      _showMessage(
        'Le fichier doit être valide avant l’import.',
        isError: true,
      );
      return;
    }

    if (_mode == 'replace') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirmer l’écrasement'),
            content: const Text(
              'Les données existantes seront remplacées par celles du fichier importé. Une copie de sauvegarde sera créée automatiquement avant l’opération.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    setState(() {
      _isImporting = true;
      _importStage = 'Lecture et validation';
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (mounted) {
        setState(() => _importStage = 'Enregistrement des données');
      }
      final result = await widget.api.importExposureExcelFile(
        _selectedBytes!,
        _selectedFile!.name,
        mode: _mode,
      );
      if (mounted) {
        setState(() => _importStage = 'Rafraîchissement');
      }
      await widget.onImportApplied();
      if (!mounted) return;
      setState(() => _importStage = 'Finalisé');
      Navigator.of(context).pop(result);
      return;
    } catch (error) {
      if (mounted) {
        _showMessage('Import impossible: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _showErrors(List<dynamic> errors) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Erreurs détectées'),
          content: SizedBox(
            width: 620,
            child: errors.isEmpty
                ? const Text('Aucune erreur.')
                : ListView.separated(addSemanticIndexes: false,
                    shrinkWrap: true,
                    itemCount: errors.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = Map<String, dynamic>.from(
                        errors[index] as Map,
                      );
                      final sheet = item['sheet'] ?? '-';
                      final row = item['row'];
                      final column = item['column'];
                      final message = item['message'] ?? '';
                      return Text(
                        '$sheet'
                        '${row != null ? ' • ligne $row' : ''}'
                        '${column != null ? ' • $column' : ''}\n'
                        '$message',
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? _error : _success,
        content: Text(message),
      ),
    );
  }

  Future<void> _copyLabel(String value, {required String kind}) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showMessage('$kind copié : $value');
  }

  @override
  Widget build(BuildContext context) {
    final inspection = _inspection;
    final errors = inspection?['errors'] as List<dynamic>? ?? const [];
    final selectedName = _selectedFile?.name ?? 'Aucun fichier';
    final selectedSize = _selectedBytes == null
        ? '-'
        : '${(_selectedBytes!.lengthInBytes / 1024).toStringAsFixed(1)} Ko';
    final showInspectionPanel = _selectedFile != null;
    final canImport = !_isImporting &&
        !_isInspecting &&
        _selectedBytes != null &&
        inspection?['valid'] == true;

    return SharedImportDialogCard(
      maxWidth: 1120,
      maxHeight: 660,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SharedImportHeader(
            title: 'Importation de données',
            isImporting: _isImporting,
            onClose: () => Navigator.of(context).pop(),
          ),
          Divider(height: 1, color: _border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImportZone(),
                  const SizedBox(height: 4),
                  if (showInspectionPanel) ...[
                    SharedImportSectionCard(
                      key: const ValueKey('inspection_panel'),
                      icon: CupertinoIcons.check_mark_circled,
                      title: 'Vérification du fichier',
                      child: _buildInspectionPanel(
                        fileName: selectedName,
                        fileSize: selectedSize,
                        inspection: inspection,
                        errors: errors,
                        isInspecting: _isInspecting,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  _buildExpectedFormatSection(
                    key: ValueKey(
                      showInspectionPanel
                          ? 'expected_format_under_inspection'
                          : 'expected_format_panel',
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_isImporting)
                    SharedImportSectionCard(
                      icon: CupertinoIcons.arrow_2_circlepath,
                      title: 'Importation en cours',
                      child: _buildImportProgress(),
                    ),
                  if (_isImporting) const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: _border),
          SharedImportFooter(
            isImporting: _isImporting,
            onClose: () => Navigator.of(context).pop(),
            canValidate: canImport,
            onRunImport: _runImport,
            centerWidget: _buildInlineModeSelector(),
          ),
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
        isInspecting: _isInspecting,
        isImporting: _isImporting,
        onPickFile: _pickFile,
        onDragEntered: () {
          if (!_isImporting) {
            setState(() => _isDragging = true);
          }
        },
        onDragExited: () {
          if (mounted) {
            setState(() => _isDragging = false);
          }
        },
        onDroppedFiles: (files) async {
          if (mounted) {
            setState(() => _isDragging = false);
          }
          await _handleDroppedFiles(files);
        },
      ),
    );
  }

  Widget _buildImportHintChip({
    required IconData icon,
    required String label,
  }) {
    final chipBackground =
        _isDark ? const Color(0xFF1A2638) : const Color(0xFFF2F6FB);
    final chipForeground =
        _isDark ? const Color(0xFFC9D6EA) : const Color(0xFF5B6A81);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: chipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: chipForeground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: chipForeground,
              fontSize: 10.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
                    onDragDone: (details) async {
                      if (mounted) {
                        setState(() => _isDragging = false);
                      }
                      await _handleDroppedFiles(details.files);
                    },
                    onDragEntered: (_) {
                      if (!_isImporting) {
                        setState(() => _isDragging = true);
                      }
                    },
                    onDragExited: (_) {
                      if (mounted) {
                        setState(() => _isDragging = false);
                      }
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isInspecting || _isImporting ? null : _pickFile,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        child: AnimatedContainer(
                          width: double.infinity,
                          height: 178,
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: _isDragging
                                ? Color.lerp(_background, _accent, 0.05)
                                : _background,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius,
                            ),
                            border: Border.all(
                              color: _isDragging ? _accent : _border,
                              width: _isDragging ? 1.3 : 1,
                            ),
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
                                    color: _isDragging
                                        ? _accent.withValues(alpha: 0.14)
                                        : _accent.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius,
                                    ),
                                    border: Border.all(
                                      color: _accent.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Icon(
                                    _isDragging
                                        ? Icons.file_download_done_rounded
                                        : Icons.upload_file_rounded,
                                    color: _accent,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _isDragging
                                      ? 'Relâchez pour charger le fichier'
                                      : 'Sélectionnez votre fichier ici',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _text,
                                    fontSize: 12.2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Cliquez pour choisir un fichier .xlsx',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 10.6,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                        decoration: BoxDecoration(
                          color: _background,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: _border),
                        ),
                        child: _buildExpectedFormat(),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildExpectedFormat() {
    final spec = _spec;
    if (_isLoadingSpec) {
      return const Padding(
        padding: EdgeInsets.all(3),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }
    final rawSheets = spec?['sheets'] as List<dynamic>? ?? const [];
    final sheets = rawSheets
        .map((sheet) => Map<String, dynamic>.from(sheet as Map))
        .toList();
    final detailedSheets = sheets.where((sheet) {
      final columns = sheet['required_columns'] as List<dynamic>? ?? const [];
      return columns.isNotEmpty;
    }).toList();
    final notes = spec?['notes'] as List<dynamic>? ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sheets.isNotEmpty) _buildWorkbookSummaryCard(sheets),
        if (detailedSheets.isNotEmpty) ...[
          const SizedBox(height: 3),
          for (final sheet in detailedSheets) _buildSheetSpecTile(sheet),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _cardSoft,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consignes',
                  style: TextStyle(
                    color: _text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $note',
                      style: TextStyle(color: _muted, fontSize: 10.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWorkbookSummaryCard(List<Map<String, dynamic>> sheets) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final order = ['Saisie', 'Support', 'Référentiel', 'Paramétrage'];
    for (final sheet in sheets) {
      final role = sheet['role']?.toString() ?? 'Référentiel';
      grouped.putIfAbsent(role, () => <Map<String, dynamic>>[]).add(sheet);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _cardSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
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
            '${sheets.length} feuilles doivent être présentes et conservées dans le fichier importé.',
            style: TextStyle(color: _muted, fontSize: 10.2),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final role in order)
                for (final sheet
                    in grouped[role] ?? const <Map<String, dynamic>>[])
                  _buildSheetNameChip(
                    sheet,
                    backgroundColor: _workbookGroupChip(role),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSheetNameChip(
    Map<String, dynamic> sheet, {
    required Color backgroundColor,
  }) {
    final sheetName = sheet['name']?.toString() ?? '';
    return Tooltip(
      message: 'Cliquer pour copier le nom de la feuille',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _copyLabel(sheetName, kind: 'Feuille'),
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(5),
              border:
                  Border.all(color: backgroundColor.withValues(alpha: 0.78)),
            ),
            child: Text(
              sheetName,
              style: TextStyle(
                color: _text,
                fontSize: 9.7,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _workbookGroupChip(String role) {
    switch (role) {
      case 'Saisie':
        return const Color(0xFFEDF2FB);
      case 'Support':
        return const Color(0xFFF6F0E4);
      case 'Référentiel':
        return const Color(0xFFEAF5EE);
      case 'Paramétrage':
        return const Color(0xFFF0EAF9);
      default:
        return _background;
    }
  }

  Widget _buildSheetSpecTile(Map<String, dynamic> sheet) {
    final requiredColumns =
        sheet['required_columns'] as List<dynamic>? ?? const [];
    final requiredMarkers =
        sheet['required_markers'] as List<dynamic>? ?? const [];
    final sheetNotes = sheet['notes'] as List<dynamic>? ?? const [];
    final role = sheet['role']?.toString() ?? 'Saisie';

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _cardSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                sheet['name']?.toString() ?? '',
                style: TextStyle(
                  color: _text,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    color: _text,
                    fontSize: 9.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sheet['description']?.toString() ?? '',
            style: TextStyle(color: _muted, fontSize: 10.2),
          ),
          const SizedBox(height: 8),
          if (requiredColumns.isNotEmpty)
            _buildColumnGroup(
              title: 'Colonnes attendues',
              count: requiredColumns.length,
              items: requiredColumns,
              color: _accent,
            ),
          if (requiredMarkers.isNotEmpty) ...[
            if (requiredColumns.isNotEmpty) const SizedBox(height: 8),
            _buildMarkerGroup(
              title: 'Repères attendus',
              items: requiredMarkers,
              color: AppTheme.success,
            ),
          ],
          if (sheetNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final note in sheetNotes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${note.toString()}',
                  style: TextStyle(color: _muted, fontSize: 10.0),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarkerGroup({
    required String title,
    required List<dynamic> items,
    required Color color,
  }) {
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
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: _text,
                  fontSize: 9.9,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${items.length})',
                style: TextStyle(
                  color: _muted,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: items
                .map((item) => _buildMarkerChip(item.toString(), color))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerChip(String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: _text,
          fontSize: 9.15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildColumnGroup({
    required String title,
    required int count,
    required List<dynamic> items,
    required Color color,
  }) {
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
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: _text,
                  fontSize: 9.9,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: TextStyle(
                  color: _muted,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Ordre attendu dans la feuille',
            style: TextStyle(
              color: _muted,
              fontSize: 8.9,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: items.asMap().entries.map((entry) {
              final item = Map<String, dynamic>.from(entry.value as Map);
              return _buildColumnItem(
                order: entry.key + 1,
                name: item['name']?.toString() ?? '',
                type: item['type']?.toString() ?? '',
                color: color,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnItem({
    required int order,
    required String name,
    required String type,
    required Color color,
  }) {
    return Tooltip(
      message: 'Cliquer pour copier le nom de la colonne',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _copyLabel(name, kind: 'Colonne'),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$order',
                    style: TextStyle(
                      color: color,
                      fontSize: 8.1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: name,
                        style: TextStyle(
                          color: _text,
                          fontSize: 9.15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: ' · $type',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 8.85,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInspectionPanel({
    required String fileName,
    required String fileSize,
    required Map<String, dynamic>? inspection,
    required List<dynamic> errors,
    required bool isInspecting,
  }) {
    final sheetCount = inspection?['sheet_count'] ?? 0;
    final sheets = inspection?['sheets'] as List<dynamic>? ?? const [];
    final rowsReadBySheet = Map<String, dynamic>.from(
      inspection?['rows_read_by_sheet'] as Map? ?? const <String, dynamic>{},
    );
    final templateExposureCount =
        rowsReadBySheet['Template données'] as int? ?? 0;
    final validSheets = sheets.where((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return map['exists'] == true &&
          (map['missing_required_columns'] as List<dynamic>? ?? const [])
              .isEmpty &&
          (map['missing_required_markers'] as List<dynamic>? ?? const [])
              .isEmpty;
    }).length;
    final statusText = isInspecting
        ? 'Analyse en cours'
        : inspection?['valid'] == true
            ? 'Validé'
            : 'À corriger';
    final statusColor = isInspecting
        ? _accent
        : inspection?['valid'] == true
            ? _success
            : _error;
    final fileNameColor = isInspecting
        ? _text
        : inspection?['valid'] == true
            ? _success
            : _error;
    final headerSurface =
        _isDark ? const Color(0xFF152337) : const Color(0xFFF6F9FD);
    final statSurface =
        _isDark ? const Color(0xFF111D30) : const Color(0xFFFBFCFE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: headerSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Classeur analysé',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fileNameColor,
                            fontSize: 13.2,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInspectionStatCard(
                    label: 'Poids',
                    value: fileSize,
                    surfaceColor: statSurface,
                    icon: Icons.insert_drive_file_outlined,
                  ),
                  _buildInspectionStatCard(
                    label: 'Expositions',
                    value: '$templateExposureCount',
                    surfaceColor: statSurface,
                    icon: Icons.table_rows_rounded,
                  ),
                  _buildInspectionStatCard(
                    label: 'Feuilles',
                    value: '$sheetCount',
                    surfaceColor: statSurface,
                    icon: Icons.grid_view_rounded,
                  ),
                  _buildInspectionStatCard(
                    label: 'Conformes',
                    value: '$validSheets / ${sheets.length}',
                    surfaceColor: statSurface,
                    icon: Icons.fact_check_rounded,
                    accentColor: statusColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        if (inspection == null && isInspecting)
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 3),
              Text(
                'Analyse du fichier en cours…',
                style: TextStyle(color: _muted, fontSize: 10.8),
              ),
            ],
          )
        else if (inspection == null)
          Text(
            'Sélectionnez un fichier pour lancer la vérification.',
            style: TextStyle(color: _muted, fontSize: 10.8),
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final cardMaxWidth = constraints.maxWidth >= 1500
                  ? 228.0
                  : constraints.maxWidth >= 1180
                      ? 216.0
                      : constraints.maxWidth >= 900
                          ? 208.0
                          : constraints.maxWidth >= 620
                              ? 198.0
                              : constraints.maxWidth;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final rawSheet in sheets)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: cardMaxWidth),
                      child: _buildSheetCheckRow(
                        Map<String, dynamic>.from(rawSheet as Map),
                      ),
                    ),
                ],
              );
            },
          ),
          if (errors.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showErrors(errors),
                icon: const Icon(Icons.error_outline, size: 14),
                label: Text('Voir les erreurs (${errors.length})'),
                style: TextButton.styleFrom(foregroundColor: _error),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildInspectionStatCard({
    required String label,
    required String value,
    required Color surfaceColor,
    required IconData icon,
    Color? accentColor,
  }) {
    final tone = accentColor ?? (_isDark ? const Color(0xFF9AB4D8) : _accent);
    return Container(
      constraints: const BoxConstraints(minWidth: 118, maxWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              size: 14,
              color: tone,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _muted,
                  fontSize: 8.9,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: accentColor ?? _text,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.15,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (accentColor != null)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSheetCheckRow(Map<String, dynamic> sheet) {
    final missingMarkers =
        sheet['missing_required_markers'] as List<dynamic>? ?? const [];
    final ok = sheet['exists'] == true &&
        (sheet['missing_required_columns'] as List<dynamic>? ?? const [])
            .isEmpty &&
        missingMarkers.isEmpty;
    final missingRequired =
        sheet['missing_required_columns'] as List<dynamic>? ?? const [];
    final surfaceColor = ok
        ? (_isDark ? const Color(0xFF13241E) : const Color(0xFFF3FBF7))
        : (_isDark ? const Color(0xFF2A191D) : const Color(0xFFFFF5F6));
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 13,
            color: ok ? _success : _error,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sheet['name']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 9.35,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                  ),
                ),
                if (!ok) ...[
                  const SizedBox(height: 2),
                  Text(
                    sheet['exists'] == true
                        ? [
                            if (missingRequired.isNotEmpty)
                              'Colonnes manquantes: ${missingRequired.join(', ')}',
                            if (missingMarkers.isNotEmpty)
                              'Repères manquants: ${missingMarkers.join(', ')}',
                          ].join(' | ')
                        : 'Feuille absente du fichier.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 8.15,
                      height: 1.05,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineModeSelector() {
    final selectedLabel =
        _mode == 'replace' ? 'Remplacer la base' : 'Compléter la base';
    final selectedIcon = _mode == 'replace'
        ? Icons.restart_alt_rounded
        : Icons.playlist_add_check_circle_outlined;
    final selectedAccent = _modeAccentColor(_mode);

    return PopupMenuButton<String>(
      enabled: !_isImporting,
      initialValue: _mode,
      onSelected: (value) => setState(() => _mode = value),
      tooltip: 'Choisir le mode d’import',
      color: _background,
      surfaceTintColor: _background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(color: _border),
      ),
      itemBuilder: (context) => [
        _buildModeMenuItem(
          value: 'merge',
          icon: Icons.playlist_add_check_circle_outlined,
          title: 'Compléter la base',
          subtitle:
              'Ajoute les nouvelles lignes et met à jour les IDs existants.',
        ),
        _buildModeMenuItem(
          value: 'replace',
          icon: Icons.restart_alt_rounded,
          title: 'Remplacer la base',
          subtitle:
              'Écrase les données actuelles par celles du fichier importé.',
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7.0),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: selectedAccent,
              elevation: 1,
              shadowColor: selectedAccent.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedAccent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(selectedIcon, color: Colors.white, size: 13.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              selectedLabel,
              style: TextStyle(
                color: _text,
                fontSize: 10.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              color: _muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildModeMenuItem({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _mode == value;
    final accent = _modeAccentColor(value);
    return PopupMenuItem<String>(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        constraints: const BoxConstraints(minWidth: 230, maxWidth: 230),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? accent.withValues(alpha: 0.16) : _cardSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                icon,
                color: selected ? accent : _muted,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _text,
                      fontSize: 10.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9.4,
                      fontWeight: FontWeight.w500,
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

  Color _modeAccentColor(String mode) {
    return mode == 'replace'
        ? const Color(0xFFD94164)
        : const Color(0xFF245BDB);
  }

  Widget _buildImportProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(minHeight: 4),
        const SizedBox(height: 3),
        Text(
          _importStage,
          style: TextStyle(
            color: _text,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Importation en cours… Merci de patienter.',
          style: TextStyle(color: _muted, fontSize: 10.8),
        ),
      ],
    );
  }

}
