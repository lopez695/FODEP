// Panneau de décision de pilotage - réutilisable dans les onglets
// A1 (AIB), A2 (AS) et B1 (BIC/Pilotage interne) du Dispositif UEMOA.
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/ro_models.dart';
import 'ro_criteres_dashboard.dart';

class DecisionPanel extends StatefulWidget {
  const DecisionPanel({super.key, required this.loader});

  /// Fonction de chargement de l'analyse - appelée à l'initialisation et
  /// à chaque rafraîchissement manuel.
  final Future<DecisionPilotageResult> Function() loader;

  @override
  State<DecisionPanel> createState() => _DecisionPanelState();
}

class _DecisionPanelState extends State<DecisionPanel> {
  DecisionPilotageResult? _decision;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await widget.loader();
      if (mounted) setState(() { _decision = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _niveauColor(String niveau) {
    switch (niveau) {
      case 'Maîtrisé': return AppTheme.success;
      case 'Sous surveillance': return const Color(0xFFF59E0B);
      case 'Vigilance renforcée': return const Color(0xFFEA580C);
      default: return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkMuted : AppTheme.muted;

    if (_loading && _decision == null) {
      return const SectionCard(
        title: 'Décision de pilotage - Analyse et reporting (UEMOA)',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null && _decision == null) {
      return SectionCard(
        title: 'Décision de pilotage - Analyse et reporting (UEMOA)',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Impossible de charger l\'analyse de pilotage',
              style: Theme.of(context).textTheme.bodyMedium),
          AppSpacing.gapXs,
          Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
          AppSpacing.gapSm,
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ),
        ]),
      );
    }

    final d = _decision!;
    final color = _niveauColor(d.niveauGlobal);

    return SectionCard(
      title: 'Décision de pilotage - Analyse et reporting (UEMOA)',
      trailing: IconButton(
        icon: const Icon(Icons.refresh, size: 18),
        tooltip: 'Rafraîchir l\'analyse',
        onPressed: _loading ? null : _load,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Verdict global ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.shield_outlined, color: color, size: 20),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(d.niveauGlobal,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Score ${d.scoreGlobal}/${d.scoreMax}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w700)),
              ),
            ]),
            AppSpacing.gapSm,
            Text(d.synthese, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
          ]),
        ),
        AppSpacing.gapSm,

        // ── Organe de reporting ──────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.account_balance_outlined, size: 16, color: AppTheme.accent),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Organe de reporting recommandé (Art. 313.b)',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(d.organeReporting,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(d.organeReportingMotif,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
            ]),
          ),
        ]),
        AppSpacing.gapSm,
        Divider(height: 1, color: isDark ? AppTheme.darkBorder : AppTheme.border),
        AppSpacing.gapSm,

        // ── Critères d'analyse - dashboard de cartes ─────────────────────────
        RoCriteresDashboard(criteres: d.criteres, embedded: true),
        AppSpacing.gapSm,

        Divider(height: 1, color: isDark ? AppTheme.darkBorder : AppTheme.border),
        AppSpacing.gapSm,

        // ── Recommandations ──────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.checklist_outlined, size: 16, color: AppTheme.accent),
          AppSpacing.hGapSm,
          Text('Recommandations',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        AppSpacing.gapXs,
        ...d.recommandations.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.arrow_right, size: 16, color: muted),
            Expanded(child: Text(r, style: Theme.of(context).textTheme.bodySmall)),
          ]),
        )),
        AppSpacing.gapXs,
        Text('Analyse générée le ${d.dateAnalyse}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted, fontSize: 10)),
      ]),
    );
  }
}
