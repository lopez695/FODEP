import sys
import re

content = open('C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/frontend/lib/modules/risque_operationnel/widgets/ro_import_pertes_dialog.dart', 'r', encoding='utf-8').read()

# 1. Update Dialog border radius to 3
content = re.sub(r'borderRadius: BorderRadius\.circular\(4\)', 'borderRadius: BorderRadius.circular(3)', content, count=1)

# 2. Update _buildHeader gradient
new_header = r'''Widget _buildHeader() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.indigo, Colors.blue.shade900],
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_upload,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Importation de données (Risque Opérationnel)',
              style: TextStyle(
                color: _text,
                fontSize: 19,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: _muted),
            onPressed: () => Navigator.pop(context, false),
            tooltip: 'Fermer',
          ),
        ],
      );'''

content = re.sub(r'Widget _buildHeader\(\) => Row\([\s\S]*?\](?:,)?\n      \);', new_header, content, count=1)

# 3. Replace _buildDropZoneScreen up to _buildPreviewScreen
start_idx = content.find('  Widget _buildDropZoneScreen() {')
end_idx = content.find('  // ─── Écran 2 : Prévisualisation')

replacement = r'''  bool _showExpectedFormat = true;

  Widget _buildDropZoneScreen() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImportZone(),
          const SizedBox(height: 4),
          _buildExpectedFormatSection(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: !_showExpectedFormat && _selectedFile == null
                ? Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: _buildEmptyStatePlaceholder(),
                  )
                : const SizedBox.shrink(),
          ),
          if (_parseError != null)
            _buildParseErrorContent(),
          const SizedBox(height: 12),
          _buildModeSelector(),
        ],
      ),
    );
  }

  Widget _buildImportZone() {
    final zoneBackground = _isDark ? const Color(0xFF121C2B) : const Color(0xFFF8FAFD);
    final zoneBorder = _isDragging ? _accent : (_isDark ? const Color(0xFF2A3850) : const Color(0xFFDCE5F0));
    final zoneIconBackground = _isDragging ? Color.lerp(zoneBackground, _accent, 0.32)! : (_isDark ? const Color(0xFF21314A) : const Color(0xFFE8EEF8));
    final zoneIconColor = _isDragging ? Colors.white : (_isDark ? const Color(0xFFD9E5FA) : _accent);
    final actionBackground = _isDark ? const Color(0xFF1C2A40) : const Color(0xFFEEF3FA);
    final actionForeground = _isDark ? const Color(0xFFF4F7FC) : const Color(0xFF2A436A);
    final selectedFileName = _selectedFile?.name;
    final headline = _isDragging ? 'Relâchez pour charger le fichier' : 'Cliquez pour sélectionner votre fichier';
    final subtitle = _isParsing ? 'Lecture du fichier en cours…' : selectedFileName != null ? 'Fichier chargé : $selectedFileName' : 'Format accepté : .xlsx. Utilisez la sélection de fichier pour importer.';

    return DropTarget(
      onDragDone: (d) async {
        setState(() => _isDragging = false);
        if (d.files.isNotEmpty) await _loadFile(d.files.first);
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: _buildSectionCard(
        icon: Icons.upload_file_outlined,
        title: 'Zone d’import',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isParsing || _isImporting ? null : _pickFile,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: _isDragging ? Color.lerp(zoneBackground, _accent, 0.09) : zoneBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: zoneBorder, width: _isDragging ? 1.3 : 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isDark ? 0.12 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 860;
                  final summary = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Text(
                          headline,
                          key: ValueKey<String>(headline),
                          style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: -0.1),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 11, height: 1.3, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _buildImportHintChip(icon: Icons.ads_click_rounded, label: 'Sélection manuelle'),
                          _buildImportHintChip(icon: Icons.description_outlined, label: '.xlsx'),
                        ],
                      ),
                    ],
                  );

                  final actionButton = FilledButton.icon(
                    onPressed: _isParsing || _isImporting ? null : _pickFile,
                    icon: _isParsing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Icon(Icons.folder_open_rounded, size: 16),
                    label: Text(_isParsing ? 'Lecture…' : 'Choisir un fichier'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      elevation: 0,
                      backgroundColor: actionBackground,
                      foregroundColor: actionForeground,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      textStyle: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  );

                  final iconBadge = Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(color: zoneIconBackground, borderRadius: BorderRadius.circular(8)),
                    child: Icon(_isDragging ? Icons.file_download_done_rounded : Icons.cloud_upload_rounded, color: zoneIconColor, size: 24),
                  );

                  return isCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [iconBadge, const SizedBox(width: 3), Expanded(child: summary)],
                            ),
                            const SizedBox(height: 3),
                            actionButton,
                          ],
                        )
                      : Row(
                          children: [
                            iconBadge, const SizedBox(width: 4), Expanded(child: summary), const SizedBox(width: 4), actionButton,
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpectedFormatSection({Key? key}) {
    final buttonBackground = _isDark ? const Color(0xFF243027) : const Color(0xFFF3F1EA);
    final buttonBorder = _isDark ? const Color(0xFF3D5344) : const Color(0xFFE0D8C9);
    final buttonForeground = _isDark ? const Color(0xFFF4F7F3) : const Color(0xFF2E3740);
    final downloadBackground = _isDark ? const Color(0xFF1D2635) : const Color(0xFFF1F4F8);
    final downloadBorder = _isDark ? const Color(0xFF334257) : const Color(0xFFD7E0EA);
    final downloadForeground = _isDark ? const Color(0xFFF2F6FC) : const Color(0xFF263445);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 156,
              height: 34,
              child: FilledButton.icon(
                onPressed: () => setState(() => _showExpectedFormat = !_showExpectedFormat),
                icon: Icon(_showExpectedFormat ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16),
                label: const Text('Format attendu'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: buttonBackground,
                  foregroundColor: buttonForeground,
                  elevation: 0,
                  alignment: Alignment.centerLeft,
                  textStyle: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w500),
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: BorderSide(color: buttonBorder)),
                ),
              ),
            ),
            const SizedBox(width: 3),
            SizedBox(
              width: 182,
              height: 34,
              child: FilledButton.icon(
                onPressed: _isDownloadingTemplate ? null : _downloadTemplate,
                icon: _isDownloadingTemplate
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined, size: 15),
                label: const Text('Télécharger le modèle'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: downloadBackground,
                  foregroundColor: downloadForeground,
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w500),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: BorderSide(color: downloadBorder)),
                ),
              ),
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
          Text(
            'Structure requise',
            style: TextStyle(
              color: _text,
              fontSize: 11.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Un classeur simple. Le fichier peut venir du modèle ou d\'un export interne, tant que les champs essentiels sont présents.',
            style: TextStyle(color: _muted, fontSize: 10.2, height: 1.3),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _buildSheetNameChip('Export Interne', backgroundColor: const Color(0xFFF0EAF9)),
              _buildSheetNameChip('Modèle Excel', backgroundColor: const Color(0xFFEDF2FB)),
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
              Text(
                'Données de pertes',
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
            'Lignes d\'incidents (en-têtes en ligne 1 ou 2).',
            style: TextStyle(color: _muted, fontSize: 10.2),
          ),
          const SizedBox(height: 8),
          _buildColumnGroup(
            title: 'Colonnes obligatoires',
            count: 5,
            items: ['Date d’occurrence', 'Description', 'Ligne de métier', 'Type d’événement', 'Perte brute'],
            color: _accent,
          ),
          const SizedBox(height: 4),
          _buildColumnGroup(
            title: 'Colonnes optionnelles',
            count: 3,
            items: ['Cause', 'Perte récupérée', 'Statut'],
            color: _muted,
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

  Widget _buildSectionCard({required IconData icon, required String title, required Widget child, Key? key}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2736) : Colors.white;
    final headerBg = isDark ? const Color(0xFF161F2E) : const Color(0xFFF9FAFC);

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: _text),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
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
              _parseError!,
              style: const TextStyle(color: AppTheme.danger, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
'''

content = content[:start_idx] + replacement + '\n\n' + content[end_idx:]

new_footer = r'''Widget _buildFooter() {
    if (_importResult != null) return const SizedBox.shrink();

    final canImport =
        _parsedRows != null && _validRows.isNotEmpty && !_isImporting;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (_isImporting) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_importStage,
                      style: TextStyle(fontSize: 11, color: _muted)),
                  const SizedBox(height: 4),
                  const LinearProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ] else
            Expanded(
              child: Text(
                _parsedRows == null
                    ? 'Sélectionnez un fichier pour lancer le contrôle.'
                    : '${_validRows.length} ligne(s) prête(s), ${_errorRows.length} à corriger ou ignorer.',
                style: TextStyle(fontSize: 11.5, color: _muted),
              ),
            ),
          TextButton(
            onPressed:
                _isImporting ? null : () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: canImport ? _runImport : null,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_rounded, size: 18),
            label: Text(
              _parsedRows == null
                  ? 'Importer'
                  : 'Importer ${_validRows.length} incident(s)',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ],
      ),
    );
  }'''
start_footer = content.find('  Widget _buildFooter() {')
end_footer = content.find('  // ─── Utilitaires visuels')
content = content[:start_footer] + new_footer + '\n\n' + content[end_footer:]

open('C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/frontend/lib/modules/risque_operationnel/widgets/ro_import_pertes_dialog.dart', 'w', encoding='utf-8').write(content)
print('Success ro_import_pertes_dialog.dart')
