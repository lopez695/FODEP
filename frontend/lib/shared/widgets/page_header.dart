// Ce fichier affiche l'en-tete reutilisable des pages.
import 'package:flutter/material.dart';

import '../../core/localization/app_localization.dart';
import '../../core/theme/app_theme.dart';

/// En-tête simple de page avec titre et sous-titre.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleFontSize,
    this.subtitleFontSize,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.subtitleSuffix,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double? titleFontSize;
  final double? subtitleFontSize;
  final CrossAxisAlignment crossAxisAlignment;
  final Widget? subtitleSuffix;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppTheme.darkText : AppTheme.text;
    final subtitleColor = isDark ? AppTheme.darkMuted : AppTheme.muted;

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.tr(context),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      fontSize: titleFontSize,
                    ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        subtitle!.tr(context),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: subtitleColor,
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    if (subtitleSuffix != null) ...[
                      const SizedBox(width: 6),
                      subtitleSuffix!,
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
