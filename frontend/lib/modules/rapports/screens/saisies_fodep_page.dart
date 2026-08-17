import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/rwa_api_service.dart';
import '../models/report_models.dart';

/// Saisie de ce que l'application ne produira jamais.
///
/// Aujourd'hui, c'est l'attestation seule : l'identité de l'établissement, les
/// deux responsables, et les signataires qui engagent leur nom. Aucune donnée
/// du portefeuille ne peut les déduire.
///
/// Les états prudentiels n'y figurent pas, et c'est délibéré. Ceux que
/// l'application n'alimente pas encore ont leur source ailleurs dans l'outil —
/// coefficients bêta, produit brut par ligne de métier, incidents de pertes —
/// et demandent d'être câblés, pas saisis. Les offrir ici laisserait croire à
/// un travail de saisie qui n'en est pas un.
///
/// Ce qui est saisi prime sur le zéro automatique de l'export ; ce qui est
/// laissé vide y retombe.
class SaisiesFodepPage extends StatefulWidget {
  const SaisiesFodepPage({super.key, required this.api, this.dateArrete});

  final RwaApiService api;

  /// La date d'arrêté que l'export portera sur l'attestation.
  ///
  /// Elle n'est pas saisie ici : elle vient de la date de fin choisie pour le
  /// reporting, et l'écran la montre pour que le déclarant reconnaisse celle
  /// qui sera déclarée. Nulle si l'export doit la déduire du portefeuille.
  final DateTime? dateArrete;

  static Future<bool> ouvrir(
    BuildContext context,
    RwaApiService api, {
    DateTime? dateArrete,
  }) async {
    final modifie = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SaisiesFodepPage(api: api, dateArrete: dateArrete),
      ),
    );
    return modifie ?? false;
  }

  @override
  State<SaisiesFodepPage> createState() => _SaisiesFodepPageState();
}

class _SaisiesFodepPageState extends State<SaisiesFodepPage> {
  late Future<SaisiesFodep> _future;

  /// Saisies modifiées et pas encore enregistrées, par adresse de case.
  final Map<String, CaseFodep> _enAttente = {};

  bool _enregistrement = false;
  bool _modifieDepuisOuverture = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchSaisiesFodep();
  }

  String _cle(CaseFodep case_) => '${case_.etat}!${case_.cellule}';

  void _modifier(CaseFodep case_, String saisie) {
    if (case_.estTexte) {
      final texte = saisie.trim();
      setState(() {
        _enAttente[_cle(case_)] = case_.copyWith(
          texte: texte,
          effacer: texte.isEmpty,
        );
      });
      return;
    }
    final nombre = saisie.trim().replaceAll(' ', '').replaceAll(',', '.');
    final valeur = nombre.isEmpty ? null : double.tryParse(nombre);
    // Une frappe invalide n'efface rien : tant qu'elle n'est pas un nombre,
    // la case garde ce qu'elle portait.
    if (nombre.isNotEmpty && valeur == null) return;
    setState(() {
      _enAttente[_cle(case_)] = case_.copyWith(
        valeur: valeur,
        effacer: valeur == null,
      );
    });
  }

  Future<void> _enregistrer() async {
    if (_enAttente.isEmpty) return;
    setState(() => _enregistrement = true);
    try {
      final nombre =
          await widget.api.enregistrerSaisiesFodep(_enAttente.values.toList());
      if (!mounted) return;
      _enAttente.clear();
      _modifieDepuisOuverture = true;
      setState(() {
        _enregistrement = false;
        _future = widget.api.fetchSaisiesFodep();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nombre case(s) enregistrée(s).')),
      );
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement impossible : $erreur')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: _enAttente.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmerAbandon();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Retour',
            onPressed: () => _quitter(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cases à renseigner du FODEP'),
              Text(
                'Ce que l\'application ne produira jamais : l\'identité de '
                'l\'établissement et les signataires de l\'attestation.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            if (_enAttente.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: FilledButton.icon(
                  onPressed: _enregistrement ? null : _enregistrer,
                  icon: _enregistrement
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text('Enregistrer (${_enAttente.length})'),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<SaisiesFodep>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Chargement impossible : ${snapshot.error}'),
              );
            }
            final saisies = snapshot.data!;
            if (saisies.etats.isEmpty) {
              return const Center(
                child: Text(
                  'Rien à saisir : tout ce que le formulaire exige vient de '
                  'l\'application.',
                ),
              );
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
                  children: [
                    _Avancement(saisies: saisies, enAttente: _enAttente.length),
                    const SizedBox(height: 20),
                    for (final etat in saisies.etats)
                      _BlocEtat(
                        etat: etat,
                        enAttente: _enAttente,
                        onModifier: _modifier,
                        dateArrete: widget.dateArrete,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _quitter() async {
    if (_enAttente.isEmpty) {
      Navigator.of(context).pop(_modifieDepuisOuverture);
      return;
    }
    await _confirmerAbandon();
  }

  Future<void> _confirmerAbandon() async {
    final abandonner = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Quitter sans enregistrer ?'),
        content: Text(
          '${_enAttente.length} case(s) modifiée(s) ne sont pas enregistrées. '
          'Elles seront perdues, et les cases concernées repartiront à zéro '
          'au prochain export.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexte, false),
            child: const Text('Continuer la saisie'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexte, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (abandonner == true && mounted) {
      Navigator.of(context).pop(_modifieDepuisOuverture);
    }
  }
}

/// Où en est la saisie, tous états confondus.
class _Avancement extends StatelessWidget {
  const _Avancement({required this.saisies, required this.enAttente});

  final SaisiesFodep saisies;
  final int enAttente;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final part = saisies.totalCases > 0
        ? saisies.totalRenseignees / saisies.totalCases
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${saisies.totalRenseignees} champ(s) renseigné(s) sur '
                  '${saisies.totalCases}.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (enAttente > 0)
                Text(
                  '$enAttente en attente d\'enregistrement',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: part,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tout le reste du formulaire est produit par l\'application. Les '
            'états qu\'elle n\'alimente pas encore sont déclarés à zéro, ce que '
            'la notice admet d\'une activité inexistante.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// L'attestation, dans son cadre, ouverte d'emblée.
///
/// Un seul bloc, et c'est voulu : les états prudentiels ne figurent plus ici,
/// leurs données venant de l'application.
class _BlocEtat extends StatelessWidget {
  const _BlocEtat({
    required this.etat,
    required this.enAttente,
    required this.onModifier,
    this.dateArrete,
  });

  final EtatASaisir etat;
  final Map<String, CaseFodep> enAttente;
  final void Function(CaseFodep, String) onModifier;
  final DateTime? dateArrete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    etat.etat,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${etat.renseignees} / ${etat.cases.length} champ(s) '
                    'renseigné(s) · rien de ceci ne vient de l\'outil',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          _Attestation(
            etat: etat,
            enAttente: enAttente,
            onModifier: onModifier,
            dateArrete: dateArrete,
          ),
        ],
      ),
    );
  }
}

class _ChampCase extends StatefulWidget {
  const _ChampCase({
    required this.case_,
    required this.modifiee,
    required this.onModifier,
    this.largeur = 208,
    this.etiquetteVisible = true,
  });

  final CaseFodep case_;
  final bool modifiee;
  final ValueChanged<String> onModifier;
  final double largeur;

  /// Dans l'attestation, le libellé est déjà posé à gauche de la case : le
  /// répéter dans le champ ferait doublon.
  final bool etiquetteVisible;

  @override
  State<_ChampCase> createState() => _ChampCaseState();
}

class _ChampCaseState extends State<_ChampCase> {
  late final TextEditingController _controleur;

  @override
  void initState() {
    super.initState();
    _controleur = TextEditingController(text: _contenuInitial());
  }

  String _contenuInitial() {
    if (widget.case_.estTexte) return widget.case_.texte ?? '';
    final valeur = widget.case_.valeur;
    return valeur == null ? '' : _sansZeroInutile(valeur);
  }

  static String _sansZeroInutile(double valeur) {
    return valeur == valeur.roundToDouble()
        ? valeur.toStringAsFixed(0)
        : valeur.toString();
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  /// Le clavier que la case appelle. Un numéro de téléphone, une adresse
  /// électronique et un montant ne se tapent pas avec les mêmes touches.
  TextInputType get _clavier {
    switch (widget.case_.typeSaisie) {
      case 'nombre':
        return const TextInputType.numberWithOptions(decimal: true);
      case 'telephone':
        return TextInputType.phone;
      case 'email':
        return TextInputType.emailAddress;
      case 'date':
        return TextInputType.datetime;
      default:
        return TextInputType.text;
    }
  }

  /// Ce que la case laisse passer.
  ///
  /// Un nom d'établissement n'est filtré par rien. Le filtre numérique qui
  /// s'appliquait ici à toutes les cases rendait l'attestation insaisissable :
  /// les lettres étaient refusées à la frappe, alors que pas une case de
  /// l'attestation n'attend un montant. Seules celles dont le libellé annonce
  /// une forme stricte gardent un filtre.
  List<TextInputFormatter> get _filtres {
    switch (widget.case_.typeSaisie) {
      case 'nombre':
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-,. ]'))];
      case 'telephone':
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-. ]'))];
      case 'email':
        // Une adresse ne porte pas d'espace ; le reste lui est permis.
        return [FilteringTextInputFormatter.deny(RegExp(r'\s'))];
      // Une date ne se tape plus : elle se choisit au calendrier, et la case
      // n'accepte aucune frappe. Aucun filtre n'a donc à la surveiller.
      case 'date':
        return const [];
      default:
        return const [];
    }
  }

  /// Le gabarit attendu, montré dans la case tant qu'elle est vide.
  String? get _indice {
    switch (widget.case_.typeSaisie) {
      case 'email':
        return 'nom@etablissement.com';
      case 'telephone':
        return '+000 00 00 00 00';
      case 'date':
        // La case vide dit ce qu'elle attend de l'utilisateur — un clic, pas
        // une frappe. Le gabarit AAAA-MM-JJ, lui, est déjà écrit à côté par
        // le formulaire, et il n'a plus à être respecté à la main.
        return 'Cliquer pour choisir';
      default:
        return null;
    }
  }

  bool get _estUneDate => widget.case_.typeSaisie == 'date';

  /// Ce qui manque à la saisie pour être du type annoncé.
  ///
  /// Le contrôle est signalé, jamais bloquant : une case mal formée reste
  /// saisie et enregistrée. Le déclarant qui part chercher l'orthographe
  /// exacte d'une adresse ne doit pas perdre le reste de son formulaire.
  String? get _erreur {
    final saisie = _controleur.text.trim();
    if (saisie.isEmpty) return null;
    switch (widget.case_.typeSaisie) {
      case 'email':
        final valide =
            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(saisie);
        return valide ? null : 'Adresse électronique incomplète';
      // Le calendrier ne rend jamais une date fausse. Le contrôle ne sert donc
      // qu'aux dates déjà enregistrées du temps où la case se tapait : elles
      // doivent se signaler, pas passer inaperçues jusqu'à la déclaration.
      case 'date':
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(saisie)) {
          return 'Date mal formée : choisissez-la au calendrier';
        }
        return DateTime.tryParse(saisie) == null ? 'Date inexistante' : null;
      default:
        return null;
    }
  }

  /// Ouvre le calendrier et porte la date choisie dans la case.
  ///
  /// Une date de signature se choisit, elle ne se tape pas. Le gabarit
  /// AAAA-MM-JJ n'est pas celui dans lequel on pense une date : le respecter à
  /// la main est une contrainte inutile, et c'est en le tapant qu'on se
  /// trompe. Le calendrier ne peut rendre qu'une date qui existe, au format
  /// que le formulaire attend.
  Future<void> _choisirLaDate() async {
    final portee = DateTime.tryParse(_controleur.text.trim());
    final choisie = await showDatePicker(
      context: context,
      initialDate: portee ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Date de signature',
    );
    if (choisie == null) return;
    final texte = '${choisie.year.toString().padLeft(4, '0')}-'
        '${choisie.month.toString().padLeft(2, '0')}-'
        '${choisie.day.toString().padLeft(2, '0')}';
    _controleur.text = texte;
    widget.onModifier(texte);
    setState(() {});
  }

  /// Vide la case.
  ///
  /// Une case qu'on ne peut plus taper ne peut plus se corriger au clavier :
  /// sans ce bouton, une date choisie par erreur ne s'en irait jamais.
  void _effacerLaDate() {
    _controleur.clear();
    widget.onModifier('');
    setState(() {});
  }

  /// Le calendrier, et de quoi revenir en arrière.
  Widget? get _actionsDate {
    if (!_estUneDate) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_controleur.text.trim().isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 15),
            tooltip: 'Effacer la date',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _effacerLaDate,
          ),
        IconButton(
          icon: const Icon(Icons.event_outlined, size: 17),
          tooltip: 'Choisir la date',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: _choisirLaDate,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Hors attestation la case est désignée par son en-tête de colonne ; dans
    // l'attestation, qui n'en a pas, par son libellé.
    final etiquette = widget.case_.colonne.isNotEmpty
        ? widget.case_.colonne
        : (widget.case_.libelle.isNotEmpty
            ? widget.case_.libelle
            : widget.case_.cellule);
    final erreur = _erreur;

    return SizedBox(
      width: widget.largeur,
      child: Tooltip(
        message: _estUneDate
            ? '${widget.case_.libelle}\n'
                'Cliquez pour ouvrir le calendrier · '
                'cellule ${widget.case_.cellule}'
            : '${widget.case_.libelle}\n'
                '${widget.case_.etat} · cellule ${widget.case_.cellule}',
        child: TextField(
          controller: _controleur,
          keyboardType: _clavier,
          inputFormatters: _filtres,
          textCapitalization: widget.case_.typeSaisie == 'texte'
              ? TextCapitalization.words
              : TextCapitalization.none,
          // La case de date ne se tape pas : toute la case est le bouton qui
          // ouvre le calendrier. Viser une petite icône pour saisir une date
          // serait revenir à demander de l'adresse ce qu'on voulait éviter.
          readOnly: _estUneDate,
          showCursor: !_estUneDate,
          mouseCursor:
              _estUneDate ? SystemMouseCursors.click : SystemMouseCursors.text,
          onTap: _estUneDate ? _choisirLaDate : null,
          style: theme.textTheme.bodySmall,
          decoration: InputDecoration(
            isDense: true,
            labelText: widget.etiquetteVisible ? etiquette : null,
            labelStyle: theme.textTheme.labelSmall,
            hintText: _indice,
            hintStyle: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            helperText: widget.etiquetteVisible ? widget.case_.cellule : null,
            helperStyle: theme.textTheme.labelSmall,
            suffixIcon: _actionsDate,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 34, minHeight: 34),
            errorText: erreur,
            errorStyle: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.error),
            border: const OutlineInputBorder(),
            enabledBorder: widget.modifiee && erreur == null
                ? OutlineInputBorder(
                    borderSide:
                        BorderSide(color: theme.colorScheme.tertiary, width: 2),
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          onChanged: (frappe) {
            widget.onModifier(frappe);
            // Le contrôle de forme suit la frappe : il n'a de valeur que s'il
            // se voit pendant qu'on tape.
            setState(() {});
          },
        ),
      ),
    );
  }
}

/// L'attestation, présentée comme le formulaire la présente.
///
/// Une liste de champs étiquetés aurait suffi à saisir les mêmes valeurs, mais
/// personne n'y aurait reconnu l'ADPE. Ici chaque bloc est à sa place, le CIB
/// garde ses cinq cases, et le texte de la certification est celui que les
/// signataires endossent — c'est ce qu'ils signent, ils doivent le lire.
class _Attestation extends StatelessWidget {
  const _Attestation({
    required this.etat,
    required this.enAttente,
    required this.onModifier,
    this.dateArrete,
  });

  final EtatASaisir etat;
  final Map<String, CaseFodep> enAttente;
  final void Function(CaseFodep, String) onModifier;
  final DateTime? dateArrete;

  static const String _certification =
      'certifions que le présent formulaire a été rempli conformément aux '
      'exigences du dispositif prudentiel applicable aux établissements de '
      'crédit et aux compagnies financières de l\'Union Monétaire Ouest '
      'Africaine.';
  static const String _exhaustivite =
      'En outre, nous attestons qu\'au meilleur de notre connaissance, les '
      'données contenues dans le présent formulaire sont fiables, intègres et '
      'exhaustives.';

  CaseFodep? _case(String cellule) {
    for (final case_ in etat.cases) {
      if (case_.cellule == cellule) {
        return enAttente['ADPE!$cellule'] ?? case_;
      }
    }
    return null;
  }

  bool _modifiee(String cellule) => enAttente.containsKey('ADPE!$cellule');

  Widget _champ(String cellule, {double largeur = 260}) {
    final case_ = _case(cellule);
    if (case_ == null) return SizedBox(width: largeur);
    return _ChampCase(
      case_: case_,
      modifiee: _modifiee(cellule),
      largeur: largeur,
      etiquetteVisible: false,
      onModifier: (texte) => onModifier(case_, texte),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'ATTESTATION DE DÉCLARATION PRUDENTIELLE',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              _LigneAttestation(
                libelle: 'ÉTAT :',
                champ: _champ('C5', largeur: 230),
              ),
              _LigneAttestation(
                libelle: 'ÉTABLISSEMENT :',
                champ: _champ('T5', largeur: 300),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _EnteteCodes(
            cib: _case('N7'),
            cibModifiee: _modifiee('N7'),
            lettreCle: _case('T7'),
            cleModifiee: _modifiee('T7'),
            onModifier: onModifier,
            dateArrete: dateArrete,
          ),
          const SizedBox(height: 22),
          _BlocResponsable(
            titre: 'Personne-responsable du renseignement du FODEP :',
            nom: _champ('N16', largeur: 300),
            fonction: _champ('N18', largeur: 300),
            telephone: _champ('N20', largeur: 190),
            poste: _champ('AB20', largeur: 110),
            courriel: _champ('N22', largeur: 300),
          ),
          const SizedBox(height: 18),
          _BlocResponsable(
            titre: 'Personne-responsable de la transmission du FODEP à la '
                'plateforme de reporting BCEAO',
            nom: _champ('N26', largeur: 300),
            fonction: _champ('N28', largeur: 300),
            telephone: _champ('N30', largeur: 190),
            poste: _champ('AB30', largeur: 110),
            courriel: _champ('N32', largeur: 300),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'CERTIFICATION',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text('Nous,', style: theme.textTheme.bodyMedium),
              _champ('C37', largeur: 250),
              Text('et', style: theme.textTheme.bodyMedium),
              _champ('T37', largeur: 250),
            ],
          ),
          const SizedBox(height: 12),
          Text(_certification, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(_exhaustivite, style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          _BlocSignataire(
            fonction: _champ('G45', largeur: 260),
            date: _champ('X45', largeur: 195),
          ),
          const SizedBox(height: 14),
          _BlocSignataire(
            fonction: _champ('G51', largeur: 260),
            date: _champ('X51', largeur: 195),
          ),
        ],
      ),
    );
  }
}

/// Un libellé du formulaire et sa case, côte à côte.
class _LigneAttestation extends StatelessWidget {
  const _LigneAttestation({
    required this.libelle,
    required this.champ,
    this.largeurLibelle,
  });

  final String libelle;
  final Widget champ;
  final double? largeurLibelle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texte = Text(libelle, style: theme.textTheme.bodySmall);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        largeurLibelle == null
            ? texte
            : SizedBox(width: largeurLibelle, child: texte),
        const SizedBox(width: 10),
        champ,
      ],
    );
  }
}

/// La rangée de cases du haut : date d'arrêté, CIB, lettre clé.
///
/// La date n'est pas saisissable — l'application la porte elle-même, depuis la
/// date d'arrêté du reporting. Ses cases sont montrées grisées plutôt que
/// masquées : le déclarant doit voir qu'elles seront remplies, sans quoi il les
/// croirait oubliées.
///
/// Quand la date est connue, ce sont ses chiffres qui s'affichent, et non le
/// gabarit AAAA MM JJ. Un gabarit ressemble à une case vide, et une case vide
/// s'essaie : le déclarant tape dedans, rien ne vient, et il croit à une panne
/// là où l'écran voulait dire « déjà rempli ».
class _EnteteCodes extends StatelessWidget {
  const _EnteteCodes({
    required this.cib,
    required this.cibModifiee,
    required this.lettreCle,
    required this.cleModifiee,
    required this.onModifier,
    this.dateArrete,
  });

  final CaseFodep? cib;
  final bool cibModifiee;
  final CaseFodep? lettreCle;
  final bool cleModifiee;
  final void Function(CaseFodep, String) onModifier;
  final DateTime? dateArrete;

  /// Les huit caractères du gabarit : les chiffres de la date si elle est
  /// connue, les lettres du modèle sinon.
  List<String> get _caracteres {
    final date = dateArrete;
    if (date == null) return const ['A', 'A', 'A', 'A', 'M', 'M', 'J', 'J'];
    final chiffres = '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    return chiffres.split('');
  }

  @override
  Widget build(BuildContext context) {
    final caracteres = _caracteres;
    final connue = dateArrete != null;

    return Wrap(
      spacing: 30,
      runSpacing: 14,
      children: [
        _GroupeDeCases(
          legende: 'Date d\'arrêté',
          precision: connue
              ? 'portée par l\'application · se change avec la date de fin du '
                  'reporting'
              : 'portée par l\'application, d\'après la date de fin du '
                  'reporting',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < caracteres.length; index++) ...[
                if (index == 4 || index == 6) const SizedBox(width: 6),
                _CaseFigee(lettre: caracteres[index], renseignee: connue),
              ],
            ],
          ),
        ),
        if (cib != null)
          _GroupeDeCases(
            legende: 'C I B',
            precision: 'code identifiant bancaire',
            child: _CasesCaracteres(
              case_: cib!,
              nombre: 5,
              modifiee: cibModifiee,
              onModifier: onModifier,
            ),
          ),
        if (lettreCle != null)
          _GroupeDeCases(
            legende: 'LC',
            precision: 'lettre clé',
            child: _CasesCaracteres(
              case_: lettreCle!,
              nombre: 1,
              modifiee: cleModifiee,
              onModifier: onModifier,
            ),
          ),
      ],
    );
  }
}

class _GroupeDeCases extends StatelessWidget {
  const _GroupeDeCases({
    required this.legende,
    required this.precision,
    required this.child,
  });

  final String legende;
  final String precision;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        const SizedBox(height: 4),
        Text(
          legende,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        Text(precision, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// Une case du gabarit de date, remplie par l'application.
///
/// Elle reste grisée dans les deux cas — rien ne s'y tape — mais un chiffre
/// déjà porté s'affiche en pleine encre : c'est une valeur acquise, pas un
/// gabarit en attente.
class _CaseFigee extends StatelessWidget {
  const _CaseFigee({required this.lettre, this.renseignee = false});

  final String lettre;
  final bool renseignee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: renseignee
          ? 'Date d\'arrêté portée par l\'application. Pour la changer, '
              'modifiez la date de fin sur l\'écran Reporting global.'
          : 'Cette case n\'est pas à saisir : l\'application y portera la '
              'date d\'arrêté du reporting.',
      child: Container(
        width: 24,
        height: 32,
        margin: const EdgeInsets.only(right: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          lettre,
          style: renseignee
              ? theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
        ),
      ),
    );
  }
}

/// Une valeur saisie caractère par caractère, comme le formulaire la présente.
class _CasesCaracteres extends StatefulWidget {
  const _CasesCaracteres({
    required this.case_,
    required this.nombre,
    required this.modifiee,
    required this.onModifier,
  });

  final CaseFodep case_;
  final int nombre;
  final bool modifiee;
  final void Function(CaseFodep, String) onModifier;

  @override
  State<_CasesCaracteres> createState() => _CasesCaracteresState();
}

class _CasesCaracteresState extends State<_CasesCaracteres> {
  late final List<TextEditingController> _controleurs;
  late final List<FocusNode> _focus;

  @override
  void initState() {
    super.initState();
    final valeur = widget.case_.texte ?? '';
    _controleurs = List.generate(
      widget.nombre,
      (index) => TextEditingController(
        text: index < valeur.length ? valeur[index] : '',
      ),
    );
    _focus = List.generate(widget.nombre, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controleur in _controleurs) {
      controleur.dispose();
    }
    for (final noeud in _focus) {
      noeud.dispose();
    }
    super.dispose();
  }

  /// Un code d'identification se lit en capitales sur le formulaire, et ne
  /// porte ni ponctuation ni espace : une case, un caractère.
  static final List<TextInputFormatter> _formatage = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    TextInputFormatter.withFunction(
      (avant, apres) => TextEditingValue(
        text: apres.text.toUpperCase(),
        selection: apres.selection,
      ),
    ),
  ];

  void _saisir(int index, String frappe) {
    // La frappe avance d'elle-même : taper un code de cinq caractères ne doit
    // pas demander cinq clics. Effacer recule de même, sans quoi le déclarant
    // qui corrige devrait cliquer case par case.
    if (frappe.isNotEmpty && index < widget.nombre - 1) {
      _focus[index + 1].requestFocus();
    } else if (frappe.isEmpty && index > 0) {
      _focus[index - 1].requestFocus();
    }
    widget.onModifier(
      widget.case_,
      _controleurs.map((controleur) => controleur.text).join(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bordure = widget.modifiee
        ? theme.colorScheme.tertiary
        : theme.colorScheme.outline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < widget.nombre; index++)
          Container(
            width: 30,
            height: 34,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              border: Border.all(
                color: bordure,
                width: widget.modifiee ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: TextField(
              controller: _controleurs[index],
              focusNode: _focus[index],
              textAlign: TextAlign.center,
              maxLength: 1,
              inputFormatters: _formatage,
              textCapitalization: TextCapitalization.characters,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (frappe) => _saisir(index, frappe),
            ),
          ),
      ],
    );
  }
}

/// Un des deux blocs « personne-responsable ».
class _BlocResponsable extends StatelessWidget {
  const _BlocResponsable({
    required this.titre,
    required this.nom,
    required this.fonction,
    required this.telephone,
    required this.poste,
    required this.courriel,
  });

  final String titre;
  final Widget nom;
  final Widget fonction;
  final Widget telephone;
  final Widget poste;
  final Widget courriel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const largeurLibelle = 128.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _LigneAttestation(
          libelle: 'Prénoms et Nom :',
          largeurLibelle: largeurLibelle,
          champ: nom,
        ),
        const SizedBox(height: 8),
        _LigneAttestation(
          libelle: 'Fonction :',
          largeurLibelle: largeurLibelle,
          champ: fonction,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _LigneAttestation(
              libelle: 'Téléphone :',
              largeurLibelle: largeurLibelle,
              champ: telephone,
            ),
            _LigneAttestation(libelle: 'Poste :', champ: poste),
          ],
        ),
        const SizedBox(height: 8),
        _LigneAttestation(
          libelle: 'E-mail :',
          largeurLibelle: largeurLibelle,
          champ: courriel,
        ),
      ],
    );
  }
}

/// Un bloc de signature.
///
/// « Code Signature » n'a pas de case : le formulaire n'en ouvre aucune en
/// face, cette ligne attend une signature et non une valeur à taper. Le dire
/// vaut mieux que de laisser croire à un champ oublié.
class _BlocSignataire extends StatelessWidget {
  const _BlocSignataire({required this.fonction, required this.date});

  final Widget fonction;
  final Widget date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Code Signature :',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(
            'Le formulaire n\'ouvre aucune case ici : il y attend une signature.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LigneAttestation(
                libelle: 'Fonction :',
                largeurLibelle: 80,
                champ: fonction,
              ),
              _LigneAttestation(libelle: 'Date :', champ: date),
              Text('(AAAA-MM-JJ)', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
