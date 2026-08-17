import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SharedImportColors {
  const SharedImportColors({
    required this.isDark,
    required this.surface,
    required this.softSurface,
    required this.actionSurface,
    required this.actionText,
    required this.border,
    required this.text,
    required this.muted,
  });

  final bool isDark;
  final Color surface;
  final Color softSurface;
  final Color actionSurface;
  final Color actionText;
  final Color border;
  final Color text;
  final Color muted;

  static SharedImportColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SharedImportColors(
      isDark: isDark,
      surface: isDark ? const Color(0xFF101B31) : Colors.white,
      softSurface: isDark ? const Color(0xFF14233D) : const Color(0xFFF8FAFD),
      actionSurface: isDark ? const Color(0xFF1C2A40) : const Color(0xFFEEF3FA),
      actionText: isDark ? const Color(0xFFF4F7FC) : const Color(0xFF243B63),
      border: isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F5),
      text: isDark ? AppTheme.darkText : AppTheme.text,
      muted: isDark ? AppTheme.darkMuted : AppTheme.muted,
    );
  }
}

class SharedImportDialogCard extends StatelessWidget {
  const SharedImportDialogCard({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.maxHeight = 660,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: colors.isDark ? 0.24 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class SharedImportHeader extends StatelessWidget {
  const SharedImportHeader({
    super.key,
    required this.title,
    this.isImporting = false,
    required this.onClose,
  });

  final String title;
  final bool isImporting;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2F6EEA), Color(0xFF12A7B4)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: const Icon(
              CupertinoIcons.cloud_upload_fill,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isImporting ? null : onClose,
            icon: Icon(
              CupertinoIcons.xmark,
              color: colors.muted,
              size: 20,
            ),
            splashRadius: 19,
          ),
        ],
      ),
    );
  }
}

class SharedImportSectionCard extends StatelessWidget {
  const SharedImportSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Icon(icon, color: AppTheme.accent, size: 14),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 13.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}

class SharedImportDropZone extends StatelessWidget {
  const SharedImportDropZone({
    super.key,
    required this.selectedFile,
    required this.isDragging,
    required this.isInspecting,
    required this.isImporting,
    required this.onPickFile,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onDroppedFiles,
    this.headlineDefault = 'Cliquez pour sélectionner votre fichier',
    this.headlineDragging = 'Relâchez pour charger le fichier',
    this.subtitleDefault = 'Format accepté : .xlsx. Utilisez la sélection de fichier pour importer.',
    this.subtitleInspecting = 'Analyse en cours…',
  });

  final XFile? selectedFile;
  final bool isDragging;
  final bool isInspecting;
  final bool isImporting;
  final VoidCallback onPickFile;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final Future<void> Function(List<XFile> files) onDroppedFiles;
  
  final String headlineDefault;
  final String headlineDragging;
  final String subtitleDefault;
  final String subtitleInspecting;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);
    final selectedName = selectedFile?.name;
    final headline = isDragging ? headlineDragging : headlineDefault;
    final subtitle = isInspecting
        ? subtitleInspecting
        : selectedName == null
            ? subtitleDefault
            : 'Fichier chargé : $selectedName';

    return DropTarget(
      onDragDone: (details) async {
        onDragExited();
        await onDroppedFiles(details.files);
      },
      onDragEntered: (_) {
        if (!isImporting) onDragEntered();
      },
      onDragExited: (_) => onDragExited(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInspecting || isImporting ? null : onPickFile,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: isDragging
                  ? AppTheme.accent.withValues(alpha: 0.045)
                  : colors.softSurface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: isDragging ? AppTheme.accent : colors.border,
                width: isDragging ? 1.25 : 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 760;
                final fileIcon = Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: const Icon(
                    CupertinoIcons.cloud_upload_fill,
                    color: AppTheme.accent,
                    size: 27,
                  ),
                );
                final textBlock = Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 10.8,
                          height: 1.32,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                  ),
                );
                final button = FilledButton.icon(
                  onPressed: isInspecting || isImporting ? null : onPickFile,
                  icon: isInspecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.folder, size: 16),
                  label: Text(
                      isInspecting ? 'Vérification…' : 'Choisir un fichier'),
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: colors.actionSurface,
                    foregroundColor: colors.actionText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 11,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11.2,
                      fontWeight: FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          fileIcon,
                          const SizedBox(width: 4),
                          textBlock,
                        ],
                      ),
                      const SizedBox(height: 3),
                      button,
                    ],
                  );
                }

                return Row(
                  children: [
                    fileIcon,
                    const SizedBox(width: 4),
                    textBlock,
                    const SizedBox(width: 4),
                    button,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SharedSecondaryDropTarget extends StatelessWidget {
  const SharedSecondaryDropTarget({
    super.key,
    required this.isDragging,
    required this.onPickFile,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onDroppedFiles,
    this.headlineDefault = 'Sélectionnez votre fichier ici',
    this.headlineDragging = 'Relâchez pour charger le fichier',
    this.subtitleDefault = 'Cliquez pour choisir un fichier .xlsx',
  });

  final bool isDragging;
  final VoidCallback onPickFile;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final Future<void> Function(List<XFile> files) onDroppedFiles;
  
  final String headlineDefault;
  final String headlineDragging;
  final String subtitleDefault;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);

    return DropTarget(
      onDragDone: (details) async {
        onDragExited();
        await onDroppedFiles(details.files);
      },
      onDragEntered: (_) => onDragEntered(),
      onDragExited: (_) => onDragExited(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPickFile,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 188,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDragging
                  ? AppTheme.accent.withValues(alpha: 0.045)
                  : colors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: isDragging ? AppTheme.accent : colors.border,
                width: isDragging ? 1.25 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.doc_text_fill,
                    color: AppTheme.accent,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isDragging
                      ? headlineDragging
                      : headlineDefault,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 12.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitleDefault,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SharedExpectedActionButton extends StatelessWidget {
  const SharedExpectedActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = SharedImportColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.08)
                : colors.softSurface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: selected
                  ? AppTheme.accent.withValues(alpha: 0.3)
                  : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? AppTheme.accent : colors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.accent : colors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SharedImportFooter extends StatelessWidget {
  const SharedImportFooter({
    super.key,
    required this.isImporting,
    required this.onClose,
    required this.canValidate,
    required this.onRunImport,
    this.centerWidget,
  });

  final bool isImporting;
  final VoidCallback onClose;
  final bool canValidate;
  final VoidCallback onRunImport;
  final Widget? centerWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 3, 5, 4),
      child: Row(
        children: [
          TextButton(
            onPressed: isImporting ? null : onClose,
            child: const Text('Fermer'),
          ),
          const Spacer(),
          if (centerWidget != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: centerWidget!,
            ),
            const SizedBox(width: 3),
          ],
          FilledButton.icon(
            onPressed: canValidate ? onRunImport : null,
            icon: isImporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.play_fill, size: 14),
            label: Text(isImporting ? 'Importation…' : 'Valider'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE1E5EC),
              disabledForegroundColor: const Color(0xFF98A2B3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
