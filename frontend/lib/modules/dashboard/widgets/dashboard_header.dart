// Ce fichier affiche l'en-tete compact du dashboard.
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import 'dashboard_design.dart';

/// En-tête du dashboard avec date de référence et valorisation.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    this.onReload,
    this.onExport,
  });

  final VoidCallback? onReload;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: _HeaderText()),
          const SizedBox(width: 16),
          _HeaderButton(
            icon: Icons.refresh_rounded,
            label: 'Actualiser',
            onTap: onReload,
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            icon: Icons.download_rounded,
            label: 'Exporter',
            isPrimary: true,
            onTap: onExport,
          ),
        ],
      ),
    );
  }
}

/// Bloc texte interne utilisé dans l'en-tête du dashboard.
class _HeaderText extends StatelessWidget {
  const _HeaderText();

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Tableau de bord'),
          style: TextStyle(
            color: c.ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.0,
          ),
        ),
        Text(
          context.tr(
            'Vue d\'ensemble du portefeuille',
          ),
          style: TextStyle(
            color: c.muted,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    
    return Material(
      color: isPrimary ? c.navy : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: isPrimary ? BorderSide.none : BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isPrimary ? Colors.white : c.navy,
              ),
              const SizedBox(width: 8),
              Text(
                label.tr(context),
                style: TextStyle(
                  color: isPrimary ? Colors.white : c.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
