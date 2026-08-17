import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../models/ro_models.dart';
import 'ro_format.dart' show roAmount;
import 'ro_hero_stat_card.dart';

class UemoiSyntheseScreen extends StatefulWidget {
  const UemoiSyntheseScreen({super.key, required this.api});
  final RwaApiService api;

  @override
  State<UemoiSyntheseScreen> createState() => _UemoiSyntheseScreenState();
}

class _UemoiSyntheseScreenState extends State<UemoiSyntheseScreen> {
  SyntheseResult? _result;
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
      final r = await widget.api.fetchSynthese();
      setState(() => _result = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 36),
          AppSpacing.gapMd,
          Text('Erreur de chargement', style: Theme.of(context).textTheme.bodyMedium),
          TextButton(onPressed: _load, child: const Text('Réessayer')),
        ]),
      );
    }

    final r = _result!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ecart = r.ecartBicVsAib;
    final ratio = r.ratioCouverture;

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicateurs d'écart - même carte "hero" que les autres onglets UEMOA
          if (ecart != null || ratio != null) ...[
            LayoutBuilder(builder: (context, constraints) {
              final stats = [
                if (ecart != null)
                  RoHeroStatCard(
                    label: 'Écart BIC − AIB',
                    value: roAmount(context, ecart),
                    subtitle: 'Risque opérationnel capital',
                    valueColor: ecart < 0 ? AppTheme.success : AppTheme.danger,
                  ),
                if (ratio != null)
                  RoHeroStatCard(
                    label: 'Ratio couverture Pilier 1/2',
                    value: '${ratio.toStringAsFixed(2)}×',
                    subtitle: 'Couverture capital pertes opérationnelles',
                    valueColor: ratio >= 1.0 ? AppTheme.success : AppTheme.danger,
                  ),
              ];
              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    for (final stat in stats) ...[
                      stat,
                      const SizedBox(height: AppTheme.spacing),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppTheme.spacing),
                    Expanded(child: stats[i]),
                  ],
                ],
              );
            }),
            AppSpacing.gapMd,
          ],

          // Tableau comparatif - carte tableau façon dashboard
          _buildComparatifCard(context, r, isDark),
          AppSpacing.gapSm,

          // Note pédagogique
          _buildLectureCard(context, isDark),
        ],
      ),
    );
  }

  // ── Carte "Tableau comparatif" - même langage visuel que le "Tableau des
  // données" du Risque de Marché (en-tête marine, lignes zébrées, pastilles
  // de statut). ─────────────────────────────────────────────────────────────

  static const _kPrimary = Color(0xFF2563EB);

  Widget _buildComparatifCard(
      BuildContext context, SyntheseResult r, bool isDark) {
    final border = isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F6);
    final surface = isDark ? const Color(0xFF101B31) : Colors.white;
    final text = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF1B2235);
    final muted = isDark ? const Color(0xFF8BA3C7) : const Color(0xFF64748B);
    final headerBg = isDark ? const Color(0xFF1B2C4A) : const Color(0xFF234A84);
    final sep = border.withValues(alpha: 0.7);

    Widget headCell(String label,
        {double? width, bool expanded = false, bool right = false}) {
      final cell = Container(
        width: width,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
      return expanded ? Expanded(child: cell) : cell;
    }

    Widget dataCell(Widget child,
        {double? width, bool expanded = false, bool right = false}) {
      final c = Container(
        width: width,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: sep)),
        ),
        child: child,
      );
      return expanded ? Expanded(child: c) : c;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tableau comparatif AIB / AS / BIC',
              style: TextStyle(
                  color: text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Exigence, APR et capital minimum selon chaque approche',
              style: TextStyle(
                  color: muted, fontSize: 10.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Container(
                    height: 40,
                    color: headerBg,
                    child: Row(
                      children: [
                        headCell('Méthode', expanded: true),
                        headCell('K (Exigence)', width: 170, right: true),
                        headCell('APR', width: 170, right: true),
                        headCell('Capital min.', width: 160, right: true),
                        Container(
                          width: 90,
                          height: double.infinity,
                          alignment: Alignment.center,
                          child: const Text('STATUT',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.6,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8)),
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < r.lignes.length; i++)
                    Builder(builder: (context) {
                      final l = r.lignes[i];
                      final isBic = l.methode.contains('BIC');
                      final faded = !l.disponible;
                      final rowText = faded ? muted : text;
                      final background = isBic
                          ? _kPrimary.withValues(alpha: isDark ? 0.10 : 0.05)
                          : i.isOdd
                              ? (isDark
                                  ? const Color(0xFF14233D)
                                      .withValues(alpha: 0.55)
                                  : const Color(0xFFF5F9FF))
                              : surface;

                      return Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: background,
                          border: Border(top: BorderSide(color: sep)),
                        ),
                        child: Row(
                          children: [
                            dataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.methode,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: rowText,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700)),
                                  if (isBic)
                                    const Text(
                                        'Pilotage interne - non déclaratoire',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Color(0xFFF59E0B),
                                            fontSize: 9.8,
                                            fontWeight: FontWeight.w600)),
                                ],
                              ),
                              expanded: true,
                            ),
                            dataCell(
                              Text(
                                  l.disponible
                                      ? roAmount(context, l.k)
                                      : '-',
                                  maxLines: 1,
                                  style: TextStyle(
                                      color: rowText,
                                      fontSize: 11,
                                      fontWeight: l.disponible
                                          ? FontWeight.w800
                                          : FontWeight.w500)),
                              width: 170,
                              right: true,
                            ),
                            dataCell(
                              Text(
                                  l.disponible
                                      ? roAmount(context, l.apr)
                                      : '-',
                                  maxLines: 1,
                                  style: TextStyle(
                                      color: rowText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              width: 170,
                              right: true,
                            ),
                            dataCell(
                              Text(
                                  l.disponible
                                      ? roAmount(context, l.capitalMin)
                                      : '-',
                                  maxLines: 1,
                                  style: TextStyle(
                                      color: rowText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              width: 160,
                              right: true,
                            ),
                            SizedBox(
                              width: 90,
                              child: Center(
                                child: _StatusBadge(
                                    ok: l.disponible, muted: muted),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLectureCard(BuildContext context, bool isDark) {
    final border = isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F6);
    final surface = isDark ? const Color(0xFF101B31) : Colors.white;
    final soft = isDark ? const Color(0xFF162642) : const Color(0xFFF3F7FD);
    final text = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF1B2235);
    final muted = isDark ? const Color(0xFF8BA3C7) : const Color(0xFF64748B);

    const notes = [
      ('AIB',
          'Approche par défaut BCEAO. Moyenne des PNB positifs des 3 derniers exercices (N-2, N-1, N) × α = 15 %. Exigible dès la 1re année.'),
      ('AS',
          'Réservée aux établissements autorisés par la Commission Bancaire (art. 300). Calculée sur l\'exercice courant : somme des PNB par ligne de métier × β.'),
      ('BIC',
          'Benchmark CRR3 (Europe). Utile pour mesurer l\'écart avec le cadre international.'),
      ('Ratio',
          'Ratio couverture < 1 → l\'exigence Pilier 1 ne couvre pas les pertes opérationnelles historiques (Pilier 2).'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lecture du tableau',
              style: TextStyle(
                  color: text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final (code, note) in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _kPrimary.withValues(alpha: 0.25)),
                      ),
                      child: Text(code,
                          style: const TextStyle(
                              color: _kPrimary,
                              fontSize: 9.6,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(note,
                          style: TextStyle(
                              color: muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              height: 1.4)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Helpers privés ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.ok, required this.muted});
  final bool ok;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppTheme.success : muted;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(ok ? 'OK' : 'N/D',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color, fontWeight: FontWeight.w700)),
    );
  }
}


