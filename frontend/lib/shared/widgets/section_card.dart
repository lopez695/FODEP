// Ce fichier encapsule les blocs de contenu reutilisables.
import 'package:flutter/material.dart';

import '../../core/localization/app_localization.dart';
import '../../core/theme/app_theme.dart';

/// Conteneur visuel standard utilisé pour regrouper un bloc fonctionnel.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.titleStyle,
    this.padding,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title.trim().isNotEmpty || trailing != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? AppTheme.darkBorder : AppTheme.border;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Flexible doit rester enfant direct d'un Flex - on insère le padding à l'intérieur.
        final pad = padding ?? const EdgeInsets.all(AppTheme.spacing);
        Widget content;
        if (child is Flexible) {
          final f = child as Flexible;
          content = Flexible(
            flex: f.flex,
            fit: f.fit,
            child: Padding(padding: pad, child: f.child),
          );
        } else if (constraints.hasBoundedHeight) {
          content = Expanded(child: Padding(padding: pad, child: child));
        } else {
          content = Padding(padding: pad, child: child);
        }

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasHeader) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing,
                    AppTheme.spacing - 2,
                    AppTheme.spacing,
                    AppTheme.spacing - 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: dividerColor, width: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (title.trim().isNotEmpty) ...[
                        Container(
                          width: 3,
                          height: 14,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title.tr(context),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTheme.darkText
                                      : AppTheme.text,
                                  letterSpacing: 0.1,
                                )
                                .merge(titleStyle),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              ],
              content,
            ],
          ),
        );
      },
    );
  }
}
