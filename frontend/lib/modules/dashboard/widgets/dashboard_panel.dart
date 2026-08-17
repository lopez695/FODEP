// Ce fichier fournit une carte reutilisable pour les sections du dashboard.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import 'dashboard_theme.dart';

/// Carte standard utilisée pour les blocs du dashboard.
class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dashboardPanelColor(isDark),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: dashboardPanelBorder(isDark)),
        boxShadow: dashboardPanelShadow(isDark),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = trailing != null && constraints.maxWidth < 620;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) ...[
                _PanelHeaderText(
                  title: title,
                  subtitle: subtitle,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                trailing!,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PanelHeaderText(
                        title: title,
                        subtitle: subtitle,
                        isDark: isDark,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
              const SizedBox(height: 3),
              child,
            ],
          );
        },
      ),
    );
  }
}

/// Bloc de texte interne utilisé dans l'en-tête des panneaux dashboard.
class _PanelHeaderText extends StatelessWidget {
  const _PanelHeaderText({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.tr(context),
          style: TextStyle(
            color: dashboardTitleColor(isDark),
            fontSize: 14.2,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            height: 1,
          ),
        ),
        if (hasSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            subtitle.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: dashboardSubtitleColor(isDark),
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}
