// Écran provisoire affiché pour les modules en cours de développement.
import 'package:flutter/material.dart';

import '../../core/localization/app_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Message institutionnel « module en construction », commun aux sections
/// dont le contenu n'est pas encore livré (Stress Test, ICAAP, Capital
/// Planning…).
class UnderConstructionScreen extends StatelessWidget {
  const UnderConstructionScreen({super.key, required this.title});

  /// Nom du module tel qu'affiché dans la navigation.
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navy = isDark ? const Color(0xFF8FA3C4) : AppColors.sidebar;
    final ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F1B2D);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6577);
    final border = isDark ? const Color(0xFF24304A) : const Color(0xFFE3E7EE);
    final surface = isDark ? const Color(0xFF111827) : Colors.white;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 44),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border, width: 0.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.engineering_outlined, size: 44, color: navy),
              const SizedBox(height: 18),
              Text(
                title.tr(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Module en construction'.tr(context),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: navy,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cette section sera disponible dans une prochaine version.'
                    .tr(context),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
