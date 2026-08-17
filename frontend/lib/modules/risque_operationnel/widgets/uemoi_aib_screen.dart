import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../models/ro_models.dart';
import 'ro_format.dart' show roAmount;
import 'ro_hero_stat_card.dart';
import 'uemoi_form_style.dart';

class UemoiAibScreen extends StatefulWidget {
  const UemoiAibScreen({super.key, required this.api});
  final RwaApiService api;

  @override
  State<UemoiAibScreen> createState() => _UemoiAibScreenState();
}

class _UemoiAibScreenState extends State<UemoiAibScreen> {
  AibCalculResult? _result;
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
      final r = await widget.api.calculeAib();
      setState(() => _result = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openExerciceDialog({PnbAnnuelView? initial}) async {
    final anneeCtrl = TextEditingController(text: initial == null ? '' : '${initial.annee}');
    final pnbCtrl = TextEditingController(
        text: initial == null ? '' : initial.produitBrutTotal.toStringAsFixed(0));
    final srcCtrl = TextEditingController(text: initial?.sourceDocument ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      pageBuilder: (dialogContext, _, __) => Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: StatefulBuilder(
            builder: (dialogContext, setD) {
              final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
              return Container(
                width: 420,
                constraints: const BoxConstraints(maxHeight: 640),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            initial == null ? 'Nouvel exercice PNB' : 'Modifier l\'exercice ${initial.annee}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                          color: AppTheme.muted,
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: UemoiFormCard(
                            title: initial == null ? 'Nouvel exercice' : 'Exercice ${initial.annee}',
                            subtitle: 'Indicateur de Base - BCEAO',
                            color: AppTheme.accent,
                            children: [
                              UemoiFormField(
                                label: 'Exercice',
                                controller: anneeCtrl,
                                enabled: initial == null,
                                hint: '2024',
                                numeric: true,
                                required: true,
                                validator: (v) => int.tryParse(v ?? '') == null ? 'Année invalide' : null,
                              ),
                              UemoiFormField(
                                label: 'Produit Brut',
                                controller: pnbCtrl,
                                hint: 'ex. 500 000 000',
                                suffixText: ' FCFA',
                                numeric: true,
                                required: true,
                                validator: (v) => double.tryParse(v?.replaceAll(' ', '') ?? '') == null
                                    ? 'Montant invalide'
                                    : null,
                              ),
                              UemoiFormField(
                                label: 'Référence documents',
                                controller: srcCtrl,
                                hint: 'Comptes audités 2024',
                                numeric: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  final annee = int.tryParse(anneeCtrl.text.trim());
                                  final pnb = double.tryParse(pnbCtrl.text.trim().replaceAll(' ', ''));
                                  if (annee == null || pnb == null) return;
                                  setD(() => saving = true);
                                  try {
                                    await widget.api.upsertPnbAnnuel(annee, {
                                      'produit_brut_total': pnb,
                                      'source_document': srcCtrl.text.trim(),
                                    });
                                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                                  } catch (e) {
                                    setD(() => saving = false);
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                                        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppTheme.danger),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          icon: saving
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined, size: 15),
                          label: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    anneeCtrl.dispose();
    pnbCtrl.dispose();
    srcCtrl.dispose();

    if (ok == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(initial == null
                ? 'Exercice enregistré avec succès.'
                : 'Exercice mis à jour avec succès.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(int annee) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Supprimer l\'exercice ?'),
        content: Text('L\'exercice $annee sera supprimé définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.deletePnbAnnuel(annee);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppTheme.success, content: Text('Exercice supprimé.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppTheme.danger),
        );
      }
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

    final r = _result;
    final annees = r?.anneesSaisies ?? const <PnbAnnuelView>[];

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatGrid(r),
          AppSpacing.gapMd,
          _buildPnbCard(context, annees),
        ],
      ),
    );
  }

  // ── Carte "PNB annuel" - tableau moderne (en-tête marine, lignes zébrées,
  // barre d'outils compacte) - même langage visuel que le "Tableau des
  // données" du Risque de Marché. ───────────────────────────────────────────

  static const _kPrimary = Color(0xFF2563EB);

  Widget _buildPnbCard(BuildContext context, List<PnbAnnuelView> annees) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F6);
    final surface = isDark ? const Color(0xFF101B31) : Colors.white;
    final soft = isDark ? const Color(0xFF162642) : const Color(0xFFF3F7FD);
    final text = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF1B2235);
    final muted = isDark ? const Color(0xFF8BA3C7) : const Color(0xFF64748B);
    final headerBg = isDark ? const Color(0xFF1B2C4A) : const Color(0xFF234A84);

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
          // ── Titre + barre d'outils ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PNB annuel (N-2, N-1, N) - Indicateur de Base',
                        style: TextStyle(
                            color: text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              // Compteur d'exercices : l'AIB en attend exactement 3.
              Builder(builder: (context) {
                final nb = _result?.anneesSaisies.length ?? 0;
                final complet = nb >= 3;
                final color = complet ? AppTheme.success : _kPrimary;
                return Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.20 : 0.10),
                    border: Border.all(color: color.withValues(alpha: 0.55)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          complet
                              ? Icons.check_circle_rounded
                              : Icons.event_outlined,
                          size: 12,
                          color: color),
                      const SizedBox(width: 5),
                      Text('$nb/3 exercices',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                );
              }),
              const SizedBox(width: 8),
              Builder(builder: (context) {
                // L'AIB porte sur exactement 3 exercices (N-2, N-1, N) : une
                // fois les 3 saisis, on modifie ou on supprime, on n'ajoute plus.
                final complet = (_result?.anneesSaisies.length ?? 0) >= 3;
                return Tooltip(
                  message: complet
                      ? '3 exercices maximum (N-2, N-1, N) : supprimez un '
                          'exercice existant pour en ajouter un autre'
                      : 'Ajouter un exercice PNB',
                  child: SizedBox(
                    height: 30,
                    child: FilledButton.icon(
                      onPressed: complet ? null : () => _openExerciceDialog(),
                      icon: const Icon(CupertinoIcons.plus, size: 13),
                      label: const Text('Nouvel exercice',
                          style: TextStyle(
                              fontSize: 10.6, fontWeight: FontWeight.w500)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),

          // ── Tableau des exercices ────────────────────────────────────────
          if (annees.isEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: border),
              ),
              child: Text(
                'Aucun exercice saisi. Ajoutez le PNB des 3 derniers exercices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: muted, fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    // En-tête marine
                    Container(
                      height: 40,
                      color: headerBg,
                      child: Row(
                        children: [
                          _pnbHeadCell('Exercice', width: 110),
                          _pnbHeadCell('PNB total', expanded: true, right: true),
                          _pnbHeadCell('Statut AIB', expanded: true, right: true),
                          _pnbHeadCell('Source', expanded: true),
                          Container(
                            width: 92,
                            height: double.infinity,
                            alignment: Alignment.center,
                            child: const Text('ACTIONS',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.6,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < annees.length; i++)
                      _buildPnbRow(
                        annees[i],
                        alternate: i.isOdd,
                        isDark: isDark,
                        border: border,
                        surface: surface,
                        text: text,
                        muted: muted,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pnbHeadCell(String label,
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
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
    return expanded ? Expanded(child: cell) : cell;
  }

  Widget _buildPnbRow(
    PnbAnnuelView a, {
    required bool alternate,
    required bool isDark,
    required Color border,
    required Color surface,
    required Color text,
    required Color muted,
  }) {
    final background = alternate
        ? (isDark
            ? const Color(0xFF14233D).withValues(alpha: 0.55)
            : const Color(0xFFF5F9FF))
        : surface;
    final sep = border.withValues(alpha: 0.7);

    Widget cell(Widget child,
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
      height: 44,
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: sep)),
      ),
      child: Row(
        children: [
          cell(
            Text('${a.annee}',
                style: TextStyle(
                    color: text, fontSize: 11.5, fontWeight: FontWeight.w800)),
            width: 110,
          ),
          cell(
            Text(roAmount(context, a.produitBrutTotal),
                maxLines: 1,
                style: TextStyle(
                    color: text, fontSize: 11, fontWeight: FontWeight.w600)),
            expanded: true,
            right: true,
          ),
          cell(
            a.pnbPositif
                ? Text(roAmount(context, a.pnbRetenuAib),
                    maxLines: 1,
                    style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text('Exclu (négatif)',
                        style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 10.2,
                            fontWeight: FontWeight.w700)),
                  ),
            expanded: true,
            right: true,
          ),
          cell(
            Text(a.sourceDocument.isEmpty ? '-' : a.sourceDocument,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: muted, fontSize: 10.8, fontWeight: FontWeight.w500)),
            expanded: true,
          ),
          SizedBox(
            width: 92,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Modifier',
                  onPressed: () => _openExerciceDialog(initial: a),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.edit_outlined,
                      size: 17,
                      color: isDark
                          ? const Color(0xFFB8C7E0)
                          : const Color(0xFF334155)),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => _confirmDelete(a.annee),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 17, color: Color(0xFFEF4444)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(AibCalculResult? r) {
    final insuffisant = r == null || r.donneesInsuffisantes;
    final stats = [
      RoHeroStatCard(
        label: 'K_IB (Exigence)',
        value: insuffisant ? '-' : roAmount(context, r.kIb),
        subtitle: 'Capital risque opérationnel',
      ),
      RoHeroStatCard(
        label: 'APR Opérationnel',
        value: insuffisant ? '-' : roAmount(context, r.aprAib),
        subtitle: 'RWA risque opérationnel',
      ),
      RoHeroStatCard(
        label: 'Capital minimal (9 %)',
        value: insuffisant ? '-' : roAmount(context, r.capitalMinAib),
        subtitle: 'Capital minimum requis',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
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
      },
    );
  }
}
