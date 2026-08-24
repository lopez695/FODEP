import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../models/ro_models.dart';
import 'ro_format.dart' show roAmount;
import 'ro_hero_stat_card.dart';

class UemoiAsScreen extends StatefulWidget {
  const UemoiAsScreen({super.key, required this.api});
  final RwaApiService api;

  @override
  State<UemoiAsScreen> createState() => _UemoiAsScreenState();
}

class _UemoiAsScreenState extends State<UemoiAsScreen> {
  AsCalculResult? _result;
  List<BetaLigneView> _betas = [];
  bool _loading = true;
  String? _error;

  // Exercice que le formulaire de saisie vise. L'exigence porte sur les trois
  // derniers, tous conservés ; celui-ci ne dit donc pas « le » millésime de
  // l'établissement, seulement lequel on est en train de renseigner.
  // Déterminé au premier chargement (le plus récent des exercices déjà saisis,
  // sinon l'année en cours), puis conservé : ni un enregistrement ni un
  // rafraîchissement ne doivent changer l'exercice choisi par l'utilisateur.
  int _anneeSelect = DateTime.now().year;
  bool _anneeInitialisee = false;
  final Map<String, TextEditingController> _pnbCtrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _pnbCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.api.calculeAs(),
        widget.api.fetchAsParametres(),
        widget.api.fetchBetaLignes(),
      ]);
      final r = results[0] as AsCalculResult;
      final b = results[2] as List<BetaLigneView>;

      // Au premier chargement uniquement, se caler sur le plus récent des
      // exercices déjà saisis (sinon l'année en cours) : c'est celui qu'on
      // vient compléter. `detailParAnnee` est trié par année croissante, le
      // dernier est donc le plus récent. Ensuite l'exercice choisi par
      // l'utilisateur est conservé à travers les rechargements.
      if (!_anneeInitialisee) {
        _anneeSelect = r.detailParAnnee.isNotEmpty
            ? r.detailParAnnee.last.annee
            : DateTime.now().year;
        _anneeInitialisee = true;
      }

      for (final c in _pnbCtrls.values) {
        c.dispose();
      }
      _pnbCtrls.clear();

      final lignes = await widget.api.fetchPnbLignes(_anneeSelect);
      final lignesMap = {for (final l in lignes) l.ligneMetier: l.produitBrutLigne};
      for (final beta in b) {
        final val = lignesMap[beta.ligneMetier];
        _pnbCtrls[beta.ligneMetier] = TextEditingController(
          text: val != null ? val.toStringAsFixed(0) : '',
        );
      }

      setState(() {
        _result = r;
        _betas = b;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Change l'exercice cible du formulaire : demande l'année puis recharge
  // les PNB par ligne enregistrés pour cette année (champs vides sinon).
  Future<void> _changerExercice() async {
    final ctrl = TextEditingController(text: '$_anneeSelect');
    final year = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Changer d\'exercice'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Exercice (année)',
            hintText: 'ex. 2026',
          ),
          onSubmitted: (v) {
            final y = int.tryParse(v.trim());
            if (y != null) Navigator.pop(dialogContext, y);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final y = int.tryParse(ctrl.text.trim());
              if (y != null) Navigator.pop(dialogContext, y);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (year == null || year < 2000 || year > 2100 || year == _anneeSelect) {
      return;
    }
    setState(() => _anneeSelect = year);
    final lignes = await widget.api.fetchPnbLignes(year);
    final lignesMap = {for (final l in lignes) l.ligneMetier: l.produitBrutLigne};
    if (!mounted) return;
    setState(() {
      for (final e in _pnbCtrls.entries) {
        final val = lignesMap[e.key];
        e.value.text = val != null ? val.toStringAsFixed(0) : '';
      }
    });
  }

  // Retire un exercice de la moyenne. Tant que l'enregistrement effaçait les
  // autres années, se tromper d'exercice se corrigeait en ressaisissant sur la
  // bonne ; maintenant que les trois se cumulent, il faut pouvoir en retirer
  // un — sans quoi une année saisie par erreur pèserait sur l'exigence
  // déclarée à la BCEAO sans aucun moyen de la reprendre.
  Future<void> _retirerExercice(int annee) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Retirer l\'exercice $annee ?'),
        content: Text(
          'Les produits bruts des huit lignes de métier saisis pour $annee '
          'seront supprimés, et l\'exercice sortira de la moyenne sur laquelle '
          'repose l\'exigence de fonds propres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await widget.api.deletePnbLignes(annee);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Exercice $annee retiré'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _saveAllLignes() async {
    setState(() => _saving = true);
    try {
      for (final entry in _pnbCtrls.entries) {
        final val = double.tryParse(entry.value.text.trim().replaceAll(' ', ''));
        if (val != null) {
          await widget.api.upsertPnbLigne(_anneeSelect, entry.key, val);
        }
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('PNB $_anneeSelect enregistrés'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI résultats
          if (!r.donneesInsuffisantes) ...[
            _buildStatGrid(r),
            AppSpacing.gapSm,
          ],

          if (r.donneesInsuffisantes) ...[
            const _NoticeBanner(
              color: AppTheme.warning,
              icon: Icons.warning_amber_outlined,
              text: 'Aucune donnée PNB par ligne de métier saisie.'
                  ' Renseignez les 8 lignes pour chacun des trois derniers'
                  ' exercices.',
            ),
            AppSpacing.gapSm,
          ] else if (r.detailParAnnee.length < 3) ...[
            // L'exigence est une moyenne sur trois exercices : tant qu'il en
            // manque, elle porte sur ce qui est disponible, et l'EP23 transmis
            // à la BCEAO le signale. Autant le dire ici, là où on saisit.
            _NoticeBanner(
              color: AppTheme.warning,
              icon: Icons.event_busy_outlined,
              text: '${r.detailParAnnee.length} exercice(s) sur 3 saisi(s)'
                  ' (${r.detailParAnnee.map((d) => d.annee).join(', ')}).'
                  ' L\'exigence est la moyenne des trois derniers exercices :'
                  ' elle porte pour l\'instant sur ce qui est disponible.',
            ),
            AppSpacing.gapSm,
          ],

          // Détail du calcul, un tableau par exercice retenu dans la moyenne.
          // Du plus récent au plus ancien : c'est celui qu'on vient de saisir
          // qu'on relit en premier.
          for (final detail in r.detailParAnnee.reversed) ...[
            _buildDetailCard(context, isDark, detail),
            AppSpacing.gapSm,
          ],

          // Saisie PNB par ligne - carte tableau façon dashboard
          _buildPnbSaisieCard(context, isDark),
        ],
      ),
    );
  }

  // ── Carte de saisie PNB - tableau moderne (en-tête marine, lignes zébrées,
  // sélecteur d'années en boutons, bouton d'enregistrement bleu) - même
  // langage visuel que le "Tableau des données" du Risque de Marché. ────────

  static const _kPrimary = Color(0xFF2563EB);

  // ── Carte "Détail du calcul" - un exercice : tableau des 8 lignes
  // avec K = PNB × β par ligne et total en pied de tableau. ─────────────────

  Widget _buildDetailCard(BuildContext context, bool isDark, AsAnneeDetail d) {
    final border = isDark ? const Color(0xFF263856) : const Color(0xFFDDE7F6);
    final surface = isDark ? const Color(0xFF101B31) : Colors.white;
    final soft = isDark ? const Color(0xFF162642) : const Color(0xFFF3F7FD);
    final text = isDark ? const Color(0xFFEAF2FF) : const Color(0xFF1B2235);
    final muted = isDark ? const Color(0xFF8BA3C7) : const Color(0xFF64748B);
    final headerBg = isDark ? const Color(0xFF1B2C4A) : const Color(0xFF234A84);
    final sep = border.withValues(alpha: 0.7);

    Widget headCell(String label,
        {double? width, bool expanded = false, bool right = false, bool center = false}) {
      final cell = Container(
        width: width,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: center
            ? Alignment.center
            : (right ? Alignment.centerRight : Alignment.centerLeft),
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
        {double? width, bool expanded = false, bool right = false, bool center = false}) {
      final c = Container(
        width: width,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: center
            ? Alignment.center
            : (right ? Alignment.centerRight : Alignment.centerLeft),
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
          // ── En-tête : titre + exercice + K retenu ────────────────────────
          Row(
            children: [
              Expanded(
                child: Text('Détail du calcul (K = PNB × β)',
                    style: TextStyle(
                        color: text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: isDark ? 0.22 : 0.10),
                  border: Border.all(color: _kPrimary),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Exercice ${d.annee}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : _kPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Tableau des lignes ───────────────────────────────────────────
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
                        headCell('Ligne de métier', expanded: true),
                        headCell('PNB ${d.annee} (FCFA)', width: 190, right: true),
                        headCell('β', width: 76, center: true),
                        headCell('K = PNB × β', width: 190, right: true),
                      ],
                    ),
                  ),
                  for (var i = 0; i < d.lignes.length; i++)
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: i.isOdd
                            ? (isDark
                                ? const Color(0xFF14233D)
                                    .withValues(alpha: 0.55)
                                : const Color(0xFFF5F9FF))
                            : surface,
                        border: Border(top: BorderSide(color: sep)),
                      ),
                      child: Row(
                        children: [
                          dataCell(
                            Text(d.lignes[i].ligneMetier,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: text,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600)),
                            expanded: true,
                          ),
                          dataCell(
                            Text(roAmount(context, d.lignes[i].pnb),
                                maxLines: 1,
                                style: TextStyle(
                                    color: text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            width: 190,
                            right: true,
                          ),
                          dataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _kPrimary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                  '${(d.lignes[i].beta * 100).toStringAsFixed(0)} %',
                                  style: const TextStyle(
                                      color: _kPrimary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                            width: 76,
                            center: true,
                          ),
                          dataCell(
                            Text(roAmount(context, d.lignes[i].kLigne),
                                maxLines: 1,
                                style: TextStyle(
                                    color: d.lignes[i].kLigne >= 0
                                        ? text
                                        : const Color(0xFFF59E0B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            width: 190,
                            right: true,
                          ),
                        ],
                      ),
                    ),
                  // ── Pied de tableau : total ──────────────────────────────
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: soft,
                      border: Border(top: BorderSide(color: border)),
                    ),
                    child: Row(
                      children: [
                        dataCell(
                          Text('K_AS retenu (plancher à 0)',
                              style: TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          expanded: true,
                        ),
                        dataCell(
                          Text(
                              d.kTotal < 0
                                  ? 'K total : ${roAmount(context, d.kTotal)}'
                                  : '',
                              maxLines: 1,
                              style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600)),
                          width: 266,
                          right: true,
                        ),
                        dataCell(
                          Text(roAmount(context, d.kRetenu),
                              maxLines: 1,
                              style: const TextStyle(
                                  color: _kPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                          width: 190,
                          right: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPnbSaisieCard(BuildContext context, bool isDark) {
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
          // ── En-tête : titre + sélecteur d'années ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PNB par ligne de métier',
                        style: TextStyle(
                            color: text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        'Approche Standard - saisie annuelle par ligne de métier BCEAO',
                        style: TextStyle(
                            color: muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Combien des trois exercices sont saisis, comme sur l'onglet de
              // l'indicateur de base. L'exigence est leur moyenne : sans ce
              // compteur, rien ne disait ici qu'il en manquait, et l'EP23
              // partait sur ce qui était disponible.
              Builder(builder: (context) {
                final saisis = _result?.detailParAnnee.length ?? 0;
                final complet = saisis >= 3;
                final couleur = complet ? AppTheme.success : _kPrimary;
                return Tooltip(
                  message: complet
                      ? 'Les trois exercices attendus sont saisis'
                      : 'L\'exigence est la moyenne des trois derniers '
                          'exercices : ${3 - saisis} reste(nt) à saisir',
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: isDark ? 0.20 : 0.10),
                      border: Border.all(color: couleur.withValues(alpha: 0.55)),
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
                          color: couleur,
                        ),
                        const SizedBox(width: 5),
                        Text('$saisis/3 exercices',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: couleur)),
                      ],
                    ),
                  ),
                );
              }),
              Tooltip(
                message: 'L\'exigence porte sur les trois derniers exercices - '
                    'cliquez pour changer celui que vous saisissez',
                child: InkWell(
                  onTap: _changerExercice,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: isDark ? 0.22 : 0.10),
                      border: Border.all(color: _kPrimary),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_outlined,
                            size: 12,
                            color: isDark ? Colors.white : _kPrimary),
                        const SizedBox(width: 5),
                        Text('Exercice $_anneeSelect',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : _kPrimary)),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_outlined,
                            size: 12,
                            color: isDark ? Colors.white : _kPrimary),
                      ],
                    ),
                  ),
                ),
              ),
              // Retrait de l'exercice affiché, proposé seulement s'il porte
              // des données : rien à retirer d'une année encore vierge.
              if (_result?.detailParAnnee
                      .any((d) => d.annee == _anneeSelect) ??
                  false) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Retirer l\'exercice $_anneeSelect de la moyenne',
                  child: InkWell(
                    onTap: () => _retirerExercice(_anneeSelect),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 28,
                      width: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppTheme.danger.withValues(alpha: 0.55)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 14, color: AppTheme.danger),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // ── Note explicative ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: muted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'L\'Approche Standard porte sur un seul exercice : saisissez le PNB '
                    'de chacune des 8 lignes de métier pour l\'exercice $_anneeSelect. '
                    'K_AS = somme des PNB × β (plancher à 0). Changer d\'exercice puis '
                    'enregistrer remplace l\'exercice précédent : une seule année est '
                    'conservée.',
                    style: TextStyle(
                        color: muted,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w500,
                        height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Tableau de saisie ────────────────────────────────────────────
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
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.14)),
                              ),
                            ),
                            child: const Text('Ligne de métier',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Container(
                          width: 76,
                          height: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.14)),
                            ),
                          ),
                          child: const Text('β',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Container(
                          width: 240,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerRight,
                          child: Text('PNB $_anneeSelect (FCFA)',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  // Lignes zébrées
                  for (var i = 0; i < _betas.length; i++)
                    _buildPnbRow(
                      _betas[i],
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
          const SizedBox(height: 12),

          // ── Enregistrer ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 32,
              child: FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 14),
                label: Text(
                    _saving ? 'Enregistrement…' : 'Enregistrer $_anneeSelect',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
                onPressed: _saving ? null : _saveAllLignes,
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPnbRow(
    BetaLigneView b, {
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

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: sep)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: sep)),
              ),
              child: Text(b.ligneMetier,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          Container(
            width: 76,
            height: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: sep)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${(b.beta * 100).toStringAsFixed(0)} %',
                  style: const TextStyle(
                      color: _kPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(
            width: 240,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                height: 30,
                child: TextFormField(
                  controller: _pnbCtrls[b.ligneMetier],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    hintText: '0',
                    hintStyle: TextStyle(
                        fontSize: 11, color: muted.withValues(alpha: 0.7)),
                    suffixText: ' FCFA',
                    suffixStyle: TextStyle(fontSize: 9, color: muted),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF162642)
                        : const Color(0xFFF3F7FD),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide:
                            const BorderSide(color: _kPrimary, width: 1.2)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(AsCalculResult r) {
    final stats = [
      RoHeroStatCard(
        label: 'K_AS (Exigence)',
        value: roAmount(context, r.kAs),
        subtitle: 'Capital risque opérationnel',
      ),
      RoHeroStatCard(
        label: 'APR Opérationnel',
        value: roAmount(context, r.aprAs),
        subtitle: 'RWA risque opérationnel',
      ),
      RoHeroStatCard(
        label: 'Capital minimal (9 %)',
        value: roAmount(context, r.capitalMinAs),
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

// ─── Helpers privés ───────────────────────────────────────────────────────────

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner(
      {required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 14),
        AppSpacing.hGapMd,
        Expanded(
          child: Text(text,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ),
      ]),
    );
  }
}

