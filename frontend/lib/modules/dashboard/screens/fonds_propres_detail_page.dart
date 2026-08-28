import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../rapports/models/report_models.dart';
import '../models/dashboard_models.dart';
import '../widgets/dashboard_design.dart';
import 'fonds_propres_exercice_dialog.dart';

/// Page de détail des fonds propres réglementaires.
///
/// La carte du tableau de bord ne porte que l'exercice courant, et chaque
/// poste y tient sur une ligne serrée. Cette page ouvre les deux dimensions
/// que la carte ne peut pas montrer : **tous** les postes qui composent les
/// fonds propres, et **tous** les exercices enregistrés côte à côte.
///
/// La comparaison d'un exercice à l'autre n'est pas un confort : les limites
/// des EP36 à EP38 se mesurent, dit le formulaire, sur les fonds propres de
/// l'exercice PRÉCÉDENT. Voir les deux millésimes ensemble, c'est voir le
/// dénominateur que la déclaration utilise.
class FondsPropresDetailPage extends StatefulWidget {
  const FondsPropresDetailPage({
    super.key,
    required this.fondsPropres,
    this.api,
  });

  final FondsPropresDetail fondsPropres;

  /// Sans elle la page reste en lecture : c'est le cas des essais de rendu,
  /// qui n'ont pas de serveur à joindre.
  final RwaApiService? api;

  /// Ouvre la page par-dessus l'écran courant.
  static Future<void> ouvrir(
    BuildContext context,
    FondsPropresDetail? fondsPropres, {
    RwaApiService? api,
  }) {
    if (fondsPropres == null) return Future<void>.value();
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          FondsPropresDetailPage(fondsPropres: fondsPropres, api: api),
    ));
  }

  @override
  State<FondsPropresDetailPage> createState() => _FondsPropresDetailPageState();
}

class _FondsPropresDetailPageState extends State<FondsPropresDetailPage> {
  late FondsPropresDetail fondsPropres = widget.fondsPropres;
  bool _chargement = false;

  /// Ce que ces fonds propres produisent une fois rapportés aux actifs
  /// pondérés : les trois ratios de solvabilité, avec leur seuil.
  ///
  /// C'est ici qu'on déclare les exercices, donc ici qu'on doit voir ce qu'ils
  /// affirment. Les montants seuls ne disent pas si l'établissement passe.
  Future<AnalyseDeclaration>? _analyse;

  @override
  void initState() {
    super.initState();
    _analyse = widget.api?.fetchAnalyseFodepCourante();
  }

  /// Recharge le tableau de bord après une saisie : la page vit au-dessus de
  /// l'écran d'origine, qui ne se rafraîchit pas de lui-même.
  Future<void> _recharger() async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _chargement = true);
    try {
      final snapshot = await api.fetchDashboard(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        fondsPropres = snapshot.fondsPropres ?? fondsPropres;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saisir({FondsPropresExercice? initial}) async {
    final api = widget.api;
    if (api == null) return;
    final enregistre = await FondsPropresExerciceDialog.ouvrir(
      context,
      api,
      initial: initial,
      anneesPrises: _exercices.map((e) => e.exercice).toList(),
      exerciceEnCours: fondsPropres.exercice,
    );
    if (!enregistre) return;
    await _recharger();
    if (!mounted) return;
    // Nommer l'exercice ecrit : c'est la seule facon de voir, sans ouvrir la
    // base, si la saisie a porte la ou on croyait.
    final vises = _exercices.map((e) => e.exercice).toSet();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade700,
        content: Text(
          '${'Enregistré'.tr(context)} — '
          '${'exercices en base'.tr(context)} : '
          '${(vises.toList()..sort((a, b) => b.compareTo(a))).join(', ')}',
        ),
      ),
    );
  }

  Future<void> _retirer(FondsPropresExercice exercice) async {
    final api = widget.api;
    if (api == null) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Retirer l\'exercice ${exercice.exercice} ?'),
        content: Text(
          'Les fonds propres saisis pour ${exercice.exercice} seront '
          "supprimés de l'historique.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await api.deleteFondsPropresExercice(exercice.exercice);
      await _recharger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Les exercices à présenter, du plus récent au plus ancien.
  ///
  /// Un relevé vide n'est pas forcément une absence de données : c'est aussi
  /// ce que renvoie un serveur antérieur à l'historique. On retombe alors sur
  /// l'exercice courant plutôt que d'ouvrir une page vide.
  List<FondsPropresExercice> get _exercices {
    if (fondsPropres.historique.isNotEmpty) {
      return fondsPropres.historique;
    }
    if (fondsPropres.totalFp > 0) {
      return [FondsPropresExercice.depuisDetail(fondsPropres)];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final exercices = _exercices;

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Fonds propres réglementaires'.tr(context),
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: c.ink),
        ),
        iconTheme: IconThemeData(color: c.ink),
        actions: [
          if (widget.api != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text('Ajouter un exercice antérieur'.tr(context)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _chargement ? null : () => _saisir(),
              ),
            ),
        ],
        bottom: _chargement
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: exercices.isEmpty
          ? Center(
              child: Text(
                'Aucun exercice de fonds propres enregistré.'.tr(context),
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bandeau(context, exercices),
                  const SizedBox(height: 16),
                  _analyseCard(context, exercices),
                  const SizedBox(height: 16),
                  _tableau(context, exercices),
                ],
              ),
            ),
    );
  }

  // ── Bandeau : le total de chaque exercice, et son écart au précédent ──────
  Widget _bandeau(BuildContext context, List<FondsPropresExercice> exercices) {
    final c = DashColors.of(context);
    final unite = PortfolioAmountUnitScope.maybeOf(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < exercices.length; i++)
          _carteExercice(
            context,
            exercices[i],
            // Les exercices vont du plus récent au plus ancien : le suivant
            // dans la liste est le précédent dans le temps.
            precedent: i + 1 < exercices.length ? exercices[i + 1] : null,
            courant: exercices[i].exercice == fondsPropres.exercice,
            unite: unite,
            couleur: c,
          ),
        if (widget.api != null) _tuileAjout(context, c),
      ],
    );
  }

  /// Tuile d'ajout, à la suite des exercices enregistrés.
  ///
  /// Elle porte l'année qui sera proposée : on voit ce qu'on va créer avant
  /// de cliquer, au lieu de le découvrir dans le formulaire.
  Widget _tuileAjout(BuildContext context, DashColors c) {
    final prises = _exercices.map((e) => e.exercice).toList();
    final proposee = prises.isEmpty
        ? DateTime.now().year - 1
        : prises.reduce((a, b) => a < b ? a : b) - 1;
    return InkWell(
      onTap: _chargement ? null : () => _saisir(),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 232,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.indigo.withValues(alpha: 0.55),
            style: BorderStyle.solid,
            width: 1.2,
          ),
          color: Colors.indigo.withValues(alpha: 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.add_circle_outline,
                    size: 16, color: Colors.indigo),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('Ajouter un exercice antérieur'.tr(context),
                      maxLines: 2,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$proposee',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.indigo.withValues(alpha: 0.55))),
            const SizedBox(height: 4),
            Text('Nouvelle ligne d\'historique'.tr(context),
                style: TextStyle(fontSize: 10, color: c.muted)),
          ],
        ),
      ),
    );
  }

  Widget _carteExercice(
    BuildContext context,
    FondsPropresExercice exercice, {
    required FondsPropresExercice? precedent,
    required bool courant,
    required PortfolioAmountUnit? unite,
    required DashColors couleur,
  }) {
    final ecart = precedent == null
        ? null
        : exercice.totalFp - precedent.totalFp;
    final ecartPct = (precedent == null || precedent.totalFp == 0)
        ? null
        : (exercice.totalFp - precedent.totalFp) / precedent.totalFp * 100;

    return Container(
      width: 232,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: courant
            ? couleur.navy.withValues(alpha: 0.05)
            : couleur.surfaceAlt,
        border: Border.all(
          color: courant
              ? couleur.navy.withValues(alpha: 0.45)
              : couleur.divider.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text('Exercice ${exercice.exercice}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: courant ? couleur.navy : couleur.muted)),
              ),
              if (courant) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: couleur.navy.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('déclaré'.tr(context),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: couleur.navy)),
                ),
              ],
              // Corriger ou retirer l'exercice depuis sa propre carte : c'est
              // là qu'on le regarde, c'est là qu'on décide.
              if (widget.api != null) ...[
                const Spacer(),
                IconButton(
                  tooltip: courant
                      ? 'Corriger l\'exercice EN COURS (${exercice.exercice}) '
                          '— pour en ajouter un autre, utilisez la tuile '
                          '« Ajouter un exercice antérieur »'
                      : 'Corriger l\'exercice ${exercice.exercice}',
                  onPressed: _chargement
                      ? null
                      : () => _saisir(initial: exercice),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(Icons.edit_outlined,
                      size: 15, color: couleur.muted),
                ),
                IconButton(
                  tooltip: 'Retirer l\'exercice ${exercice.exercice}',
                  onPressed: _chargement ? null : () => _retirer(exercice),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.delete_outline,
                      size: 15, color: Color(0xFFDC2626)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(_montant(exercice.totalFp, unite),
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: couleur.ink)),
          const SizedBox(height: 4),
          if (ecart == null)
            Text('Aucun exercice antérieur'.tr(context),
                style: TextStyle(fontSize: 10, color: couleur.muted))
          else
            Row(
              children: [
                Icon(
                    ecart >= 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 12,
                    color: ecart >= 0 ? couleur.conforme : couleur.sousMinimum),
                const SizedBox(width: 3),
                Text(
                  '${_montant(ecart.abs(), unite)}'
                  '${ecartPct == null ? '' : ' (${ecartPct.abs().toStringAsFixed(1)} %)'}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color:
                          ecart >= 0 ? couleur.conforme : couleur.sousMinimum),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Analyse des fonds propres déclarés : ce qu'ils produisent, comment ils
  /// se composent, et de combien ils ont bougé.
  Widget _analyseCard(
      BuildContext context, List<FondsPropresExercice> exercices) {
    final c = DashColors.of(context);
    final courant = exercices.isEmpty ? null : exercices.first;
    if (courant == null) return const SizedBox.shrink();
    final precedent = exercices.length > 1 ? exercices[1] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.surfaceAlt.withValues(alpha: 0.5),
        border: Border.all(color: c.divider.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Analyse'.tr(context),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: c.navy)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ce que ces fonds propres affirment, exercice '
                  '${courant.exercice}',
                  style: TextStyle(fontSize: 10.5, color: c.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _prudentiel(context, c),
          const SizedBox(height: 12),
          _composition(context, c, courant),
          if (precedent != null) ...[
            const SizedBox(height: 12),
            _evolution(context, c, courant, precedent),
          ],
        ],
      ),
    );
  }

  /// Les codes EP01 des limites qui se mesurent SUR les fonds propres.
  ///
  /// Elles ont leur place ici et pas ailleurs : leur dénominateur est le
  /// montant que cette page déclare. Un franchissement s'y déduit du CET1
  /// (lignes PA149, IM006, IM010 et PR004 de l'EP03), ce que l'application ne
  /// fait pas encore — d'où la consigne portée sous le relevé.
  static const _codesLimites = [
    'RA006',
    'RA007',
    'RA008',
    'RA009',
    'RA010',
    'RA011',
  ];

  static const _codesRatios = ['RA001', 'RA002', 'RA003'];

  /// Les ratios de solvabilité et les limites adossées aux fonds propres.
  ///
  /// Ils ne se calculent pas ici : ils viennent de l'analyse de la déclaration,
  /// lue par la même fonction que celle d'un fichier déposé. Un second calcul
  /// finirait par diverger du formulaire transmis.
  Widget _prudentiel(BuildContext context, DashColors c) {
    final analyse = _analyse;
    if (analyse == null) {
      return Text(
        'Les ratios de solvabilité ne sont pas disponibles hors connexion.'
            .tr(context),
        style: TextStyle(fontSize: 10.5, color: c.muted),
      );
    }
    return FutureBuilder<AnalyseDeclaration>(
      future: analyse,
      builder: (context, instantane) {
        if (instantane.connectionState == ConnectionState.waiting) {
          return Row(children: [
            const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('Ratios de solvabilité…'.tr(context),
                style: TextStyle(fontSize: 10.5, color: c.muted)),
          ]);
        }
        if (!instantane.hasData) {
          // « Not Found » ne dit rien a personne : c'est la reponse d'un
          // serveur qui ne connait pas la route d'analyse, donc anterieur a
          // celle-ci. Le message doit nommer le geste, pas le code HTTP.
          final erreur = '${instantane.error ?? ''}';
          final routeAbsente = erreur.contains('Not Found') ||
              erreur.contains('404');
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.muted.withValues(alpha: 0.06),
              border: Border.all(color: c.muted.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              routeAbsente
                  ? 'Ratios et limites indisponibles : le serveur joint ne '
                      'connaît pas cette analyse. Il date d\'avant son ajout — '
                      'relancez le backend à jour.'
                  : 'Ratios et limites indisponibles : $erreur',
              style: TextStyle(fontSize: 10.5, color: c.muted),
            ),
          );
        }

        final normes = instantane.data!.normes;
        final ratios =
            normes.where((n) => _codesRatios.contains(n.code)).toList();
        final limites =
            normes.where((n) => _codesLimites.contains(n.code)).toList();
        final franchies = limites
            .where((n) => n.situation == SituationNorme.depassee)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ratios.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [for (final n in ratios) _pastilleRatio(c, n)],
              ),
            if (limites.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Limites adossées aux fonds propres'.tr(context),
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: c.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [for (final n in limites) _pastilleRatio(c, n)],
              ),
              if (franchies.isNotEmpty) ...[
                const SizedBox(height: 8),
                _consigneDeduction(context, c, franchies.length),
              ],
            ],
          ],
        );
      },
    );
  }

  /// Ce qu'un franchissement appelle, en clair.
  ///
  /// L'excedent d'une limite se deduit des fonds propres de base : l'EP03
  /// porte une ligne par limite. L'application ne les alimente pas encore, et
  /// le CET1 declare est donc surestime d'autant — le dire ici, ou le montant
  /// se declare, plutot que dans une reserve lue apres l'export.
  Widget _consigneDeduction(BuildContext context, DashColors c, int nombre) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 15, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$nombre limite(s) franchie(s). Leur excédent se déduit des '
              'fonds propres de base : l\'EP03 le porte sur les lignes PA149, '
              'IM006, IM010 et PR004. L\'application ne les alimente pas '
              'encore — le CET1 déclaré, et les trois ratios ci-dessus, sont '
              'surestimés d\'autant. À corriger à la main avant transmission.',
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pastilleRatio(DashColors c, NormeAnalysee norme) {
    final tenu = norme.situation != SituationNorme.depassee;
    final couleur = norme.situation == SituationNorme.nonMesuree
        ? c.muted
        : (tenu ? c.conforme : c.sousMinimum);
    String pct(double? v) =>
        v == null ? '—' : '${(v * 100).toStringAsFixed(2)} %';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.07),
        border: Border.all(color: couleur.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tenu ? Icons.check_circle_outline : Icons.error_outline,
              size: 13, color: couleur),
          const SizedBox(width: 6),
          Text(norme.libelle,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600, color: c.ink)),
          const SizedBox(width: 8),
          Text('${pct(norme.observe)} / ${pct(norme.seuil)}',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: couleur)),
        ],
      ),
    );
  }

  /// La part de chaque tier dans le total : la qualité des fonds propres se
  /// lit là, pas dans le seul montant.
  Widget _composition(
      BuildContext context, DashColors c, FondsPropresExercice e) {
    if (e.totalFp <= 0) return const SizedBox.shrink();
    String part(double v) => '${(v / e.totalFp * 100).toStringAsFixed(1)} %';
    return Row(
      children: [
        Text('Composition'.tr(context),
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 14, runSpacing: 4, children: [
            _mesure(c, 'CET1', part(e.cet1)),
            _mesure(c, 'AT1', part(e.at1)),
            _mesure(c, 'Tier 2', part(e.tier2)),
          ]),
        ),
      ],
    );
  }

  /// L'écart avec l'exercice précédent, agrégat par agrégat.
  ///
  /// C'est le dénominateur que les limites des EP36 à EP38 utilisent : voir
  /// de combien il a bougé, c'est voir de combien ces limites se déplacent.
  Widget _evolution(BuildContext context, DashColors c,
      FondsPropresExercice courant, FondsPropresExercice precedent) {
    String delta(double n, double p) {
      if (p == 0) return '—';
      final pct = (n - p) / p * 100;
      return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)} %';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${precedent.exercice} → ${courant.exercice}',
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 14, runSpacing: 4, children: [
            _mesure(c, 'CET1', delta(courant.cet1, precedent.cet1)),
            _mesure(c, 'Tier 1', delta(courant.tier1, precedent.tier1)),
            _mesure(c, 'Tier 2', delta(courant.tier2, precedent.tier2)),
            _mesure(c, 'Total', delta(courant.totalFp, precedent.totalFp)),
          ]),
        ),
      ],
    );
  }

  Widget _mesure(DashColors c, String libelle, String valeur) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$libelle ',
          style: TextStyle(fontSize: 10.5, color: c.muted)),
      Text(valeur,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w800, color: c.ink)),
    ]);
  }

  // ── Tableau : un poste par ligne, un exercice par colonne ────────────────
  Widget _tableau(BuildContext context, List<FondsPropresExercice> exercices) {
    final c = DashColors.of(context);
    final unite = PortfolioAmountUnitScope.maybeOf(context);

    final lignes = <_LignePoste>[
      const _LignePoste.groupe('CET1 — Fonds propres de base de catégorie 1'),
      _LignePoste('Capital ordinaire', (e) => e.capitalOrdinaire),
      _LignePoste('Réserves', (e) => e.reserves),
      _LignePoste('Résultats en report', (e) => e.resultatsReport),
      _LignePoste('Résultat éligible', (e) => e.resultatEligible),
      _LignePoste('Réduction prudentielle', (e) => -e.deductionsPrudCet1.abs()),
      _LignePoste('Total CET1', (e) => e.cet1, total: true),
      const _LignePoste.groupe('AT1 — Fonds propres additionnels'),
      _LignePoste('Instruments additionnels', (e) => e.instrumentsAt1),
      _LignePoste("Primes d'émission", (e) => e.primesEmissionAt1),
      _LignePoste('Réduction prudentielle', (e) => -e.deductionsPrudAt1.abs()),
      _LignePoste('Total AT1', (e) => e.at1, total: true),
      _LignePoste('Tier 1 (CET1 + AT1)', (e) => e.tier1, total: true),
      const _LignePoste.groupe('Tier 2 — Capital complémentaire'),
      _LignePoste('Dettes subordonnées', (e) => e.dettesSubordonneesT2),
      _LignePoste('Provisions générales', (e) => e.provisionsGeneralesT2),
      _LignePoste('Réduction prudentielle', (e) => -e.deductionsPrudT2.abs()),
      _LignePoste('Total Tier 2', (e) => e.tier2, total: true),
      const _LignePoste.groupe('Total'),
      _LignePoste('Fonds propres réglementaires', (e) => e.totalFp,
          total: true),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.divider.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, contraintes) {
        final largeurPoste = _largeurPoste(
          exercices.length,
          contraintes.maxWidth,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: largeurPoste + exercices.length * _kLargeurExercice,
            child: Column(
            children: [
              // En-tête : les exercices, du plus récent au plus ancien.
              Container(
                height: 40,
                color: c.navy,
                child: Row(
                  children: [
                    _cellule(
                      Text('Poste'.tr(context),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      largeur: largeurPoste,
                      separateur: Colors.white.withValues(alpha: 0.14),
                    ),
                    for (final exercice in exercices)
                      _cellule(
                        Text('${exercice.exercice}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        largeur: _kLargeurExercice,
                        aDroite: true,
                        separateur: Colors.white.withValues(alpha: 0.14),
                      ),
                  ],
                ),
              ),
              for (var i = 0; i < lignes.length; i++)
                _rendreLigne(
                    context, lignes[i], exercices, unite, i, c, largeurPoste),
            ],
          ),
          ),
        );
      }),
    );
  }

  Widget _rendreLigne(
    BuildContext context,
    _LignePoste ligne,
    List<FondsPropresExercice> exercices,
    PortfolioAmountUnit? unite,
    int rang,
    DashColors c,
    double largeurPoste,
  ) {
    final sep = c.divider.withValues(alpha: 0.45);

    if (ligne.estGroupe) {
      return Container(
        height: 32,
        width: largeurPoste + exercices.length * _kLargeurExercice,
        color: c.surfaceAlt,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Text(ligne.libelle.tr(context),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: c.navy)),
      );
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: ligne.total
            ? c.navy.withValues(alpha: 0.04)
            : (rang.isOdd ? c.surfaceAlt.withValues(alpha: 0.4) : c.surface),
        border: Border(top: BorderSide(color: sep)),
      ),
      child: Row(
        children: [
          _cellule(
            Text(ligne.libelle.tr(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        ligne.total ? FontWeight.w700 : FontWeight.w500,
                    color: ligne.total ? c.ink : c.muted)),
            largeur: largeurPoste,
            separateur: sep,
          ),
          for (final exercice in exercices)
            _cellule(
              Text(_montant(ligne.valeur(exercice), unite),
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          ligne.total ? FontWeight.w800 : FontWeight.w600,
                      color: ligne.valeur(exercice) < 0
                          ? c.sousMinimum
                          : (ligne.total ? c.navy : c.ink))),
              largeur: _kLargeurExercice,
              aDroite: true,
              separateur: sep,
            ),
        ],
      ),
    );
  }

  /// Largeur d'une colonne d'exercice.
  static const double _kLargeurExercice = 160;

  /// Largeur minimale de la colonne des postes : en deçà, les libellés longs
  /// se coupent.
  static const double _kLargeurPosteMin = 320;

  /// La colonne des postes prend ce que les exercices laissent, sans jamais
  /// descendre sous son minimum. Le tableau remplit ainsi la largeur
  /// disponible au lieu de laisser un grand blanc à sa droite ; passé le
  /// minimum, il déborde et se fait défiler.
  static double _largeurPoste(int nombreExercices, double largeurDisponible) {
    final reste = largeurDisponible - nombreExercices * _kLargeurExercice;
    return reste > _kLargeurPosteMin ? reste : _kLargeurPosteMin;
  }

  Widget _cellule(Widget enfant,
      {required double largeur,
      bool aDroite = false,
      required Color separateur}) {
    return Container(
      width: largeur,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: aDroite ? Alignment.centerRight : Alignment.centerLeft,
      decoration:
          BoxDecoration(border: Border(right: BorderSide(color: separateur))),
      child: enfant,
    );
  }

  String _montant(double valeur, PortfolioAmountUnit? unite) {
    if (unite == null) return AppFormatters.compactNumber(valeur);
    return '${AppFormatters.decimalNumber(valeur / unite.divisor, maxDecimals: 3)} '
        '${unite.label}';
  }
}

/// Une ligne du tableau : un poste et la façon de le lire sur un exercice.
class _LignePoste {
  const _LignePoste(this.libelle, this.lecture, {this.total = false})
      : estGroupe = false;

  const _LignePoste.groupe(this.libelle)
      : lecture = null,
        total = false,
        estGroupe = true;

  final String libelle;
  final double Function(FondsPropresExercice)? lecture;
  final bool total;
  final bool estGroupe;

  double valeur(FondsPropresExercice exercice) =>
      lecture == null ? 0.0 : lecture!(exercice);
}
