// Ecran d'import des donnees de risque de marche.
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/file_save.dart';
import '../../../shared/widgets/import/shared_import_layout.dart';
import '../services/market_data_import_store.dart';

enum _MarketImportScope { bonds, equities, both }

extension _MarketImportScopeX on _MarketImportScope {
  String get label => switch (this) {
        _MarketImportScope.bonds => 'Obligations',
        _MarketImportScope.equities => 'Actions',
        _MarketImportScope.both => 'Portefeuille complet',
      };

  String get templateFileName => switch (this) {
        _MarketImportScope.bonds => MarketPortfolioType.bonds.templateFileName,
        _MarketImportScope.equities =>
          MarketPortfolioType.equities.templateFileName,
        _MarketImportScope.both =>
          'RiskManagement_Template_Portefeuille_Complet.xlsx',
      };

  IconData get icon => switch (this) {
        _MarketImportScope.bonds => CupertinoIcons.doc_text_fill,
        _MarketImportScope.equities => CupertinoIcons.chart_bar_alt_fill,
        _MarketImportScope.both => CupertinoIcons.square_stack_3d_up_fill,
      };

  Color get accent => switch (this) {
        _MarketImportScope.bonds => AppTheme.accent,
        _MarketImportScope.equities => AppTheme.success,
        _MarketImportScope.both => AppTheme.warning,
      };

  List<MarketPortfolioType> get portfolioTypes => switch (this) {
        _MarketImportScope.bonds => const [MarketPortfolioType.bonds],
        _MarketImportScope.equities => const [MarketPortfolioType.equities],
        _MarketImportScope.both => const [
            MarketPortfolioType.bonds,
            MarketPortfolioType.equities,
          ],
      };

  String get sheetLabel => switch (this) {
        _MarketImportScope.bonds => 'Feuille Saisir donnée',
        _MarketImportScope.equities => 'Feuille Actions',
        _MarketImportScope.both => 'Feuilles Saisir donnée + Actions',
      };
}

Future<bool> showMarketDataImportDialog(BuildContext context) async {
  final successResult = await showDialog<_MarketImportSuccessPayload>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _MarketDataImportDialog(),
  );
  if (successResult == null || !context.mounted) return false;
  await _showMarketDataImportSuccessDialog(context, successResult);
  return true;
}

Future<void> _showMarketDataImportSuccessDialog(
  BuildContext context,
  _MarketImportSuccessPayload result,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        titlePadding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        contentPadding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
        actionsPadding: const EdgeInsets.fromLTRB(6, 8, 6, 5),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: const Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: AppTheme.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 3),
            const Expanded(
              child: Text(
                'Importation réussie',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        content: _MarketImportSuccessContent(result: result),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

class _MarketImportSuccessPayload {
  const _MarketImportSuccessPayload({
    required this.scope,
    required this.mode,
    required this.results,
  });

  final _MarketImportScope scope;
  final String mode;
  final List<MarketImportCommitResult> results;

  bool get isReplacement => mode == 'replace';

  int get previousTitleCount => results.fold<int>(
        0,
        (sum, result) => sum + result.previousRowCount,
      );

  int get newTitleCount => isReplacement
      ? results.fold<int>(0, (sum, result) => sum + result.importedRowCount)
      : results.fold<int>(0, (sum, result) => sum + result.totalRowCount);
}

class _MarketImportSuccessContent extends StatelessWidget {
  const _MarketImportSuccessContent({required this.result});

  final _MarketImportSuccessPayload result;

  @override
  Widget build(BuildContext context) {
    const crimson = Color(0xFFDC143C);
    const indigo = Color(0xFF3730A3);
    const baseStyle = TextStyle(
      height: 1.45,
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      color: Color(0xFF13203A),
    );
    const strongStyle = TextStyle(fontWeight: FontWeight.w800);

    final oldCount = '${result.previousTitleCount}';
    final newCount = '${result.newTitleCount}';

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(
            text: 'La base de données a été mise à jour avec succès.',
          ),
          const TextSpan(text: '\n\n'),
          const TextSpan(text: 'Nombre de titres dans l’ancienne base : '),
          TextSpan(
            text: oldCount,
            style: strongStyle.copyWith(color: crimson),
          ),
          const TextSpan(text: '\n'),
          const TextSpan(text: 'Nombre de titres dans la nouvelle base : '),
          TextSpan(
            text: newCount,
            style: strongStyle.copyWith(color: indigo),
          ),
        ],
      ),
    );
  }
}

class _MarketDataImportDialog extends StatefulWidget {
  const _MarketDataImportDialog();

  @override
  State<_MarketDataImportDialog> createState() =>
      _MarketDataImportDialogState();
}

class _MarketDataImportDialogState extends State<_MarketDataImportDialog> {
  final _store = MarketDataImportStore.instance;

  XFile? _selectedFile;
  Uint8List? _selectedBytes;
  List<MarketImportInspection> _inspections = const [];
  bool _isDragging = false;
  bool _isInspecting = false;
  bool _isImporting = false;
  bool _isDownloadingTemplate = false;
  bool _showExpectedFormat = false;
  _MarketImportScope _scope = _MarketImportScope.bonds;
  String _mode = 'replace';

  Future<void> _pickFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Portefeuille marche', extensions: ['xlsx']),
      ],
    );
    if (file == null) return;
    await _loadFile(file);
  }

  Future<void> _loadFile(XFile file, {bool autoDetectScope = true}) async {
    if (!file.name.toLowerCase().endsWith('.xlsx')) {
      setState(() {
        _selectedFile = file;
        _selectedBytes = null;
        _inspections = const [];
        _isInspecting = false;
      });
      return;
    }

    setState(() {
      _selectedFile = file;
      _selectedBytes = null;
      _inspections = const [];
      _isInspecting = true;
    });

    try {
      final bytes = await file.readAsBytes();
      final previousScope = _scope;
      var effectiveScope = _scope;
      List<MarketImportInspection> inspections;

      if (autoDetectScope) {
        // Détecte le type de portefeuille (Obligations / Actions / complet) à
        // partir des feuilles réellement présentes dans le fichier déposé,
        // plutôt que de dépendre du scope actuellement sélectionné dans la
        // boîte de dialogue - évite de valider un fichier Actions contre la
        // structure Obligations (ou l'inverse) simplement parce que
        // l'utilisateur n'a pas cliqué sur le bon onglet avant de déposer.
        final probes = await Future.wait([
          for (final type in MarketPortfolioType.values)
            _store.inspectWorkbookAsync(bytes, file.name, portfolioType: type),
        ]);
        final bondsFound = probes[MarketPortfolioType.bonds.index].sheetFound;
        final equitiesFound =
            probes[MarketPortfolioType.equities.index].sheetFound;
        effectiveScope = switch ((bondsFound, equitiesFound)) {
          (true, true) => _MarketImportScope.both,
          (true, false) => _MarketImportScope.bonds,
          (false, true) => _MarketImportScope.equities,
          // Aucune des deux feuilles reconnues : conserve le scope choisi
          // pour afficher un message d'erreur cohérent avec celui-ci.
          (false, false) => _scope,
        };
        inspections = [
          for (final type in effectiveScope.portfolioTypes)
            probes[type.index],
        ];
      } else {
        inspections = await Future.wait([
          for (final type in effectiveScope.portfolioTypes)
            _store.inspectWorkbookAsync(
              bytes,
              file.name,
              portfolioType: type,
            ),
        ]);
      }

      if (!mounted) return;
      setState(() {
        _scope = effectiveScope;
        _selectedBytes = bytes;
        _inspections = inspections;
      });
      if (autoDetectScope && effectiveScope != previousScope) {
        _showMessage(
          'Type de portefeuille détecté automatiquement : ${effectiveScope.label}.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectedBytes = null;
        _inspections = const [];
      });
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
      final bytes = _store.buildTemplateWorkbookForTypes(
        portfolioTypes: _scope.portfolioTypes,
      );
      final location = await getSaveLocation(
        suggestedName: _scope.templateFileName,
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
      if (!mounted) return;
      _showMessage('Modèle RiskManagement portefeuille enregistré.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Téléchargement impossible : $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isDownloadingTemplate = false);
      }
    }
  }

  Future<void> _runImport() async {
    final bytes = _selectedBytes;
    final file = _selectedFile;
    final inspections = _inspections;
    if (bytes == null ||
        file == null ||
        inspections.isEmpty ||
        !inspections.every((inspection) => inspection.valid)) {
      return;
    }

    setState(() {
      _isImporting = true;
    });
    try {
      final imported = <MarketImportCommitResult>[];
      for (final type in _scope.portfolioTypes) {
        imported.add(
          await _store.importWorkbookAsync(
            bytes,
            file.name,
            portfolioType: type,
            append: _mode != 'replace',
          ),
        );
      }
      if (!mounted) return;
      final successResult = _MarketImportSuccessPayload(
        scope: _scope,
        mode: _mode,
        results: imported,
      );
      Navigator.of(context).pop(successResult);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Import impossible : $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _changeScope(_MarketImportScope scope) async {
    if (scope == _scope) return;
    final selectedFile = _selectedFile;
    setState(() {
      _scope = scope;
      _selectedBytes = null;
      _inspections = const [];
      _isInspecting = selectedFile != null;
    });
    if (selectedFile != null) {
      // Choix manuel explicite de l'utilisateur : ne pas laisser la
      // détection automatique le réécraser.
      await _loadFile(selectedFile, autoDetectScope: false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 660),
        child: _ImportWorkspaceCard(
          selectedFile: _selectedFile,
          selectedFileSize: _selectedBytes?.lengthInBytes,
          inspections: _inspections,
          isDragging: _isDragging,
          isInspecting: _isInspecting,
          isImporting: _isImporting,
          isDownloadingTemplate: _isDownloadingTemplate,
          showExpectedFormat: _showExpectedFormat,
          scope: _scope,
          mode: _mode,
          onClose: () => Navigator.of(context).maybePop(),
          onPickFile: _pickFile,
          onDownloadTemplate: _downloadTemplate,
          onRunImport: _runImport,
          onToggleExpectedFormat: () {
            setState(() => _showExpectedFormat = !_showExpectedFormat);
          },
          onScopeChanged: _changeScope,
          onModeChanged: (value) => setState(() => _mode = value),
          onDragEntered: () => setState(() => _isDragging = true),
          onDragExited: () => setState(() => _isDragging = false),
          onDroppedFiles: _handleDroppedFiles,
        ),
      ),
    );
  }
}

class _ImportWorkspaceCard extends StatelessWidget {
  const _ImportWorkspaceCard({
    required this.selectedFile,
    required this.selectedFileSize,
    required this.inspections,
    required this.isDragging,
    required this.isInspecting,
    required this.isImporting,
    required this.isDownloadingTemplate,
    required this.showExpectedFormat,
    required this.scope,
    required this.mode,
    required this.onClose,
    required this.onPickFile,
    required this.onDownloadTemplate,
    required this.onRunImport,
    required this.onToggleExpectedFormat,
    required this.onScopeChanged,
    required this.onModeChanged,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onDroppedFiles,
  });

  final XFile? selectedFile;
  final int? selectedFileSize;
  final List<MarketImportInspection> inspections;
  final bool isDragging;
  final bool isInspecting;
  final bool isImporting;
  final bool isDownloadingTemplate;
  final bool showExpectedFormat;
  final _MarketImportScope scope;
  final String mode;
  final VoidCallback onClose;
  final VoidCallback onPickFile;
  final VoidCallback onDownloadTemplate;
  final VoidCallback onRunImport;
  final VoidCallback onToggleExpectedFormat;
  final ValueChanged<_MarketImportScope> onScopeChanged;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final Future<void> Function(List<XFile> files) onDroppedFiles;

  bool get canValidate =>
      !isImporting &&
      !isInspecting &&
      inspections.isNotEmpty &&
      inspections.every((inspection) => inspection.valid);

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);

    return SharedImportDialogCard(
      maxWidth: 1180,
      maxHeight: 660,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SharedImportHeader(
            title: 'Importation de données',
            isImporting: isImporting,
            onClose: onClose,
          ),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ImportPortfolioTypeSelector(
                    value: scope,
                    onChanged: onScopeChanged,
                  ),
                  const SizedBox(height: 4),
                  SharedImportSectionCard(
                    icon: CupertinoIcons.doc_text,
                    title: 'Zone d’import',
                    child: SharedImportDropZone(
                      selectedFile: selectedFile,
                      isDragging: isDragging,
                      isInspecting: isInspecting,
                      isImporting: isImporting,
                      onPickFile: onPickFile,
                      onDragEntered: onDragEntered,
                      onDragExited: onDragExited,
                      onDroppedFiles: onDroppedFiles,
                    ),
                  ),
                  if (inspections.isEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SharedExpectedActionButton(
                          icon: showExpectedFormat
                              ? CupertinoIcons.chevron_up
                              : CupertinoIcons.chevron_down,
                          label: 'Format attendu',
                          selected: showExpectedFormat,
                          onPressed: onToggleExpectedFormat,
                        ),
                        SharedExpectedActionButton(
                          icon: CupertinoIcons.arrow_down_doc,
                          label: isDownloadingTemplate
                              ? 'Préparation du modèle'
                              : 'Télécharger le modèle',
                          onPressed:
                              isDownloadingTemplate ? null : onDownloadTemplate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      child: showExpectedFormat
                          ? _ExpectedWorkbookPanel(
                              key: ValueKey(
                                'expected-format-${scope.name}',
                              ),
                              scope: scope,
                            )
                          : SharedSecondaryDropTarget(
                              key: const ValueKey('secondary-drop-zone'),
                              isDragging: isDragging,
                              onPickFile: onPickFile,
                              onDragEntered: onDragEntered,
                              onDragExited: onDragExited,
                              onDroppedFiles: onDroppedFiles,
                            ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    _FileVerificationPanel(
                      inspections: inspections,
                      fileSize: selectedFileSize ?? 0,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, color: colors.border),
          SharedImportFooter(
            isImporting: isImporting,
            onClose: onClose,
            canValidate: canValidate,
            onRunImport: onRunImport,
            centerWidget: _ImportModeSelector(
              value: mode,
              onChanged: onModeChanged,
            ),
          ),
        ],
      ),
    );
  }
}



class _ExpectedWorkbookPanel extends StatelessWidget {
  const _ExpectedWorkbookPanel({
    super.key,
    required this.scope,
  });

  final _MarketImportScope scope;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);
    final types = scope.portfolioTypes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.softSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scope == _MarketImportScope.both
                ? 'Classeur complet requis'
                : 'Classeur ${scope.label} requis',
            style: TextStyle(
              color: colors.text,
              fontSize: 13.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            scope == _MarketImportScope.both
                ? 'Le fichier importé doit contenir les feuilles Saisir donnée et Actions, avec les colonnes obligatoires de chaque portefeuille.'
                : types.single.expectedDescription,
            style: TextStyle(
              color: colors.muted,
              fontSize: 10.8,
              height: 1.32,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final type in types) ...[
                _ExpectedChip(
                  label: type.sheetName,
                  tone: _ExpectedChipTone.sheet,
                ),
                _ExpectedChip(
                  label:
                      '${type.label} · ${type.requiredHeaders.length} colonnes obligatoires',
                  tone: _ExpectedChipTone.meta,
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          for (final type in types) ...[
            if (types.length > 1) ...[
              Text(
                type.label,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final header in type.requiredHeaders)
                  _ExpectedChip(label: header),
              ],
            ),
            if (type != types.last) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _FileVerificationPanel extends StatelessWidget {
  const _FileVerificationPanel({
    required this.inspections,
    required this.fileSize,
  });

  final List<MarketImportInspection> inspections;
  final int fileSize;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);
    final allValid =
        inspections.isNotEmpty && inspections.every((item) => item.valid);
    final statusColor = allValid ? AppTheme.success : AppTheme.danger;
    final totalRows = inspections.fold<int>(
      0,
      (sum, inspection) => sum + inspection.rowCount,
    );
    final sheetCount = inspections.isEmpty ? 0 : inspections.first.sheetCount;
    final requiredHeadersCount = inspections.fold<int>(
      0,
      (sum, inspection) =>
          sum + inspection.portfolioType.requiredHeaders.length,
    );
    final conformingColumns = inspections.fold<int>(
      0,
      (sum, inspection) {
        final requiredHeaders = inspection.portfolioType.requiredHeaders;
        return sum +
            (inspection.sheetFound
                ? requiredHeaders.length - inspection.missingHeaders.length
                : 0);
      },
    );
    final errors = [
      for (final inspection in inspections) ..._verificationErrors(inspection),
    ];
    final fileName = inspections.isEmpty ? '' : inspections.first.fileName;
    final title = inspections.length > 1
        ? 'Classeur complet · $fileName'
        : '${inspections.first.portfolioType.label} · $fileName';
    final headerSurface =
        colors.isDark ? const Color(0xFF152337) : const Color(0xFFF6F9FD);
    final statSurface =
        colors.isDark ? const Color(0xFF111D30) : const Color(0xFFFBFCFE);

    return SharedImportSectionCard(
      icon: CupertinoIcons.doc_text,
      title: 'Vérification du fichier',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: headerSurface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: colors.border),
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
                          color: colors.muted,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusColor,
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
                  child: Text(
                    allValid ? 'Validé' : 'À corriger',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _VerificationMetricCard(
                  icon: Icons.insert_drive_file_outlined,
                  label: 'Poids',
                  value: _formatFileSize(fileSize),
                  surfaceColor: statSurface,
                ),
                _VerificationMetricCard(
                  icon: Icons.table_rows_rounded,
                  label: 'Expositions',
                  value: '$totalRows',
                  surfaceColor: statSurface,
                ),
                _VerificationMetricCard(
                  icon: Icons.grid_view_rounded,
                  label: 'Feuilles',
                  value: '$sheetCount',
                  surfaceColor: statSurface,
                ),
                _VerificationMetricCard(
                  icon: Icons.fact_check_rounded,
                  label: 'Conformes',
                  value: '$conformingColumns / $requiredHeadersCount',
                  surfaceColor: statSurface,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final inspection in inspections) ...[
                  _VerificationItemChip(
                    label: inspection.portfolioType.label,
                    valid: inspection.valid,
                    detail: inspection.valid
                        ? 'Structure ${inspection.portfolioType.label} conforme.'
                        : 'Structure ${inspection.portfolioType.label} à corriger.',
                  ),
                  _VerificationItemChip(
                    label: inspection.portfolioType.sheetName,
                    valid: inspection.sheetFound,
                    detail: inspection.sheetFound
                        ? 'Feuille présente.'
                        : 'Feuille absente du fichier.',
                  ),
                  for (final header in inspection.portfolioType.requiredHeaders)
                    _VerificationItemChip(
                      label: header,
                      valid: inspection.sheetFound &&
                          !inspection.missingHeaders.contains(header),
                      detail: inspection.sheetFound &&
                              !inspection.missingHeaders.contains(header)
                          ? 'Colonne présente.'
                          : 'Colonne absente du fichier.',
                    ),
                ],
              ],
            ),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 3),
              TextButton.icon(
                onPressed: () => _showVerificationErrors(context, errors),
                icon: const Icon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 15,
                ),
                label: Text('Voir les erreurs (${errors.length})'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  textStyle: const TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerificationMetricCard extends StatelessWidget {
  const _VerificationMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.surfaceColor,
    this.color = AppTheme.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color surfaceColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);
    final showAccentDot = color != AppTheme.accent;

    return Container(
      constraints: const BoxConstraints(minWidth: 118, maxWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 8.9,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: showAccentDot ? color : colors.text,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.15,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (showAccentDot)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      ),
    );
  }
}

class _VerificationItemChip extends StatelessWidget {
  const _VerificationItemChip({
    required this.label,
    required this.valid,
    required this.detail,
  });

  final String label;
  final bool valid;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);
    final iconColor = valid ? AppTheme.success : AppTheme.danger;
    final background = valid
        ? (colors.isDark ? const Color(0xFF13241E) : const Color(0xFFF3FBF7))
        : (colors.isDark ? const Color(0xFF2A191D) : const Color(0xFFFFF5F6));

    return Container(
      constraints: const BoxConstraints(minHeight: 34, maxWidth: 226),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            valid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 13,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 9.35,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                  ),
                ),
                if (!valid) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.muted,
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
}





class _ImportPortfolioTypeSelector extends StatelessWidget {
  const _ImportPortfolioTypeSelector({
    required this.value,
    required this.onChanged,
  });

  final _MarketImportScope value;
  final ValueChanged<_MarketImportScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.softSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          const visibleScopes = [
            _MarketImportScope.bonds,
            _MarketImportScope.equities,
          ];
          final buttons = [
            for (final scope in visibleScopes)
              _ImportPortfolioTypeButton(
                scope: scope,
                selected: value == scope,
                onTap: () => onChanged(scope),
              ),
          ];
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buttons[0],
                const SizedBox(height: 4),
                buttons[1],
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: buttons[0]),
              const SizedBox(width: 4),
              Expanded(child: buttons[1]),
            ],
          );
        },
      ),
    );
  }
}

class _ImportPortfolioTypeButton extends StatelessWidget {
  const _ImportPortfolioTypeButton({
    required this.scope,
    required this.selected,
    required this.onTap,
  });

  final _MarketImportScope scope;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);
    final accent = scope.accent;
    final icon = scope.icon;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color:
                selected ? accent.withValues(alpha: 0.32) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? accent : colors.muted),
            const SizedBox(width: 8),
            Text(
              scope.label,
              style: TextStyle(
                color: selected ? accent : colors.text,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _ImportModeSelector extends StatelessWidget {
  const _ImportModeSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);
    final label =
        value == 'replace' ? 'Remplacer la base' : 'Compléter la base';

    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: '',
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'replace',
          child: _ImportModeMenuItem(
            icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
            label: 'Remplacer la base',
            color: AppTheme.warning,
            colors: colors,
          ),
        ),
        PopupMenuItem(
          value: 'merge',
          child: _ImportModeMenuItem(
            icon: CupertinoIcons.plus_app_fill,
            label: 'Compléter la base',
            color: AppTheme.accent,
            colors: colors,
          ),
        ),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: const Icon(
                CupertinoIcons.tray_arrow_down_fill,
                color: Colors.white,
                size: 13,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Icon(CupertinoIcons.chevron_down, size: 13, color: colors.muted),
          ],
        ),
      ),
    );
  }
}

class _ImportModeMenuItem extends StatelessWidget {
  const _ImportModeMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final Color color;
  final SharedImportColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: colors.isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

List<String> _verificationErrors(MarketImportInspection inspection) {
  final granularErrors = [
    if (!inspection.sheetFound)
      'Feuille "${inspection.portfolioType.sheetName}" absente.',
    for (final header in inspection.missingHeaders) 'Colonne absente : $header',
  ];
  if (granularErrors.isNotEmpty) return granularErrors;
  return [
    for (final error in inspection.errors)
      if (error.trim().isNotEmpty) error,
  ];
}

void _showVerificationErrors(BuildContext context, List<String> errors) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Erreurs détectées'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(addSemanticIndexes: false,
            shrinkWrap: true,
            itemCount: errors.length,
            separatorBuilder: (_, __) => const Divider(height: 14),
            itemBuilder: (context, index) {
              return Text(
                errors[index],
                style: const TextStyle(fontSize: 12),
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

String _formatFileSize(int size) {
  if (size >= 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
  if (size >= 1024) {
    return '${(size / 1024).toStringAsFixed(1)} Ko';
  }
  return '$size o';
}

enum _ExpectedChipTone { header, sheet, meta, success }

class _ExpectedChip extends StatelessWidget {
  const _ExpectedChip({
    required this.label,
    this.tone = _ExpectedChipTone.header,
  });

  final String label;
  final _ExpectedChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);
    final (bg, fg, border) = switch (tone) {
      _ExpectedChipTone.sheet => (
          AppTheme.accent.withValues(alpha: 0.09),
          AppTheme.accent,
          AppTheme.accent.withValues(alpha: 0.18),
        ),
      _ExpectedChipTone.meta => (
          const Color(0xFFFFF7E8),
          const Color(0xFF895100),
          const Color(0xFFFFDDA1),
        ),
      _ExpectedChipTone.success => (
          AppTheme.success.withValues(alpha: 0.08),
          const Color(0xFF0F766E),
          AppTheme.success.withValues(alpha: 0.20),
        ),
      _ExpectedChipTone.header => (
          colors.surface,
          colors.text,
          colors.border,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: border),
      ),
      child: SelectableText(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10.1,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.actionSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colors.muted,
              fontSize: 10.1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}


