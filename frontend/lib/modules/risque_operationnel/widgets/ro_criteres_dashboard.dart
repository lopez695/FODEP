// Dashboard des critères d'analyse de la décision de pilotage.
//
// Remplace l'ancien tableau plat par une grille de cartes façon dashboard :
// chaque critère devient une carte avec liseré de statut, badge de code,
// pastille Conforme / Attention / Critique, valeur observée mise en avant,
// seuil de référence et référence réglementaire. Un bandeau de synthèse
// compte les critères par statut.
import 'package:flutter/material.dart';

import '../models/ro_models.dart';

class RoCriteresDashboard extends StatelessWidget {
  const RoCriteresDashboard({
    super.key,
    required this.criteres,
    this.title = 'Critères d\'analyse',
    this.embedded = false,
  });

  final List<DecisionCritere> criteres;
  final String title;

  /// Quand true, le widget est posé dans une carte existante : il ne dessine
  /// pas son propre conteneur (fond, bordure, ombre), seulement l'en-tête et
  /// la grille.
  final bool embedded;

  static const _kGreen = Color(0xFF14A44D);
  static const _kAmber = Color(0xFFF59E0B);
  static const _kRed = Color(0xFFDC2626);
  static const _kBlue = Color(0xFF2563EB);

  Color _statutColor(String statut) => switch (statut) {
        'conforme' => _kGreen,
        'attention' => _kAmber,
        _ => _kRed,
      };

  String _statutLabel(String statut) => switch (statut) {
        'conforme' => 'Conforme',
        'attention' => 'Attention',
        _ => 'Critique',
      };

  IconData _statutIcon(String statut) => switch (statut) {
        'conforme' => Icons.check_circle_rounded,
        'attention' => Icons.warning_amber_rounded,
        _ => Icons.error_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F6);
    final surface = isDark ? const Color(0xFF101B31) : Colors.white;
    final text = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF1B2235);
    final muted = isDark ? const Color(0xFF8BA3C7) : const Color(0xFF64748B);

    final nbConformes = criteres.where((c) => c.statut == 'conforme').length;
    final nbAttention = criteres.where((c) => c.statut == 'attention').length;
    final nbCritiques = criteres.length - nbConformes - nbAttention;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête : titre + synthèse par statut ──────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _SummaryPill(
                  icon: Icons.check_circle_rounded,
                  color: _kGreen,
                  count: nbConformes,
                  label: 'conformes',
                  isDark: isDark,
                ),
                _SummaryPill(
                  icon: Icons.warning_amber_rounded,
                  color: _kAmber,
                  count: nbAttention,
                  label: 'attention',
                  isDark: isDark,
                ),
                _SummaryPill(
                  icon: Icons.error_rounded,
                  color: _kRed,
                  count: nbCritiques,
                  label: 'critiques',
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Grille de cartes ───────────────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final maxWidth = constraints.maxWidth;
            final columns = maxWidth >= 1160
                ? 3
                : maxWidth >= 720
                    ? 2
                    : 1;
            final cardWidth = (maxWidth - gap * (columns - 1)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final c in criteres)
                  SizedBox(
                    width: cardWidth,
                    child: _CritereCard(
                      critere: c,
                      color: _statutColor(c.statut),
                      statutLabel: _statutLabel(c.statut),
                      statutIcon: _statutIcon(c.statut),
                      border: border,
                      surface: surface,
                      text: text,
                      muted: muted,
                      isDark: isDark,
                      blue: _kBlue,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );

    if (embedded) return content;

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
      child: content,
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final Color color;
  final int count;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    final fg = active ? color : (isDark ? const Color(0xFF56688A) : const Color(0xFFB0BDD1));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: active ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CritereCard extends StatelessWidget {
  const _CritereCard({
    required this.critere,
    required this.color,
    required this.statutLabel,
    required this.statutIcon,
    required this.border,
    required this.surface,
    required this.text,
    required this.muted,
    required this.isDark,
    required this.blue,
  });

  final DecisionCritere critere;
  final Color color;
  final String statutLabel;
  final IconData statutIcon;
  final Color border;
  final Color surface;
  final Color text;
  final Color muted;
  final bool isDark;
  final Color blue;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13213A) : const Color(0xFFFBFCFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Liseré de statut en haut de carte.
            Container(height: 3, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Code + libellé + pastille de statut ─────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          critere.code,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              critere.libelle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: text,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              critere.commentaire,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: muted,
                                fontSize: 10.2,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statutIcon, size: 11, color: color),
                            const SizedBox(width: 4),
                            Text(
                              statutLabel,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(height: 1, color: border.withValues(alpha: 0.8)),
                  const SizedBox(height: 9),

                  // ── Valeur observée / seuil ─────────────────────────────
                  _MetricRow(
                    label: 'Valeur observée',
                    value: critere.valeurObservee,
                    valueColor: text,
                    muted: muted,
                    emphasized: true,
                  ),
                  const SizedBox(height: 5),
                  _MetricRow(
                    label: 'Seuil de référence',
                    value: critere.seuilReference,
                    valueColor: muted,
                    muted: muted,
                  ),
                  const SizedBox(height: 9),

                  // ── Référence réglementaire + poids ─────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: blue.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          critere.referenceReglementaire,
                          style: TextStyle(
                            color: blue,
                            fontSize: 9.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Poids ${critere.poids}',
                        style: TextStyle(
                          color: muted,
                          fontSize: 9.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.muted,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color muted;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: emphasized ? 11.5 : 10.5,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
