import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/utils/formatters.dart';
import 'dashboard_design.dart';

/// Masthead du dashboard prudentiel - barre claire raffinée.
///
/// Surface blanche structurée : monogramme navy plein, sur-titre tracé (cadre
/// réglementaire), pastille de conformité (statut = seule couleur), contrôle de
/// date et actions en conteneurs à filet fin.
class DashboardGeneralHeader extends StatelessWidget {
  const DashboardGeneralHeader({
    super.key,
    required this.analysisDate,
    required this.onPickAnalysisDate,
    this.onRefresh,
    this.onExport,
  });

  final DateTime analysisDate;
  final VoidCallback onPickAnalysisDate;
  final VoidCallback? onRefresh;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          bottom: BorderSide(color: c.border, width: Dash.hairline),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tableau de bord'.tr(context),
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  "Vue d'ensemble des indicateurs prudentiels".tr(context),
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _DateControl(
            value: AppFormatters.shortDate(analysisDate),
            onTap: onPickAnalysisDate,
            colors: c,
          ),
          const SizedBox(width: 10),
          _IconButtonBox(
            icon: Icons.file_download_outlined,
            tooltip: 'Exporter',
            onTap: onExport,
            colors: c,
          ),
          const SizedBox(width: 8),
          _IconButtonBox(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onTap: onRefresh,
            colors: c,
          ),
        ],
      ),
    );
  }
}

class _DateControl extends StatelessWidget {
  const _DateControl({
    required this.value,
    required this.onTap,
    required this.colors,
  });

  final String value;
  final VoidCallback onTap;
  final DashColors colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.calendar, size: 15, color: colors.muted),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: Dash.tabular,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.expand_more, size: 16, color: colors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButtonBox extends StatelessWidget {
  const _IconButtonBox({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final DashColors colors;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip.tr(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Icon(icon, size: 17, color: colors.muted),
          ),
        ),
      ),
    );
  }
}
