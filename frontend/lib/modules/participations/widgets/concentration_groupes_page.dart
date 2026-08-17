import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/utils/formatters.dart';
import '../models/participation_models.dart';
import 'jauge_limite.dart';
import 'tableau_maison.dart';

/// Nombre de membres retenus dans chaque analyse de groupe.
///
/// Cinq lignes suffisent à dire où le risque se loge : au-delà, la queue de
/// distribution pèse trop peu pour changer une décision, et le tableau complet
/// reste consultable dans le détail du groupe.
const int _tailleDuTop = 5;

/// Unité d'affichage des montants : le million de francs.
///
/// Tous les montants de la page sont exprimés dans cette unité, axes des
/// graphiques compris. Une page qui mélangerait les unités ferait comparer des
/// chiffres qui ne se comparent pas.
const double _million = 1000000;

/// Membres portant réellement une exposition, du plus lourd au plus léger.
///
/// Le tri est refait ici plutôt que présumé : un membre à zéro n'est pas une
/// concentration, et un classement faux se voit moins qu'une somme fausse.
List<MembreConcentration> _membresPorteurs(ConcentrationGroupe groupe) {
  return groupe.membres.where((membre) => membre.exposition > 0).toList()
    ..sort((a, b) => b.exposition.compareTo(a.exposition));
}

/// Les cinq premiers membres d'un groupe.
List<MembreConcentration> _topDuGroupe(ConcentrationGroupe groupe) =>
    _membresPorteurs(groupe).take(_tailleDuTop).toList();

/// Ce que l'indice de Herfindahl veut dire en français.
String _lectureHerfindahl(double indice) {
  if (indice >= 0.5) return 'très concentré';
  if (indice >= 0.25) return 'concentré';
  return 'réparti';
}

/// Couleurs des cinq premiers membres.
///
/// Le rang d'un membre lui donne sa couleur partout dans la page : le premier
/// des barres de répartition de la section 3 est le premier de l'histogramme
/// de la section 4. Une couleur qui changerait d'un graphique à l'autre
/// obligerait à relire les légendes à chaque fois.
List<Color> _palette(ThemeData theme) => <Color>[
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
      theme.colorScheme.secondary,
      theme.colorScheme.error,
      theme.colorScheme.primaryContainer,
    ];

/// Concentration des groupes de clients liés, section par section.
///
/// Un groupe existe pour additionner les risques portés sur des contreparties
/// qu'un même contrôle fait tomber ensemble. La page suit l'ordre dans lequel
/// la question se pose : le périmètre, puis quel groupe pèse le plus, puis le
/// détail d'un groupe, puis les cinq premiers membres de chacun, puis la
/// lecture d'ensemble.
class ConcentrationGroupesPage extends StatefulWidget {
  const ConcentrationGroupesPage({super.key, required this.api});

  final RwaApiService api;

  static Future<void> ouvrir(BuildContext context, RwaApiService api) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConcentrationGroupesPage(api: api),
      ),
    );
  }

  @override
  State<ConcentrationGroupesPage> createState() =>
      _ConcentrationGroupesPageState();
}

class _ConcentrationGroupesPageState extends State<ConcentrationGroupesPage> {
  late Future<ConcentrationGroupes> _future;
  int _selection = 0;

  /// Ancre de la section de détail, pour y amener le lecteur quand il choisit
  /// un groupe depuis une autre section.
  final GlobalKey _ancreDetail = GlobalKey();

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchConcentrationGroupes();
  }

  void _recharger() {
    setState(() {
      _future = widget.api.fetchConcentrationGroupes();
    });
  }

  void _selectionner(int index, {bool remonter = false}) {
    setState(() => _selection = index);
    if (!remonter) return;
    final contexte = _ancreDetail.currentContext;
    if (contexte == null) return;
    Scrollable.ensureVisible(
      contexte,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // Un bouton nommé plutôt qu'une flèche seule : l'écran s'ouvre par
        // dessus le portefeuille, et le lecteur doit voir comment en sortir
        // sans avoir à deviner ce que l'icône recouvre.
        leadingWidth: 128,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: BoutonEnTete(
            icone: Icons.arrow_back,
            libelle: 'Retour',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          'Concentration des groupes de clients liés',
          style: theme.textTheme.titleMedium?.copyWith(
            color: _entete,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // Écran de lecture seule : aucune action n'y écrit, donc aucune n'est
          // principale.
          BoutonEnTete(
            icone: Icons.refresh,
            libelle: 'Recalculer',
            onPressed: _recharger,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<ConcentrationGroupes>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Chargement impossible : ${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _recharger,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final donnees = snapshot.data!;
          if (donnees.groupes.isEmpty) {
            return const Center(
              child: Text('Aucun groupe constitué : rien à comparer.'),
            );
          }

          final index = _selection.clamp(0, donnees.groupes.length - 1);
          final groupe = donnees.groupes[index];

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                children: [
                  _Section(
                    numero: 1,
                    titre: 'Périmètre',
                    sousTitre:
                        'Ce que couvrent les groupes constitués, et face à '
                        'quels fonds propres ils sont appréciés.',
                    enfant: _Perimetre(donnees: donnees),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    numero: 2,
                    titre: 'Poids de chaque groupe',
                    sousTitre:
                        'En part des fonds propres de base T1 · seuil du grand '
                        'risque à '
                        '${(donnees.seuilGrandRisque * 100).toStringAsFixed(0)} % · '
                        'sélectionnez un groupe pour son détail.',
                    enfant: _PoidsDesGroupes(
                      donnees: donnees,
                      selection: index,
                      onSelection: (valeur) =>
                          _selectionner(valeur, remonter: true),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    key: _ancreDetail,
                    numero: 3,
                    titre: 'Détail du groupe',
                    sousTitre:
                        'Chiffres clés, répartition interne et liste complète '
                        'des membres.',
                    action: _ChoixDuGroupe(
                      groupes: donnees.groupes,
                      selection: index,
                      onSelection: _selectionner,
                    ),
                    enfant: _DetailGroupe(groupe: groupe, donnees: donnees),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    numero: 4,
                    titre: 'Top $_tailleDuTop des membres',
                    sousTitre:
                        'Les $_tailleDuTop membres les plus exposés du groupe '
                        'choisi, en millions de FCFA.',
                    // Un groupe à la fois, choisi ici comme à la section 3.
                    // Empiler une carte par groupe faisait grandir la page avec
                    // le portefeuille, alors qu'un seul classement se lit à la
                    // fois : à dix groupes, il fallait défiler pour atteindre la
                    // section suivante.
                    action: _ChoixDuGroupe(
                      groupes: donnees.groupes,
                      selection: index,
                      onSelection: _selectionner,
                    ),
                    enfant: _CarteTopGroupe(
                      groupe: groupe,
                      onDetail: () => _selectionner(index, remonter: true),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    numero: 5,
                    titre: 'Analyse',
                    sousTitre:
                        'Ce que les graphiques ne disent pas d\'eux-mêmes.',
                    enfant: _Analyse(donnees: donnees),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cadre commun des sections : un numéro, un titre, une intention.
class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.numero,
    required this.titre,
    required this.sousTitre,
    required this.enfant,
    this.action,
  });

  final int numero;
  final String titre;
  final String sousTitre;
  final Widget enfant;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$numero',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(sousTitre, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 16),
                  action!,
                ],
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(20),
            child: enfant,
          ),
        ],
      ),
    );
  }
}

/// Section 1 : ce que pèsent les groupes dans l'ensemble du portefeuille.
class _Perimetre extends StatelessWidget {
  const _Perimetre({required this.donnees});

  final ConcentrationGroupes donnees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalGroupes = donnees.groupes.fold<double>(
      0,
      (somme, groupe) => somme + groupe.expositionTotale,
    );
    final depassements =
        donnees.groupes.where((groupe) => groupe.depasseLeSeuil).length;
    final couverture = donnees.expositionPortefeuille > 0
        ? totalGroupes / donnees.expositionPortefeuille
        : 0.0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Indicateur(
          libelle: 'Fonds propres de base T1',
          valeur: AppFormatters.millions(donnees.fondsPropresT1),
          precision: 'référence de la division des risques',
        ),
        _Indicateur(
          libelle: 'Exposition groupée',
          valeur: AppFormatters.millions(totalGroupes),
          precision: 'bilan et hors bilan après CCF',
        ),
        _Indicateur(
          libelle: 'Couverture du portefeuille',
          valeur: '${(couverture * 100).toStringAsFixed(1)} %',
          precision:
              'sur ${AppFormatters.millions(donnees.expositionPortefeuille)} au total',
        ),
        _Indicateur(
          libelle: 'Groupes constitués',
          valeur: '${donnees.groupes.length}',
          precision: depassements == 0
              ? 'aucun au-dessus du seuil'
              : '$depassements au-dessus du seuil',
          couleur: depassements == 0 ? null : theme.colorScheme.error,
        ),
        _Indicateur(
          libelle: 'Seuil du grand risque',
          valeur: '${(donnees.seuilGrandRisque * 100).toStringAsFixed(0)} %',
          precision: 'part maximale des fonds propres T1',
        ),
      ],
    );
  }
}

// Palette des tableaux de l'application : celle des expositions NPL et des
// groupes de clients liés, dans l'onglet Portefeuille. Un écran de détail qui
// s'en écarterait obligerait le lecteur à réapprendre la grille.
const Color _entete = Color(0xFF001F4E);
const Color _bordure = Color(0xFFDCE4F2);
const Color _ligneAlternee = Color(0xFFF8FAFC);
const Color _texteFort = Color(0xFF1E293B);

const double _largeurRang = 34;

/// Contenu d'une cellule, avec le retrait propre à la colonne du rang.
Widget _contenuCellule({required Widget enfant, required bool colonneRang}) {
  return Container(
    padding: colonneRang
        ? const EdgeInsets.only(left: 12, top: 10, bottom: 10)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    alignment: Alignment.centerLeft,
    child: enfant,
  );
}

/// Une cellule et son filet, à poser directement dans la ligne.
///
/// La fonction rend une liste plutôt qu'un widget : un `Expanded` doit être
/// l'enfant direct de la `Row` qui le mesure. L'envelopper dans une `Row`
/// intermédiaire lui donnerait une largeur infinie à répartir, ce que Flutter
/// refuse.
List<Widget> _cellule({required Widget enfant, int? flex, double? largeur}) {
  final contenu = _contenuCellule(
    enfant: enfant,
    colonneRang: largeur == _largeurRang,
  );
  return [
    if (largeur != null)
      SizedBox(width: largeur, child: contenu)
    else
      Expanded(flex: flex ?? 1, child: contenu),
    Container(width: 0.5, color: _bordure),
  ];
}

/// En-tête d'un tableau, dans le bandeau bleu marine de l'application.
Widget _enteteTableau(
  BuildContext context,
  List<({String libelle, int? flex, double? largeur})> colonnes,
) {
  return Container(
    color: _entete,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final colonne in colonnes)
            ..._cellule(
              flex: colonne.flex,
              largeur: colonne.largeur,
              enfant: Text(
                colonne.libelle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Couleur d'une limite selon la part de son plafond déjà consommée.
///
/// Le rouge signale le dépassement, l'ambre la marge inférieure à 20 % : une
/// limite qui se rapproche doit se voir avant d'être franchie, pas après.
Color _couleurConsommation(double consommation, ThemeData theme) {
  if (consommation > 1) return theme.colorScheme.error;
  if (consommation >= 0.8) return theme.colorScheme.tertiary;
  return theme.colorScheme.primary;
}

/// Section 2 : poids de chaque groupe, rapporté aux fonds propres de base.
///
/// La jauge mesure la part du plafond consommée, et non la part des fonds
/// propres : la largeur entière vaut donc le seuil de 25 %. C'est le seul
/// cadrage où la limite reste visible quel que soit le portefeuille — à
/// l'échelle des montants, un repère posé à 25 % se confond avec le bord droit
/// tant qu'aucun groupe n'en approche, et la norme disparaît de l'écran.
class _PoidsDesGroupes extends StatelessWidget {
  const _PoidsDesGroupes({
    required this.donnees,
    required this.selection,
    required this.onSelection,
  });

  final ConcentrationGroupes donnees;
  final int selection;
  final ValueChanged<int> onSelection;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: _bordure)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _enteteTableau(context, const [
            (libelle: 'N°', flex: null, largeur: _largeurRang),
            (libelle: 'Groupe', flex: 4, largeur: null),
            (libelle: 'Exposition', flex: 3, largeur: null),
            (libelle: 'Part des FP T1', flex: 2, largeur: null),
            (libelle: 'Consommation du seuil', flex: 5, largeur: null),
            (libelle: 'Marge avant seuil', flex: 3, largeur: null),
          ]),
          Container(height: 0.5, color: _bordure),
          for (var i = 0; i < donnees.groupes.length; i++)
            _LigneDuGroupe(
              rang: i + 1,
              groupe: donnees.groupes[i],
              seuil: donnees.seuilGrandRisque,
              fondsPropresT1: donnees.fondsPropresT1,
              selectionne: i == selection,
              onTap: () => onSelection(i),
            ),
        ],
      ),
    );
  }
}

class _LigneDuGroupe extends StatelessWidget {
  const _LigneDuGroupe({
    required this.rang,
    required this.groupe,
    required this.seuil,
    required this.fondsPropresT1,
    required this.selectionne,
    required this.onTap,
  });

  final int rang;
  final ConcentrationGroupe groupe;
  final double seuil;
  final double fondsPropresT1;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consommation =
        seuil > 0 ? groupe.partFondsPropres / seuil : 0.0;
    final couleur = _couleurConsommation(consommation, theme);
    // Ce qu'il reste à porter avant d'atteindre le plafond, en francs : c'est
    // le montant sur lequel une décision d'engagement se prend.
    final marge = seuil * fondsPropresT1 - groupe.expositionTotale;

    return Material(
      color: selectionne
          ? theme.colorScheme.primary.withValues(alpha: 0.06)
          : (rang.isEven ? _ligneAlternee : Colors.white),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._cellule(
                    largeur: _largeurRang,
                    enfant: Text(
                      '$rang'.padLeft(2, '0'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ..._cellule(
                    flex: 4,
                    enfant: Row(
                      children: [
                        if (selectionne)
                          Container(
                            width: 3,
                            height: 16,
                            margin: const EdgeInsets.only(right: 8),
                            color: theme.colorScheme.primary,
                          ),
                        Expanded(
                          child: Text(
                            groupe.nom,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _texteFort,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._cellule(
                    flex: 3,
                    enfant: Text(
                      AppFormatters.millions(groupe.expositionTotale),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _entete,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ..._cellule(
                    flex: 2,
                    enfant: Text(
                      '${(groupe.partFondsPropres * 100).toStringAsFixed(2)} %',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: couleur,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ..._cellule(
                    flex: 5,
                    enfant: _JaugeSeuil(
                      consommation: consommation,
                      couleur: couleur,
                    ),
                  ),
                  ..._cellule(
                    flex: 3,
                    enfant: Text(
                      marge >= 0
                          ? AppFormatters.millions(marge)
                          : '− ${AppFormatters.millions(marge.abs())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: marge >= 0 ? _texteFort : theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: _bordure),
          ],
        ),
      ),
    );
  }
}

/// Jauge de consommation d'un plafond : pleine, elle vaut la limite.
class _JaugeSeuil extends StatelessWidget {
  const _JaugeSeuil({required this.consommation, required this.couleur});

  final double consommation;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: consommation.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(couleur),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            '${(consommation * 100).toStringAsFixed(0)} %',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: couleur,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sélecteur de groupe, dans l'en-tête de la section de détail.
class _ChoixDuGroupe extends StatelessWidget {
  const _ChoixDuGroupe({
    required this.groupes,
    required this.selection,
    required this.onSelection,
  });

  final List<ConcentrationGroupe> groupes;
  final int selection;
  final ValueChanged<int> onSelection;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: DropdownButtonFormField<int>(
        initialValue: selection,
        isDense: true,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Groupe',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          for (var i = 0; i < groupes.length; i++)
            DropdownMenuItem<int>(
              value: i,
              child: Text(groupes[i].nom, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (valeur) {
          if (valeur != null) onSelection(valeur);
        },
      ),
    );
  }
}

/// Section 3 : détail du groupe sélectionné.
class _DetailGroupe extends StatelessWidget {
  const _DetailGroupe({required this.groupe, required this.donnees});

  final ConcentrationGroupe groupe;
  final ConcentrationGroupes donnees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final porteurs = _membresPorteurs(groupe);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(groupe.nom, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    groupe.numeroCentraleRisques == null ||
                            groupe.numeroCentraleRisques!.isEmpty
                        ? 'Aucun numéro de centrale des risques renseigné.'
                        : 'N° centrale des risques : ${groupe.numeroCentraleRisques}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (groupe.depasseLeSeuil)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Grand risque',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Indicateur(
              libelle: 'Exposition du groupe',
              valeur: AppFormatters.millions(groupe.expositionTotale),
              precision: 'FCFA, bilan et hors bilan',
            ),
            _Indicateur(
              libelle: 'Part des fonds propres T1',
              valeur: '${(groupe.partFondsPropres * 100).toStringAsFixed(2)} %',
              precision:
                  'seuil ${(donnees.seuilGrandRisque * 100).toStringAsFixed(0)} %',
              couleur: groupe.depasseLeSeuil ? theme.colorScheme.error : null,
            ),
            _Indicateur(
              libelle: 'Membres',
              valeur: '${groupe.membres.length}',
              precision: '${porteurs.length} avec exposition',
            ),
            _Indicateur(
              libelle: 'Herfindahl',
              valeur: groupe.herfindahl.toStringAsFixed(2),
              precision: _lectureHerfindahl(groupe.herfindahl),
            ),
            _Indicateur(
              libelle: 'Premier membre',
              valeur:
                  '${(groupe.partDuPlusGrosMembre * 100).toStringAsFixed(0)} %',
              precision: porteurs.isEmpty ? '—' : porteurs.first.nom,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SousTitre(
          titre: 'Répartition interne',
          precision: porteurs.length > _tailleDuTop
              ? 'Les $_tailleDuTop premiers membres, le reste regroupé.'
              : 'Exposition répartie entre les membres du groupe.',
        ),
        const SizedBox(height: 12),
        if (porteurs.isEmpty)
          Text(
            'Aucun membre de ce groupe ne porte d\'exposition.',
            style: theme.textTheme.bodySmall,
          )
        else
          _Repartition(groupe: groupe, porteurs: porteurs),
        if (porteurs.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SousTitre(
            titre: 'Tous les membres',
            precision:
                'Cumul : ce que portent ensemble les membres jusqu\'à cette ligne.',
          ),
          const SizedBox(height: 10),
          _TableauMembres(groupe: groupe),
        ],
      ],
    );
  }
}

class _SousTitre extends StatelessWidget {
  const _SousTitre({required this.titre, required this.precision});

  final String titre;
  final String precision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        Text(precision, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Répartition interne du groupe, en barres horizontales.
///
/// La longueur d'une barre est la part du groupe, la largeur entière valant
/// le groupe tout entier. Deux membres à 58 % et 42 % se comparent alors d'un
/// coup d'œil, et la piste restante dit ce que les autres portent — ce qu'un
/// anneau n'exprime qu'au prix d'une lecture d'angles.
class _Repartition extends StatelessWidget {
  const _Repartition({required this.groupe, required this.porteurs});

  final ConcentrationGroupe groupe;
  final List<MembreConcentration> porteurs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(theme);
    final total = groupe.expositionTotale;
    final tete = porteurs.take(_tailleDuTop).toList();
    final reste = porteurs.skip(_tailleDuTop).toList();
    final montantReste =
        reste.fold<double>(0, (somme, membre) => somme + membre.exposition);

    final parts = <({String nom, double montant, double part, Color couleur})>[
      for (var i = 0; i < tete.length; i++)
        (
          nom: tete[i].nom,
          montant: tete[i].exposition,
          part: tete[i].partDuGroupe,
          couleur: palette[i % palette.length],
        ),
      if (reste.isNotEmpty)
        (
          nom: '${reste.length} autre(s) membre(s)',
          montant: montantReste,
          part: total > 0 ? montantReste / total : 0.0,
          couleur: theme.colorScheme.outlineVariant,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final part in parts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: part.couleur,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: Text(
                    part.nom,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _texteFort,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: _BarreHorizontale(
                    part: part.part,
                    couleur: part.couleur,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${(part.part * 100).toStringAsFixed(1)} %',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _texteFort,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(
                  width: 104,
                  child: Text(
                    AppFormatters.millions(part.montant),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _entete,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Une barre dont la piste entière vaut le groupe.
class _BarreHorizontale extends StatelessWidget {
  const _BarreHorizontale({required this.part, required this.couleur});

  final double part;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 10,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          FractionallySizedBox(
            widthFactor: part.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: couleur,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tous les membres du groupe, avec le cumul de leurs parts.
class _TableauMembres extends StatelessWidget {
  const _TableauMembres({required this.groupe});

  final ConcentrationGroupe groupe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final porteurs = _membresPorteurs(groupe);
    final sansExposition =
        groupe.membres.where((membre) => membre.exposition <= 0).toList();

    final lignes = <Widget>[];
    var cumul = 0.0;
    for (var i = 0; i < porteurs.length; i++) {
      cumul += porteurs[i].partDuGroupe;
      lignes.add(
        _LigneMembre(
          rang: '${i + 1}'.padLeft(2, '0'),
          nom: porteurs[i].nom,
          montant: AppFormatters.millions(porteurs[i].exposition),
          part: '${(porteurs[i].partDuGroupe * 100).toStringAsFixed(1)} %',
          cumul: '${(cumul * 100).toStringAsFixed(1)} %',
          dansLeTop: i < _tailleDuTop,
          alternee: i.isOdd,
        ),
      );
    }
    for (var i = 0; i < sansExposition.length; i++) {
      lignes.add(
        _LigneMembre(
          rang: '—',
          nom: sansExposition[i].nom,
          montant: '—',
          part: '—',
          cumul: '—',
          dansLeTop: false,
          alternee: (porteurs.length + i).isOdd,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: _bordure)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _enteteTableau(context, const [
            (libelle: 'N°', flex: null, largeur: _largeurRang),
            (libelle: 'Membre', flex: 5, largeur: null),
            (libelle: 'Exposition', flex: 3, largeur: null),
            (libelle: 'Part du groupe', flex: 2, largeur: null),
            (libelle: 'Cumul', flex: 2, largeur: null),
          ]),
          Container(height: 0.5, color: _bordure),
          ...lignes,
          if (sansExposition.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _ligneAlternee,
              child: Text(
                '${sansExposition.length} membre(s) rattaché(s) sans exposition : '
                'ils élargissent le périmètre du groupe sans en changer le poids.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _LigneMembre extends StatelessWidget {
  const _LigneMembre({
    required this.rang,
    required this.nom,
    required this.montant,
    required this.part,
    required this.cumul,
    required this.dansLeTop,
    required this.alternee,
  });

  final String rang;
  final String nom;
  final String montant;
  final String part;
  final String cumul;

  /// Les cinq premiers portent l'essentiel : ils se lisent en gras, comme dans
  /// l'histogramme de la section suivante.
  final bool dansLeTop;

  final bool alternee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poids = dansLeTop ? FontWeight.w700 : FontWeight.w500;
    final couleur = dansLeTop
        ? _texteFort
        : _texteFort.withValues(alpha: 0.72);

    Widget texte(String valeur, {Color? teinte}) => Text(
          valeur,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: teinte ?? couleur,
            fontWeight: poids,
            fontSize: 12,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: alternee ? _ligneAlternee : Colors.white,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._cellule(
                  largeur: _largeurRang,
                  enfant: Text(
                    rang,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                ..._cellule(flex: 5, enfant: texte(nom)),
                ..._cellule(
                  flex: 3,
                  enfant: texte(montant, teinte: dansLeTop ? _entete : null),
                ),
                ..._cellule(flex: 2, enfant: texte(part)),
                ..._cellule(flex: 2, enfant: texte(cumul)),
              ],
            ),
          ),
        ),
        Container(height: 0.5, color: _bordure),
      ],
    );
  }
}

/// Un chiffre clé du périmètre ou du groupe.
class _Indicateur extends StatelessWidget {
  const _Indicateur({
    required this.libelle,
    required this.valeur,
    required this.precision,
    this.couleur,
  });

  final String libelle;
  final String valeur;
  final String precision;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 224,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border.all(color: _bordure),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valeur,
            style: theme.textTheme.titleMedium?.copyWith(
              color: couleur ?? _entete,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            precision,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// Section 4 : top 5 des membres de chaque groupe, tous groupes confondus.
///
/// Une analyse qui ne montrerait que le groupe sélectionné obligerait à cliquer
/// partout pour savoir où se loge le risque : ce bloc donne la réponse d'un
/// seul regard, groupe par groupe.
/// Classement du groupe choisi : l'histogramme de son top et sa légende.
class _CarteTopGroupe extends StatelessWidget {
  const _CarteTopGroupe({
    required this.groupe,
    required this.onDetail,
  });

  final ConcentrationGroupe groupe;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final porteurs = _membresPorteurs(groupe);
    final top = _topDuGroupe(groupe);
    final partDuTop =
        top.fold<double>(0, (somme, membre) => somme + membre.partDuGroupe);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Bordure neutre : la carte étant seule, un liseré de sélection
        // n'aurait plus rien à distinguer.
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
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
                    Text(
                      groupe.nom,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${AppFormatters.millions(groupe.expositionTotale)} · '
                      '${porteurs.length} membre(s) exposé(s) · '
                      'Herfindahl ${groupe.herfindahl.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: groupe.depasseLeSeuil
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onDetail,
                child: const Text('Voir le détail'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (top.isEmpty)
            Text(
              'Aucun membre porteur d\'exposition : rien à classer.',
              style: theme.textTheme.bodySmall,
            )
          else
            LayoutBuilder(
              builder: (context, contraintes) {
                final graphique = _HistogrammeTop(groupe: groupe, top: top);
                final legende = _LegendeTop(top: top);
                // En dessous de cette largeur, mettre le graphique et le
                // tableau côte à côte écraserait les deux.
                if (contraintes.maxWidth < 880) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      graphique,
                      const SizedBox(height: 16),
                      legende,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: graphique),
                    const SizedBox(width: 24),
                    SizedBox(width: 420, child: legende),
                  ],
                );
              },
            ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              porteurs.length > _tailleDuTop
                  ? 'Ces ${top.length} membres portent '
                      '${(partDuTop * 100).toStringAsFixed(0)} % du groupe, '
                      'sur ${porteurs.length} membres exposés.'
                  : 'Le groupe ne compte que ${porteurs.length} membre(s) '
                      'exposé(s) : le classement est complet.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Histogramme vertical du top 5 d'un groupe.
///
/// Une barre par membre, à la même échelle pour tout le groupe : la hauteur se
/// compare directement, ce qu'un camembert ne permet pas au-delà de deux ou
/// trois parts.
class _HistogrammeTop extends StatelessWidget {
  const _HistogrammeTop({required this.groupe, required this.top});

  final ConcentrationGroupe groupe;
  final List<MembreConcentration> top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(theme);
    final montants = top.map((membre) => membre.exposition / _million).toList();
    final maximum = montants.reduce((a, b) => a > b ? a : b);
    // Marge au-dessus de la plus haute barre : sans elle, la barre touche le
    // bord et l'échelle paraît tronquée.
    final plafond = maximum > 0 ? maximum * 1.18 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exposition en millions de FCFA',
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: plafond,
              minY: 0,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final membre = top[groupIndex];
                    return BarTooltipItem(
                      '${membre.nom}\n',
                      theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w500,
                          ) ??
                          const TextStyle(),
                      children: [
                        TextSpan(
                          text: '${AppFormatters.millions(membre.exposition)} · '
                              '${(membre.partDuGroupe * 100).toStringAsFixed(1)} % du groupe',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= top.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: SizedBox(
                          width: 96,
                          child: Text(
                            '${index + 1}. ${top[index].nom}',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    interval: plafond / 4,
                    getTitlesWidget: (value, meta) {
                      if (value > plafond * 0.99) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: Text(
                          AppFormatters.decimalNumber(value, maxDecimals: 0),
                          style: theme.textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: plafond / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.dividerColor,
                  strokeWidth: 1,
                  dashArray: const [4, 4],
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor, width: 1.5),
                ),
              ),
              barGroups: [
                for (var i = 0; i < top.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: montants[i],
                        width: 30,
                        color: palette[i % palette.length],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Lecture chiffrée de l'histogramme : rang, montant, part, cumul.
///
/// La pastille reprend la couleur de la barre : c'est le même membre, et deux
/// codes couleur pour une même donnée obligeraient à faire le rapprochement de
/// tête.
class _LegendeTop extends StatelessWidget {
  const _LegendeTop({required this.top});

  final List<MembreConcentration> top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(theme);

    final lignes = <Widget>[];
    var cumul = 0.0;
    for (var i = 0; i < top.length; i++) {
      cumul += top[i].partDuGroupe;
      lignes.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: i.isOdd ? _ligneAlternee : Colors.white,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._cellule(
                      largeur: _largeurRang,
                      enfant: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: palette[i % palette.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    ..._cellule(
                      flex: 5,
                      enfant: Text(
                        '${i + 1}. ${top[i].nom}',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _texteFort,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ..._cellule(
                      flex: 3,
                      enfant: Text(
                        AppFormatters.millions(top[i].exposition),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _entete,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ..._cellule(
                      flex: 2,
                      enfant: Text(
                        '${(top[i].partDuGroupe * 100).toStringAsFixed(1)} %',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _texteFort,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ..._cellule(
                      flex: 2,
                      enfant: Text(
                        '${(cumul * 100).toStringAsFixed(1)} %',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _texteFort,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 0.5, color: _bordure),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: _bordure)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _enteteTableau(context, const [
            (libelle: '', flex: null, largeur: _largeurRang),
            (libelle: 'Membre', flex: 5, largeur: null),
            (libelle: 'Exposition', flex: 3, largeur: null),
            (libelle: 'Part', flex: 2, largeur: null),
            (libelle: 'Cumul', flex: 2, largeur: null),
          ]),
          Container(height: 0.5, color: _bordure),
          ...lignes,
        ],
      ),
    );
  }
}

/// Ton d'un constat : ce qu'il appelle de la part du lecteur.
///
/// Un constat rassurant et un constat qui demande une décision ne se lisent
/// pas de la même façon. Une liste à puces les met au même rang et oblige à
/// tout lire pour trouver ce qui compte.
enum _Ton {
  fait('Constat', Icons.insights_outlined, Color(0xFF1E293B)),
  favorable('Conforme', Icons.check_circle_outline, limiteRespectee),
  vigilance('À surveiller', Icons.trending_up, limiteProche),
  alerte('À corriger', Icons.error_outline, limiteDepassee);

  const _Ton(this.libelle, this.icone, this.couleur);

  final String libelle;
  final IconData icone;
  final Color couleur;
}

typedef _Constat = ({_Ton ton, String titre, String detail});

/// Section 5 : lecture des chiffres, ce qu'un graphique ne dit pas de lui-même.
///
/// Chaque constat porte un titre court, une phrase, et le ton qui dit s'il
/// appelle une décision. Les constats sont rangés du plus urgent au simple
/// relevé : c'est l'ordre dans lequel on agit, pas celui dans lequel les
/// chiffres sont calculés.
class _Analyse extends StatelessWidget {
  const _Analyse({required this.donnees});

  final ConcentrationGroupes donnees;

  /// Groupe dont le risque est le plus concentré sur un seul membre, parmi
  /// ceux qui portent réellement une exposition.
  ConcentrationGroupe? get _plusConcentre {
    final candidats =
        donnees.groupes.where((groupe) => groupe.expositionTotale > 0).toList();
    if (candidats.isEmpty) return null;
    candidats.sort((a, b) => b.herfindahl.compareTo(a.herfindahl));
    return candidats.first;
  }

  List<_Constat> _constats() {
    final constats = <_Constat>[];
    final groupes = donnees.groupes;
    if (groupes.isEmpty) return constats;

    final seuil = (donnees.seuilGrandRisque * 100).toStringAsFixed(0);
    final depassements =
        groupes.where((groupe) => groupe.depasseLeSeuil).toList();
    if (depassements.isNotEmpty) {
      constats.add((
        ton: _Ton.alerte,
        titre: depassements.length == 1
            ? 'Un groupe dépasse le seuil du grand risque'
            : '${depassements.length} groupes dépassent le seuil du grand '
                'risque',
        detail: '${depassements.map((groupe) => groupe.nom).join(", ")}. '
            'Au-delà de $seuil % des fonds propres, ils doivent être déclarés '
            'à l\'EP29 et surveillés.',
      ));
    } else {
      constats.add((
        ton: _Ton.favorable,
        titre: 'Aucun dépassement du seuil du grand risque',
        detail: 'Aucun groupe n\'atteint $seuil % des fonds propres de base.',
      ));
    }

    final concentre = _plusConcentre;
    if (concentre != null) {
      final porteurs = _membresPorteurs(concentre);
      if (porteurs.length <= 1) {
        constats.add((
          ton: _Ton.vigilance,
          titre: '« ${concentre.nom} » ne compte qu\'un membre exposé',
          detail: 'Le regrouper n\'ajoute rien tant qu\'aucune autre '
              'contrepartie ne lui est rattachée.',
        ));
      } else {
        final part =
            (concentre.partDuPlusGrosMembre * 100).toStringAsFixed(0);
        final concentration = concentre.herfindahl >= 0.5;
        constats.add((
          ton: concentration ? _Ton.vigilance : _Ton.fait,
          titre: 'Le risque le plus concentré est « ${concentre.nom} »',
          detail: '$part % de son exposition tient à un seul membre — '
              'Herfindahl ${concentre.herfindahl.toStringAsFixed(2)}, '
              '${_lectureHerfindahl(concentre.herfindahl)}. La défaillance de '
              'ce membre entraînerait l\'essentiel du groupe.',
        ));
      }
    }

    final totalGroupes = groupes.fold<double>(
      0,
      (somme, groupe) => somme + groupe.expositionTotale,
    );

    if (donnees.expositionPortefeuille > 0) {
      final part = totalGroupes / donnees.expositionPortefeuille;
      final partielle = part < 0.1;
      constats.add((
        ton: partielle ? _Ton.vigilance : _Ton.fait,
        titre: 'Les groupes couvrent '
            '${(part * 100).toStringAsFixed(1)} % du portefeuille',
        detail: partielle
            ? 'Le reste est traité contrepartie par contrepartie, ce qui '
                'sous-estime les concentrations réelles.'
            : 'Le reste est traité contrepartie par contrepartie.',
      ));
    }

    final plusLourd = groupes.first;
    if (plusLourd.expositionTotale > 0) {
      constats.add((
        ton: _Ton.fait,
        titre: 'Le groupe le plus exposé est « ${plusLourd.nom} »',
        detail: '${AppFormatters.millions(plusLourd.expositionTotale)} FCFA, '
            'soit ${(plusLourd.partFondsPropres * 100).toStringAsFixed(2)} % '
            'des fonds propres de base, pour un plafond de $seuil %.',
      ));
    }

    // Ce que pèse la tête de classement de chaque groupe dans l'ensemble des
    // groupes : c'est la mesure du risque réellement concentré.
    final totalDesTops = groupes.fold<double>(
      0,
      (somme, groupe) =>
          somme +
          _topDuGroupe(groupe).fold<double>(
            0,
            (sousTotal, membre) => sousTotal + membre.exposition,
          ),
    );
    if (totalGroupes > 0) {
      constats.add((
        ton: _Ton.fait,
        titre: 'Les $_tailleDuTop premiers membres de chaque groupe portent '
            '${(totalDesTops / totalGroupes * 100).toStringAsFixed(0)} % de '
            'l\'exposition groupée',
        detail: 'La queue de distribution pèse le reste : c\'est sur ces '
            'têtes de classement que se joue la concentration.',
      ));
    }

    return constats;
  }

  @override
  Widget build(BuildContext context) {
    final constats = _constats();
    if (constats.isEmpty) {
      return Text(
        'Aucun groupe constitué : rien à analyser.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _bordure),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < constats.length; i++) ...[
            if (i > 0) Container(height: 1, color: _bordure),
            _LigneConstat(constat: constats[i]),
          ],
        ],
      ),
    );
  }
}

/// Un constat : son ton à gauche, son titre, sa phrase.
class _LigneConstat extends StatelessWidget {
  const _LigneConstat({required this.constat});

  final _Constat constat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Le filet coloré porte le ton sans peindre toute la ligne : cinq
          // constats sur fond teinté crieraient tous à la fois.
          Container(width: 3, color: constat.ton.couleur),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      constat.ton.icone,
                      size: 18,
                      color: constat.ton.couleur,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                constat.titre,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: tableauTexteFort,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: constat.ton.couleur
                                    .withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                constat.ton.libelle,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: constat.ton.couleur,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          constat.detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            height: 1.4,
                            color: texteSecondaireLimites,
                          ),
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
}
