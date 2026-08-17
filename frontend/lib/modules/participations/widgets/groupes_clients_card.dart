import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/participation_models.dart';
import 'concentration_groupes_page.dart';
import 'groupes_clients_page.dart';
import 'tableau_maison.dart';

/// Nombre de groupes montrés dans la carte avant de renvoyer au détail.
///
/// Cinq lignes suffisent à donner le ton du portefeuille. Au-delà, la carte
/// devient une liste que personne ne lit en entier, et qui repousse les
/// blocs suivants hors de l'écran.
const int _groupesAffiches = 5;

/// Groupes de clients liés, dans l'onglet Portefeuille.
///
/// Sans groupe constitué, la division des risques traite chaque contrepartie
/// comme un groupe à elle seule : les concentrations sont sous-estimées, et
/// l'état EP30 du FODEP reste vide faute de clients à détailler.
class GroupesClientsCard extends StatefulWidget {
  const GroupesClientsCard({
    super.key,
    required this.api,
    this.limiteAffichage = _groupesAffiches,
    this.afficherEntete = true,
  });

  final RwaApiService api;

  /// Nombre de groupes montrés avant de renvoyer à la page complète.
  /// `null` les affiche tous : c'est ce que fait la page de gestion.
  final int? limiteAffichage;

  /// La page de gestion porte déjà ce titre dans sa barre : le répéter dans
  /// la carte ferait doublon.
  final bool afficherEntete;

  @override
  State<GroupesClientsCard> createState() => _GroupesClientsCardState();
}

class _GroupesClientsCardState extends State<GroupesClientsCard> {
  late Future<List<GroupeClients>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchGroupesClients();
  }

  void _recharger() {
    // Corps entre accolades, et non flèche : une flèche renverrait la valeur
    // de l'affectation, donc un Future, que setState refuse.
    setState(() {
      _future = widget.api.fetchGroupesClients();
    });
  }

  Future<void> _creerGroupe() async {
    final nom = await showDialog<String>(
      context: context,
      builder: (_) => const _FormulaireGroupe(),
    );
    if (nom == null || nom.trim().isEmpty) return;
    try {
      await widget.api.createGroupeClients(nom: nom.trim());
      _recharger();
    } catch (erreur) {
      _signaler('Création impossible : $erreur');
    }
  }

  Future<void> _supprimerGroupe(GroupeClients groupe) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text('Supprimer « ${groupe.nom} » ?'),
        content: const Text(
          'Les contreparties du groupe sont détachées, pas supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexte, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexte, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await widget.api.deleteGroupeClients(groupe.id);
      _recharger();
    } catch (erreur) {
      _signaler('Suppression impossible : $erreur');
    }
  }

  Future<void> _rattacher(GroupeClients groupe, {MembreGroupe? membre}) async {
    final modifie = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogueRattachement(
        api: widget.api,
        groupe: groupe,
        membre: membre,
      ),
    );
    if (modifie == true) _recharger();
  }

  Future<void> _renommer(GroupeClients groupe) async {
    final saisie = await showDialog<({String nom, String numero})>(
      context: context,
      builder: (_) => _FormulaireEditionGroupe(groupe: groupe),
    );
    if (saisie == null || saisie.nom.isEmpty) return;
    try {
      await widget.api.updateGroupeClients(
        id: groupe.id,
        nom: saisie.nom,
        numeroCentraleRisques: saisie.numero,
      );
      _recharger();
    } catch (erreur) {
      _signaler('Modification impossible : $erreur');
    }
  }

  void _signaler(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.afficherEntete) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Groupes de clients liés',
                            style: theme.textTheme.titleMedium),
                        Text('État EP30 et division des risques',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  // Ouvre un écran de lecture, quand sa voisine crée un groupe :
                  // contour contre plein.
                  BoutonSecondaire(
                    libelle: 'Analyse',
                    onPressed: () =>
                        ConcentrationGroupesPage.ouvrir(context, widget.api),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _creerGroupe,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouveau groupe'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.tonalIcon(
                    onPressed: _creerGroupe,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouveau groupe'),
                  ),
                ),
              ),
            FutureBuilder<List<GroupeClients>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Text('Chargement impossible : ${snapshot.error}',
                      style: theme.textTheme.bodySmall);
                }
                final groupes = snapshot.data ?? const [];
                if (groupes.isEmpty) {
                  return Text(
                    'Aucun groupe constitué. Chaque contrepartie est donc '
                    'traitée comme un groupe à elle seule, ce qui sous-estime '
                    'les concentrations, et l\'EP30 reste vide.',
                    style: theme.textTheme.bodySmall,
                  );
                }
                // La carte donne un aperçu, pas l'inventaire : au-delà de cinq
                // groupes, la liste pousse tout le reste de l'onglet vers le
                // bas sans rien apprendre de plus. Le détail complet, avec les
                // poids et l'analyse, vit dans la page Concentration.
                final limite = widget.limiteAffichage;
                final visibles =
                    limite == null ? groupes : groupes.take(limite).toList();

                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _bordure),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _EnteteTableau(),
                      Container(height: 0.5, color: _bordure),
                      for (var i = 0; i < visibles.length; i++)
                        _LigneGroupe(
                          rang: i + 1,
                          groupe: visibles[i],
                          onRattacher: () => _rattacher(visibles[i]),
                          onSupprimer: () => _supprimerGroupe(visibles[i]),
                          onRenommer: () => _renommer(visibles[i]),
                          onModifierMembre: (membre) =>
                              _rattacher(visibles[i], membre: membre),
                        ),
                      if (visibles.length < groupes.length)
                        _PiedDuTableau(
                          affiches: visibles.length,
                          total: groupes.length,
                          onDetail: () async {
                            await GroupesClientsPage.ouvrir(
                              context,
                              widget.api,
                            );
                            // La page permet de créer, renommer et détacher :
                            // au retour, la carte doit relire la liste.
                            if (mounted) _recharger();
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Couleurs du tableau des expositions NPL du même écran. Les deux tableaux
// se lisent côte à côte dans l'onglet Portefeuille : leur donner deux allures
// obligerait le lecteur à réapprendre la grille à chaque bloc.
const Color _entete = Color(0xFF001F4E);
const Color _bordure = Color(0xFFDCE4F2);
const Color _ligneAlternee = Color(0xFFF8FAFC);
const Color _texteFort = Color(0xFF1E293B);

/// Largeur des deux colonnes fixes : le rang et les actions.
const double _largeurRang = 32;
const double _largeurActions = 96;

/// Contenu d'une cellule, avec le retrait propre à la colonne du rang.
Widget _contenuCellule({required Widget enfant, required bool colonneRang}) {
  return Container(
    padding: colonneRang
        ? const EdgeInsets.only(left: 12, top: 9, bottom: 9)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    alignment: Alignment.centerLeft,
    child: enfant,
  );
}

/// Une cellule et son filet, à poser directement dans la ligne.
///
/// La fonction rend une liste plutôt qu'un widget : un `Expanded` doit être
/// l'enfant direct de la `Row` qui le mesure. L'envelopper dans une `Row`
/// intermédiaire lui donnerait une largeur infinie à répartir, ce que Flutter
/// refuse — la mise en page échouait au premier rendu.
List<Widget> _cellule({
  required Widget enfant,
  int? flex,
  double? largeur,
}) {
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

/// En-tête du tableau des groupes.
class _EnteteTableau extends StatelessWidget {
  const _EnteteTableau();

  List<Widget> _colonne(
    BuildContext context,
    String libelle, {
    int? flex,
    double? largeur,
  }) {
    return _cellule(
      flex: flex,
      largeur: largeur,
      enfant: Text(
        libelle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _entete,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._colonne(context, 'N°', largeur: _largeurRang),
            ..._colonne(context, 'Groupe', flex: 4),
            ..._colonne(context, 'Membres', flex: 2),
            ..._colonne(context, 'N° Centrale des risques', flex: 3),
            ..._colonne(context, 'Identification', flex: 3),
            ..._colonne(context, '', largeur: _largeurActions),
          ],
        ),
      ),
    );
  }
}

/// Une ligne du tableau : le groupe, et ses membres quand elle est dépliée.
///
/// Le dépliage tient dans l'état de la ligne plutôt que dans un `ExpansionTile`
/// : celui-ci range son ouverture dans le `PageStorage` de la page, où l'écran
/// Portefeuille garde aussi des positions de défilement. La collision faisait
/// relire un `double` là où un `bool?` était attendu, et l'écran plantait au
/// premier rendu.
class _LigneGroupe extends StatefulWidget {
  const _LigneGroupe({
    required this.rang,
    required this.groupe,
    required this.onRattacher,
    required this.onSupprimer,
    required this.onRenommer,
    required this.onModifierMembre,
  });

  final int rang;
  final GroupeClients groupe;
  final VoidCallback onRattacher;
  final VoidCallback onSupprimer;
  final VoidCallback onRenommer;
  final ValueChanged<MembreGroupe> onModifierMembre;

  @override
  State<_LigneGroupe> createState() => _LigneGroupeState();
}

class _LigneGroupeState extends State<_LigneGroupe> {
  bool _ouvert = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupe = widget.groupe;
    final incomplets =
        groupe.membres.where((m) => !m.identificationComplete).length;
    final sansNumero = (groupe.numeroCentraleRisques ?? '').isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: widget.rang.isEven ? _ligneAlternee : Colors.white,
          child: InkWell(
            onTap: () => setState(() => _ouvert = !_ouvert),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._cellule(
                    largeur: _largeurRang,
                    enfant: Text(
                      '${widget.rang}'.padLeft(2, '0'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ..._cellule(
                    flex: 4,
                    enfant: Text(
                      groupe.nom,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _texteFort,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ..._cellule(
                    flex: 2,
                    enfant: Text(
                      '${groupe.membres.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _entete,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ..._cellule(
                    flex: 3,
                    enfant: Text(
                      sansNumero
                          ? 'Non renseigné'
                          : groupe.numeroCentraleRisques!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            sansNumero ? theme.colorScheme.error : _texteFort,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ..._cellule(
                    flex: 3,
                    enfant: Text(
                      incomplets == 0
                          ? 'Complète'
                          : '$incomplets membre(s) incomplet(s)',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: incomplets == 0
                            ? _texteFort
                            : theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ..._cellule(
                    largeur: _largeurActions,
                    enfant: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Renommer le groupe, corriger son '
                              'n° Centrale des risques',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: widget.onRenommer,
                        ),
                        Icon(
                          _ouvert ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: AppTheme.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(height: 0.5, color: _bordure),
        if (_ouvert)
          _MembresDuGroupe(
            groupe: groupe,
            onRattacher: widget.onRattacher,
            onSupprimer: widget.onSupprimer,
            onModifierMembre: widget.onModifierMembre,
          ),
      ],
    );
  }
}

/// Les membres du groupe, sous la ligne qui les porte.
class _MembresDuGroupe extends StatelessWidget {
  const _MembresDuGroupe({
    required this.groupe,
    required this.onRattacher,
    required this.onSupprimer,
    required this.onModifierMembre,
  });

  final GroupeClients groupe;
  final VoidCallback onRattacher;
  final VoidCallback onSupprimer;
  final ValueChanged<MembreGroupe> onModifierMembre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: _ligneAlternee,
      padding: const EdgeInsets.fromLTRB(44, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (groupe.membres.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aucune contrepartie rattachée : le groupe ne pèse rien tant '
                'qu\'il reste vide.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final membre in groupe.membres)
            InkWell(
              // Toute identification saisie doit rester corrigeable : c'est
              // précisément celle qui manque que l'export signale.
              onTap: () => onModifierMembre(membre),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      membre.identificationComplete
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 16,
                      color: membre.identificationComplete
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Text(
                        membre.nom,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _texteFort,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        [
                          membre.categorieLien?.label ?? 'Lien non qualifié',
                          membre.numeroCentraleRisques ??
                              'Sans n° Centrale des risques',
                          if ((membre.secteurActivite ?? '').isNotEmpty)
                            membre.secteurActivite!,
                          if (membre.categoriePartieLiee != null)
                            membre.categoriePartieLiee!.label,
                        ].join(' · '),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 11.5),
                      ),
                    ),
                    Tooltip(
                      message: 'Corriger l\'identification de ce membre',
                      child: Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _bordure),
          const SizedBox(height: 10),
          _BarreActionsGroupe(
            nombreMembres: groupe.membres.length,
            onRattacher: onRattacher,
            onSupprimer: onSupprimer,
          ),
        ],
      ),
    );
  }
}

class _FormulaireGroupe extends StatefulWidget {
  const _FormulaireGroupe();

  @override
  State<_FormulaireGroupe> createState() => _FormulaireGroupeState();
}

class _FormulaireGroupeState extends State<_FormulaireGroupe> {
  final _controleur = TextEditingController();

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        'Nouveau groupe de clients liés',
        style: theme.textTheme.titleMedium?.copyWith(
          color: _entete,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nom du groupe',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _texteFort,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controleur,
              autofocus: true,
              decoration: _decorationSimple(context),
              onSubmitted: (valeur) => Navigator.pop(context, valeur),
            ),
            const SizedBox(height: 6),
            Text(
              'Le numéro Centrale des risques du groupe se renseigne ensuite, '
              'depuis le crayon de sa ligne.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.outline,
            minimumSize: const Size(0, 38),
            textStyle:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _controleur.text),
          icon: const Icon(Icons.add, size: 17),
          label: const Text('Créer le groupe'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            minimumSize: const Size(0, 38),
            textStyle:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Décoration commune des champs de saisie : un cadre net, la même hauteur
/// partout, et le focus marqué par la couleur primaire.
InputDecoration _decorationSimple(BuildContext context, {Widget? suffixe}) {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
      borderSide: BorderSide(color: _bordure),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
    ),
    suffixIcon: suffixe,
  );
}

/// Rattachement d'une contrepartie à un groupe, ou correction de son
/// identification.
///
/// La même boîte sert aux deux : en création elle propose les contreparties
/// encore libres, en modification elle ouvre directement sur celle qu'on
/// corrige et offre de la détacher.
class _DialogueRattachement extends StatefulWidget {
  const _DialogueRattachement({
    required this.api,
    required this.groupe,
    this.membre,
  });

  final RwaApiService api;
  final GroupeClients groupe;
  final MembreGroupe? membre;

  @override
  State<_DialogueRattachement> createState() => _DialogueRattachementState();
}

class _DialogueRattachementState extends State<_DialogueRattachement> {
  late Future<List<ContrepartieRattachement>> _future;
  ContrepartieRattachement? _choisie;
  late CategorieLien _lien;
  CategoriePartieLiee? _partieLiee;
  final _numero = TextEditingController();
  final _secteur = TextEditingController();
  bool _envoi = false;

  bool get _modification => widget.membre != null;

  @override
  void initState() {
    super.initState();
    final membre = widget.membre;
    _lien = membre?.categorieLien ?? CategorieLien.controleDeDroit;
    _partieLiee = membre?.categoriePartieLiee;
    _numero.text = membre?.numeroCentraleRisques ?? '';
    _secteur.text = membre?.secteurActivite ?? '';
    // Un numéro déjà saisi n'est jamais écrasé : la suggestion ne sert qu'à
    // épargner une frappe là où le champ est vide.
    if (_numero.text.isEmpty) _numero.text = _suggestion();
    // En modification, la contrepartie est connue : inutile d'aller chercher
    // celles qui restent libres.
    _future = _modification
        ? Future.value(const <ContrepartieRattachement>[])
        : widget.api.fetchContrepartiesRattachement(sansGroupe: true);
  }

  @override
  void dispose() {
    _numero.dispose();
    _secteur.dispose();
    super.dispose();
  }

  String? get _identifiantCible => widget.membre?.id ?? _choisie?.id;

  /// Prochain numéro de la série du groupe, en ignorant celui du membre
  /// en cours de modification pour ne pas se suggérer son propre numéro.
  String _suggestion() => suggererNumeroCentraleRisques([
        for (final autre in widget.groupe.membres)
          if (autre.id != widget.membre?.id) autre.numeroCentraleRisques,
        widget.groupe.numeroCentraleRisques,
      ]);

  Future<void> _enregistrer({bool detacher = false}) async {
    final identifiant = _identifiantCible;
    if (identifiant == null) return;
    setState(() => _envoi = true);
    try {
      await widget.api.rattacherContrepartie(
        contrepartieId: identifiant,
        groupeId: detacher ? null : widget.groupe.id,
        categorieLien: detacher ? null : _lien,
        numeroCentraleRisques:
            _numero.text.trim().isEmpty ? null : _numero.text.trim(),
        secteurActivite:
            _secteur.text.trim().isEmpty ? null : _secteur.text.trim(),
        categoriePartieLiee: _partieLiee,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _envoi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement impossible : $erreur')),
      );
    }
  }

  /// Un champ, son intitulé au-dessus et sa précision en dessous.
  ///
  /// L'intitulé est posé hors du cadre plutôt qu'en étiquette flottante : il
  /// reste lisible quand le champ est rempli, et tous les champs s'alignent à
  /// la même hauteur quelle que soit la longueur de leur aide.
  Widget _champ({
    required String intitule,
    required Widget enfant,
    String? aide,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intitule,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _texteFort,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 6),
          enfant,
          if (aide != null) ...[
            const SizedBox(height: 5),
            Text(
              aide,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _titreDeBloc(String libelle) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        libelle.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 10.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _enTete(theme),
            const Divider(height: 1, color: _bordure),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                child: FutureBuilder<List<ContrepartieRattachement>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final libres = snapshot.data ?? const [];
                    if (!_modification && libres.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Toutes les contreparties sont déjà rattachées à un '
                          'groupe. Détachez-en une avant d\'en rattacher une '
                          'autre ici.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }
                    return _formulaire(theme, libres);
                  },
                ),
              ),
            ),
            const Divider(height: 1, color: _bordure),
            _piedDePage(theme),
          ],
        ),
      ),
    );
  }

  Widget _enTete(ThemeData theme) {
    final nom =
        _modification ? widget.membre!.nom : 'Rattacher une contrepartie';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _modification
                  ? Icons.account_balance_outlined
                  : Icons.group_add_outlined,
              size: 19,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nom,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _entete,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Groupe « ${widget.groupe.nom} » · état EP30',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Fermer',
            onPressed: _envoi ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _formulaire(ThemeData theme, List<ContrepartieRattachement> libres) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _titreDeBloc('Identification'),
        if (!_modification)
          _champ(
            intitule: 'Contrepartie',
            enfant: DropdownButtonFormField<ContrepartieRattachement>(
              initialValue: _choisie,
              isExpanded: true,
              decoration: _decorationSimple(context),
              hint: const Text('Choisissez une contrepartie'),
              items: [
                for (final contrepartie in libres)
                  DropdownMenuItem(
                    value: contrepartie,
                    child:
                        Text(contrepartie.nom, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (valeur) => setState(() => _choisie = valeur),
            ),
          ),
        _champ(
          intitule: 'Catégorie de lien',
          aide: 'Ce qui fait tomber ces contreparties ensemble',
          enfant: DropdownButtonFormField<CategorieLien>(
            initialValue: _lien,
            isExpanded: true,
            decoration: _decorationSimple(context),
            items: [
              for (final lien in CategorieLien.values)
                DropdownMenuItem(value: lien, child: Text(lien.label)),
            ],
            onChanged: (valeur) => setState(() => _lien = valeur ?? _lien),
          ),
        ),
        _champ(
          intitule: 'N° Centrale des risques',
          aide: 'Exigé par l\'EP30 · le numéro proposé prolonge la série du '
              'groupe, vérifiez-le',
          enfant: TextField(
            controller: _numero,
            onChanged: (_) => setState(() {}),
            decoration: _decorationSimple(
              context,
              suffixe: IconButton(
                icon: const Icon(Icons.auto_fix_high_outlined, size: 19),
                tooltip: 'Proposer le numéro suivant du groupe',
                onPressed: () {
                  final propose = _suggestion();
                  if (propose.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Aucun numéro dans ce groupe : rien à prolonger. '
                          'Saisissez le premier.',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _numero.text = propose);
                },
              ),
            ),
          ),
        ),
        _champ(
          intitule: 'Secteur d\'activités',
          aide: 'Choisissez dans la liste ou saisissez',
          // Saisie assistée plutôt que contrainte : la liste couvre les
          // branches usuelles, un secteur absent se tape en clair.
          enfant: Autocomplete<String>(
            initialValue: TextEditingValue(text: _secteur.text),
            optionsBuilder: (saisie) {
              final filtre = saisie.text.trim().toLowerCase();
              if (filtre.isEmpty) return secteursActivite;
              return secteursActivite.where(
                (secteur) => secteur.toLowerCase().contains(filtre),
              );
            },
            onSelected: (secteur) => _secteur.text = secteur,
            fieldViewBuilder: (context, controleur, focus, onFieldSubmitted) {
              // Le champ interne d'Autocomplete porte la saisie : on la
              // recopie pour que l'enregistrement la retrouve.
              controleur.addListener(() => _secteur.text = controleur.text);
              return TextField(
                controller: controleur,
                focusNode: focus,
                decoration: _decorationSimple(
                  context,
                  suffixe: const Icon(Icons.arrow_drop_down),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        _titreDeBloc('Partie liée'),
        // Une contrepartie peut aussi être une partie liée : actionnaire,
        // dirigeant ou membre du personnel. Ce classement alimente les états
        // EP38 et EP39, et la limite RA011 de l'état de conformité.
        _champ(
          intitule: 'Qualité de partie liée (facultatif)',
          aide: 'Alimente les états EP38 et EP39, et la limite RA011',
          enfant: DropdownButtonFormField<CategoriePartieLiee?>(
            initialValue: _partieLiee,
            isExpanded: true,
            decoration: _decorationSimple(context),
            items: [
              const DropdownMenuItem<CategoriePartieLiee?>(
                value: null,
                child: Text('Non — contrepartie ordinaire'),
              ),
              for (final categorie in CategoriePartieLiee.values)
                DropdownMenuItem<CategoriePartieLiee?>(
                  value: categorie,
                  child: Text(categorie.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (valeur) => setState(() => _partieLiee = valeur),
          ),
        ),
        if (_numero.text.trim().isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sans numéro Centrale des risques, ce membre sera signalé '
                    'comme incomplet et l\'EP30 le déclarera sans identifiant.',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _piedDePage(ThemeData theme) {
    const forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
    );

    return Container(
      color: _ligneAlternee,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        children: [
          if (_modification)
            OutlinedButton.icon(
              onPressed: _envoi ? null : () => _enregistrer(detacher: true),
              icon: const Icon(Icons.link_off, size: 17),
              label: const Text('Détacher du groupe'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.45),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                minimumSize: const Size(0, 38),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                shape: forme,
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: _envoi ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.outline,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size(0, 38),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              shape: forme,
            ),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _envoi || _identifiantCible == null
                ? null
                : () => _enregistrer(),
            icon: _envoi
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 17),
            label: Text(_modification ? 'Enregistrer' : 'Rattacher'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              minimumSize: const Size(0, 38),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              shape: forme,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renommage d'un groupe et correction de son numéro Centrale des risques.
class _FormulaireEditionGroupe extends StatefulWidget {
  const _FormulaireEditionGroupe({required this.groupe});

  final GroupeClients groupe;

  @override
  State<_FormulaireEditionGroupe> createState() =>
      _FormulaireEditionGroupeState();
}

class _FormulaireEditionGroupeState extends State<_FormulaireEditionGroupe> {
  late final TextEditingController _nom;
  late final TextEditingController _numero;

  @override
  void initState() {
    super.initState();
    _nom = TextEditingController(text: widget.groupe.nom);
    _numero = TextEditingController(
      text: widget.groupe.numeroCentraleRisques ?? '',
    );
  }

  @override
  void dispose() {
    _nom.dispose();
    _numero.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le groupe'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nom,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nom du groupe'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numero,
              decoration: const InputDecoration(
                labelText: 'N° Centrale des risques du groupe',
                helperText: 'Exigé par l\'EP30',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            nom: _nom.text.trim(),
            numero: _numero.text.trim(),
          )),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Barre d'actions d'un groupe déplié.
///
/// Les deux actions n'ont pas le même poids et ne doivent pas le paraître :
/// rattacher une contrepartie est le geste courant, supprimer le groupe est
/// irréversible pour son périmètre. La première est donc pleine, la seconde
/// contourée dans la teinte d'alerte.
class _BarreActionsGroupe extends StatelessWidget {
  const _BarreActionsGroupe({
    required this.nombreMembres,
    required this.onRattacher,
    required this.onSupprimer,
  });

  final int nombreMembres;
  final VoidCallback onRattacher;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            nombreMembres == 0
                ? 'Aucune contrepartie rattachée'
                : '$nombreMembres contrepartie(s) rattachée(s)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 11.5,
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: onRattacher,
          icon: const Icon(Icons.group_add_outlined, size: 17),
          label: const Text('Rattacher une contrepartie'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(0, 38),
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            shape: forme,
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onSupprimer,
          icon: const Icon(Icons.delete_outline, size: 17),
          label: const Text('Supprimer le groupe'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.45),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(0, 38),
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            shape: forme,
          ),
        ),
      ],
    );
  }
}

/// Pied du tableau, quand tous les groupes ne tiennent pas dans la carte.
class _PiedDuTableau extends StatelessWidget {
  const _PiedDuTableau({
    required this.affiches,
    required this.total,
    required this.onDetail,
  });

  final int affiches;
  final int total;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: _ligneAlternee,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$affiches groupe(s) affiché(s) sur $total · les poids et '
              'l\'analyse de tous les groupes sont dans le détail',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: onDetail,
            icon: const Icon(Icons.bar_chart_rounded, size: 17),
            label: Text('Voir les $total groupes'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(0, 36),
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
