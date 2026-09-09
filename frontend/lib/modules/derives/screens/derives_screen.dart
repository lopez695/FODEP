import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/widgets/dashboard_design.dart';
import '../models/derive_models.dart';
import '../widgets/derive_formulaire.dart';

/// Registre des instruments dérivés, et l'état EP11 qu'il alimente.
///
/// L'EP11 déclare le risque de contrepartie porté par les dérivés. L'écran
/// montre les deux : les contrats saisis, et les quinze lignes du formulaire
/// telles qu'elles partiront. Une saisie ne se vérifie qu'en regardant la case
/// où elle atterrit — un contrat rangé sous la mauvaise nature ou la mauvaise
/// durée ne se voit pas autrement.
///
/// Un registre vide déclare zéro. C'est légitime pour un établissement qui ne
/// traite pas de dérivés, mais ce n'est pas rien : le formulaire l'affirme au
/// régulateur, et l'écran le dit plutôt que de laisser croire à un oubli.
class DerivesScreen extends StatefulWidget {
  const DerivesScreen({super.key, required this.api});

  final RwaApiService api;

  @override
  State<DerivesScreen> createState() => _DerivesScreenState();
}

/// Les contrats et l'état qu'ils remplissent, chargés ensemble.
typedef _Donnees = ({List<Derive> contrats, SyntheseEp11 synthese});

class _DerivesScreenState extends State<DerivesScreen> {
  late Future<_Donnees> _future;

  @override
  void initState() {
    super.initState();
    _future = _charger();
  }

  Future<_Donnees> _charger() async {
    // Les deux appels partent ensemble : ils ne dépendent pas l'un de l'autre.
    final contrats = widget.api.fetchDerives();
    final synthese = widget.api.fetchSyntheseEp11();
    return (contrats: await contrats, synthese: await synthese);
  }

  void _recharger() {
    // Corps entre accolades : une flèche renverrait le Future affecté, que
    // setState refuse.
    setState(() {
      _future = _charger();
    });
  }

  Future<void> _editer([Derive? existant]) async {
    final saisi = await DeriveFormulaire.show(context, existant);
    if (saisi == null) return;
    try {
      if (existant == null) {
        await widget.api.createDerive(saisi);
      } else {
        await widget.api.updateDerive(saisi);
      }
      _recharger();
    } catch (erreur) {
      _signaler('Enregistrement impossible : $erreur', erreur: true);
    }
  }

  Future<void> _supprimer(Derive contrat) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Retirer ce contrat ?'),
        content: Text(
          '${contrat.contrepartie} — ${contrat.nature.label}.\n\n'
          "Il sortira de l'EP11 : l'exposition déclarée baissera d'autant.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexte, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexte, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true || contrat.id == null) return;
    try {
      await widget.api.deleteDerive(contrat.id!);
      _recharger();
    } catch (erreur) {
      _signaler('Suppression impossible : $erreur', erreur: true);
    }
  }

  void _signaler(String message, {bool erreur = false}) {
    if (!mounted) return;
    final c = DashColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: erreur ? c.sousMinimum : c.conforme,
    ));
  }

  /// Les montants se lisent en millions de FCFA.
  ///
  /// C'est l'unité de la déclaration — « tous les montants doivent être
  /// déclarés en millions de franc CFA » (notice, § 2.3) — et donc la forme
  /// sous laquelle le déclarant les retrouvera sur le classeur transmis.
  String _montant(double valeur) =>
      valeur == 0 ? '—' : AppFormatters.millions(valeur);

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      color: c.surfaceAlt,
      child: FutureBuilder<_Donnees>(
        future: _future,
        builder: (context, instantane) {
          if (instantane.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (instantane.hasError) {
            return _indisponible(c, instantane.error);
          }
          final donnees = instantane.data!;
          return ListView(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            children: [
              _entete(c, donnees.synthese),
              const SizedBox(height: 16),
              for (final alerte in donnees.synthese.alertes) ...[
                _bandeau(c, alerte),
                const SizedBox(height: 12),
              ],
              _contrats(c, donnees.contrats),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _etatEp11(c, donnees.synthese)),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: _ventilation(c, donnees.synthese)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ── En-tête ──────────────────────────────────────────────────────────────

  Widget _entete(DashColors c, SyntheseEp11 synthese) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ÉTAT EP11', style: DashText.eyebrow(c)),
                    const SizedBox(height: 6),
                    Text(
                      'Instruments dérivés',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 720,
                      child: Text(
                        'Swaps de taux, change à terme, contrats sur titres de '
                        'propriété ou produits de base. Chaque contrat est '
                        'décrit une fois ; l\'export en tire la ligne, la '
                        'pondération et l\'exposition du formulaire.',
                        style: TextStyle(
                            fontSize: 12, height: 1.45, color: c.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              FilledButton.icon(
                onPressed: () => _editer(),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Ajouter un contrat'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, thickness: Dash.hairline, color: c.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              _tuile(c, 'CONTRATS', '${synthese.nombre}', null),
              _separateur(c),
              _tuile(c, '(b) NOTIONNEL',
                  _montant(synthese.totalNotionnel), 'Millions de FCFA'),
              _separateur(c),
              _tuile(c, '(a) COÛT DE REMPLACEMENT',
                  _montant(synthese.totalCoutRemplacement), 'Valeur de marché'),
              _separateur(c),
              _tuile(c, '(e) EXPOSITION DÉCLARÉE',
                  _montant(synthese.totalExposition), 'a + (b × c)',
                  accent: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _separateur(DashColors c) => Container(
        width: Dash.hairline,
        height: 46,
        color: c.divider,
        margin: const EdgeInsets.symmetric(horizontal: 20),
      );

  Widget _tuile(DashColors c, String titre, String valeur, String? note,
      {bool accent = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titre, style: DashText.eyebrow(c)),
          const SizedBox(height: 6),
          Text(valeur,
              style: DashText.hero(c,
                  size: 21, color: accent ? c.accent : c.ink)),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(note, style: DashText.caption(c)),
          ],
        ],
      ),
    );
  }

  Widget _bandeau(DashColors c, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: c.sousCible.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: c.sousCible, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: c.sousCible),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 12, height: 1.45, color: c.ink)),
          ),
        ],
      ),
    );
  }

  // ── Les contrats ─────────────────────────────────────────────────────────

  Widget _contrats(DashColors c, List<Derive> contrats) {
    if (contrats.isEmpty) return _registreVide(c);

    return DashPanel(
      title: 'CONTRATS ENREGISTRÉS',
      unit: 'Montants en millions de FCFA',
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _enteteColonnes(c, const [
            (libelle: 'Contrepartie', largeur: 0, alignDroite: false),
            (libelle: 'Catégorie', largeur: 190.0, alignDroite: false),
            (libelle: 'Nature', largeur: 180.0, alignDroite: false),
            (libelle: 'Échéance', largeur: 92.0, alignDroite: false),
            (libelle: 'Durée résiduelle', largeur: 132.0, alignDroite: false),
            (libelle: '(b) Notionnel', largeur: 112.0, alignDroite: true),
            (libelle: '(a) Coût rempl.', largeur: 112.0, alignDroite: true),
            (libelle: '', largeur: 80.0, alignDroite: false),
          ]),
          for (final contrat in contrats) _ligneContrat(c, contrat),
        ],
      ),
    );
  }

  Widget _registreVide(DashColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        children: [
          Icon(Icons.swap_horiz_rounded, size: 30, color: c.faint),
          const SizedBox(height: 12),
          Text('Aucun contrat enregistré',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
          const SizedBox(height: 6),
          SizedBox(
            width: 460,
            child: Text(
              "L'EP11 partira à zéro, ce qui déclare au régulateur que "
              "l'établissement ne porte aucun engagement sur instruments de "
              'taux, de change, de propriété ou de produits de base.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.45, color: c.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligneContrat(DashColors c, Derive contrat) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.divider, width: Dash.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(contrat.contrepartie,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.ink)),
                if (contrat.typeContrat != null)
                  Text(contrat.typeContrat!, style: DashText.caption(c)),
              ],
            ),
          ),
          _cellule(c, 190, contrat.categorieContrepartie.label),
          _cellule(c, 180, contrat.nature.label),
          _cellule(c, 92, _jour(contrat.dateEcheance)),
          SizedBox(
            width: 132,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _puce(c, contrat.tranche.label),
            ),
          ),
          _celluleNombre(c, 112, contrat.montantNotionnel, contrat.devise),
          _celluleNombre(c, 112, contrat.coutRemplacement, contrat.devise),
          // Les deux boutons sont contraints : sans cela `IconButton` impose sa
          // zone de clic de 40 pixels et la ligne déborde de sa colonne.
          SizedBox(
            width: 80,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _action(c, Icons.edit_outlined, 'Modifier',
                  () => _editer(contrat)),
              _action(c, Icons.delete_outline_rounded, 'Retirer',
                  () => _supprimer(contrat)),
            ]),
          ),
        ],
      ),
    );
  }

  /// Un bouton d'action de ligne, réduit à la taille de son icône.
  ///
  /// `constraints` ne suffit pas : `IconButton` réserve par défaut une zone
  /// tactile de 48 pixels, que seule `tapTargetSize` libère. C'est ce qui
  /// faisait déborder la ligne de sa colonne.
  Widget _action(
          DashColors c, IconData icone, String infobulle, VoidCallback action) =>
      IconButton(
        tooltip: infobulle,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icone, size: 16, color: c.muted),
        onPressed: action,
      );

  Widget _cellule(DashColors c, double largeur, String texte) => SizedBox(
        width: largeur,
        child: Text(texte,
            style: TextStyle(fontSize: 11.5, color: c.muted),
            overflow: TextOverflow.ellipsis),
      );

  /// Un montant, avec sa devise d'origine quand elle n'est pas celle du
  /// formulaire : le déclarant doit voir qu'une conversion a eu lieu.
  Widget _celluleNombre(
      DashColors c, double largeur, double valeur, String devise) {
    return SizedBox(
      width: largeur,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_montant(valeur), style: DashText.value(c)),
          if (devise != 'XOF') Text(devise, style: DashText.caption(c)),
        ],
      ),
    );
  }

  static String _jour(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  // ── L'état tel qu'il partira ─────────────────────────────────────────────

  Widget _etatEp11(DashColors c, SyntheseEp11 synthese) {
    return DashPanel(
      title: 'EP11 — TEL QUE LA DÉCLARATION LE PORTERA',
      subtitle: 'La pondération (c) est imprimée par la BCEAO sur le '
          'formulaire ; (d) = b × c et (e) = a + d sont calculés.',
      unit: 'Millions de FCFA',
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _enteteColonnes(c, const [
            (libelle: 'Code', largeur: 62.0, alignDroite: false),
            (libelle: 'Poste', largeur: 0, alignDroite: false),
            (libelle: 'Contrats', largeur: 70.0, alignDroite: true),
            (libelle: '(a)', largeur: 96.0, alignDroite: true),
            (libelle: '(b)', largeur: 96.0, alignDroite: true),
            (libelle: '(c)', largeur: 62.0, alignDroite: true),
            (libelle: '(d)', largeur: 96.0, alignDroite: true),
            (libelle: '(e)', largeur: 96.0, alignDroite: true),
          ]),
          for (final ligne in synthese.lignes) _ligneEp11(c, ligne),
        ],
      ),
    );
  }

  /// Les quinze lignes sont toutes affichées, y compris les vides.
  ///
  /// Elles partent toutes dans la déclaration : voir un zéro là où on
  /// attendait un contrat est précisément ce qu'on vient vérifier ici.
  Widget _ligneEp11(DashColors c, LigneEp11 ligne) {
    final porte = ligne.nombreContrats > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: porte ? c.accent.withValues(alpha: 0.04) : null,
        border: Border(top: BorderSide(color: c.divider, width: Dash.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: _puce(c, ligne.code, teinte: porte ? c.accent : null),
          ),
          Expanded(
            child: Text(
              ligne.libelle,
              style: TextStyle(
                fontSize: 11.5,
                color: porte ? c.ink : c.muted,
                fontWeight: porte ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _nombre(c, 70, porte ? '${ligne.nombreContrats}' : '—', porte),
          _nombre(c, 96, _montant(ligne.coutRemplacement), porte),
          _nombre(c, 96, _montant(ligne.montantNotionnel), porte),
          _nombre(c, 62,
              '${(ligne.ponderation * 100).toStringAsFixed(1)} %', false),
          _nombre(c, 96, _montant(ligne.notionnelPondere), porte),
          _nombre(c, 96, _montant(ligne.exposition), porte, accent: porte),
        ],
      ),
    );
  }

  Widget _nombre(DashColors c, double largeur, String texte, bool porte,
      {bool accent = false}) {
    return SizedBox(
      width: largeur,
      child: Text(
        texte,
        textAlign: TextAlign.right,
        style: DashText.value(c,
            color: accent ? c.accent : (porte ? c.ink : c.faint),
            weight: accent ? FontWeight.w700 : FontWeight.w500),
      ),
    );
  }

  /// La ventilation de l'exposition par catégorie de contrepartie.
  ///
  /// Le formulaire l'étale sur cinq colonnes ; les poser à côté du tableau
  /// principal l'aurait rendu illisible, et elles se lisent aussi bien en
  /// total — la somme retombe par construction sur l'exposition déclarée.
  Widget _ventilation(DashColors c, SyntheseEp11 synthese) {
    final totaux = <String, double>{};
    for (final ligne in synthese.lignes) {
      ligne.ventilation.forEach((categorie, montant) {
        totaux[categorie] = (totaux[categorie] ?? 0) + montant;
      });
    }

    return DashPanel(
      title: 'VENTILATION (e)',
      unit: 'Par contrepartie',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final categorie in CategorieContrepartieDerive.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(categorie.label,
                        style: TextStyle(fontSize: 11.5, color: c.muted)),
                  ),
                  const SizedBox(width: 8),
                  Text(_montant(totaux[categorie.wire] ?? 0),
                      style: DashText.value(c,
                          color: (totaux[categorie.wire] ?? 0) > 0
                              ? c.ink
                              : c.faint)),
                ],
              ),
            ),
          Divider(height: 14, thickness: Dash.hairline, color: c.divider),
          Row(
            children: [
              Expanded(
                child: Text('Total',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: c.ink)),
              ),
              Text(_montant(synthese.totalExposition),
                  style: DashText.value(c,
                      color: c.accent, weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Fragments communs ────────────────────────────────────────────────────

  Widget _enteteColonnes(
    DashColors c,
    List<({String libelle, double largeur, bool alignDroite})> colonnes,
  ) {
    Widget cellule(({String libelle, double largeur, bool alignDroite}) col) {
      final texte = Text(
        col.libelle.toUpperCase(),
        textAlign: col.alignDroite ? TextAlign.right : TextAlign.left,
        style: DashText.eyebrow(c, color: c.faint).copyWith(fontSize: 9.5),
      );
      return col.largeur == 0
          ? Expanded(child: texte)
          : SizedBox(width: col.largeur, child: texte);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [for (final col in colonnes) cellule(col)]),
    );
  }

  /// Une pastille : code DISPRU ou tranche de durée. Courte, discrète, et
  /// alignée — c'est par elle qu'on retrouve la case sur le formulaire.
  Widget _puce(DashColors c, String texte, {Color? teinte}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: (teinte ?? c.muted).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          texte,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: teinte ?? c.muted,
            fontFeatures: Dash.tabular,
          ),
        ),
      ),
    );
  }

  Widget _indisponible(DashColors c, Object? erreur) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 32, color: c.faint),
            const SizedBox(height: 12),
            Text(
              _messageDeChargement(erreur, 'Registre des dérivés indisponible'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: c.muted),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
                onPressed: _recharger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

/// Ce qu'il faut comprendre d'une erreur de chargement.
///
/// « Not Found » ne dit rien à personne : c'est la réponse d'un serveur qui ne
/// connaît pas la route, donc antérieur à son ajout. Le piège est que le script
/// de lancement réutilise un backend déjà en écoute — relancer l'application ne
/// suffit pas, il faut arrêter le processus.
String _messageDeChargement(Object? erreur, String quoi) {
  final texte = '${erreur ?? ''}';
  final routeAbsente = texte.contains('Not Found') || texte.contains('404');
  if (routeAbsente) {
    return '$quoi : le serveur joint ne connaît pas cette route. Il date '
        "d'avant son ajout — arrêtez le backend puis relancez-le, le script "
        'réutilise celui qui écoute déjà.';
  }
  return '$quoi : $texte';
}
