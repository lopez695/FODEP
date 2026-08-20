import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart' show ApiException;
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/file_save.dart';
import '../../reporting_global/services/fodep_pdf.dart';
import '../../reporting_global/widgets/choix_format_fodep_dialog.dart';
import '../models/report_models.dart';
import 'analyse_declaration_page.dart';
import 'saisies_fodep_page.dart';

/// La déclaration prudentielle, en un seul endroit.
///
/// Renseigner les cases que l'application ne calcule pas et exporter le
/// formulaire sont deux moments de la même tâche : le second se fait après le
/// premier, sans quoi les états concernés partent à zéro. Les deux boutons
/// vivaient pourtant à deux coins opposés de l'écran de reporting, dont le
/// sujet est le rapport consolidé, pas le FODEP.
class FodepPage extends StatefulWidget {
  const FodepPage({super.key, required this.api, this.dateArrete});

  final RwaApiService api;

  /// Date d'arrêté que l'attestation portera. Elle vient de la date de fin
  /// choisie pour le reporting ; nulle, l'export la déduit du portefeuille.
  final DateTime? dateArrete;

  /// Retourne `true` si des cases ont été renseignées, pour que l'appelant
  /// rafraîchisse son aperçu.
  static Future<bool> ouvrir(
    BuildContext context,
    RwaApiService api, {
    DateTime? dateArrete,
  }) async {
    final modifie = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FodepPage(api: api, dateArrete: dateArrete),
      ),
    );
    return modifie ?? false;
  }

  @override
  State<FodepPage> createState() => _FodepPageState();
}

class _FodepPageState extends State<FodepPage> {
  late Future<SaisiesFodep> _saisies;

  /// Date d'arrêté retenue pour la déclaration.
  ///
  /// Initialisée avec la date de fin du reporting, elle se choisit sur
  /// l'écran des cases à renseigner : c'est l'attestation qui la porte.
  DateTime? _dateArrete;
  bool _exportEnCours = false;
  bool _analyseEnCours = false;
  bool _saisiesModifiees = false;

  @override
  void initState() {
    super.initState();
    _saisies = widget.api.fetchSaisiesFodep();
    _dateArrete = widget.dateArrete;
  }

  String? get _dateArreteLisible {
    final date = _dateArrete;
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _ouvrirLesSaisies() async {
    final retour = await SaisiesFodepPage.ouvrir(
      context,
      widget.api,
      dateArrete: _dateArrete,
    );
    if (!mounted) return;
    setState(() {
      // La date d'arrêté se choisit sur l'écran de saisie, parce que c'est
      // l'attestation qui la porte. L'export doit repartir de celle-là, sans
      // quoi la déclaration contredirait l'attestation qu'on vient de régler.
      _dateArrete = retour.dateArrete;
      if (retour.modifie) {
        _saisiesModifiees = true;
        _saisies = widget.api.fetchSaisiesFodep();
      }
    });
  }

  Future<void> _exporter() async {
    // Le format se demande avant de produire quoi que ce soit : les deux
    // sorties partent du même classeur, mais l'une est la pièce déclarative et
    // l'autre sa lecture.
    final format = await ChoixFormatFodepDialog.demander(
      context,
      dateArrete: _dateArreteLisible,
    );
    if (format == null || !mounted) return;

    setState(() => _exportEnCours = true);
    try {
      final enPdf = format == FormatExportFodep.pdf;

      // Un seul aller-retour dans les deux cas, et la même source : le PDF est
      // rendu depuis le contenu que le backend extrait du classeur qu'il vient
      // d'écrire, jamais d'un second calcul.
      final Uint8List octets;
      final String nomPropose;
      final List<ReserveFodep> reserves;
      if (enPdf) {
        final contenu =
            await widget.api.fetchContenuFodep(dateArrete: _dateArrete);
        if (!mounted) return;
        octets = await construireFodepPdf(contenu: contenu);
        nomPropose = contenu.nomFichier.replaceFirst(RegExp(r'\.xlsx$'), '.pdf');
        reserves = contenu.anomalies;
      } else {
        final export =
            await widget.api.downloadFodep(dateArrete: _dateArrete);
        if (!mounted) return;
        octets = export.bytes;
        nomPropose = export.fileName;
        reserves = export.anomalies;
      }
      final extension = enPdf ? '.pdf' : '.xlsx';
      if (!mounted) return;

      final emplacement = await getSaveLocation(
        suggestedName: nomPropose,
        acceptedTypeGroups: [
          enPdf
              ? const XTypeGroup(label: 'Document PDF', extensions: ['pdf'])
              : const XTypeGroup(label: 'Classeur Excel', extensions: ['xlsx']),
        ],
      );
      if (!mounted || emplacement == null) return;

      final enregistre = await saveBytesAtLocation(
        emplacement,
        octets,
        requiredExtension: extension,
        suggestedName: nomPropose,
      );
      if (!mounted) return;

      // La boîte n'interrompt que s'il reste un geste à faire. Sinon les
      // remarques restent consultables d'un clic : ce sont des constats et des
      // conventions de report, qui doivent pouvoir être lus — celui qui signe
      // les endosse — sans arrêter quelqu'un qui n'a rien à corriger.
      final aFaire =
          reserves.any((reserve) => reserve.nature == NatureReserve.aVerifier);

      _annoncer(
        'Enregistré : ${enregistre.path.split(RegExp(r'[\\/]')).last}',
        action: reserves.isEmpty || aFaire
            ? null
            : (
                libelle: 'Voir les remarques',
                surAppui: () => _afficherLesReserves(reserves),
              ),
      );

      // Personne ne relit une page de garde avant d'avoir enregistré le
      // fichier : la boîte vient après, et seulement si elle a de quoi.
      if (aFaire) await _afficherLesReserves(reserves);
    } on FichierVerrouilleException catch (erreur) {
      _signaler(erreur.message);
    } on ApiException catch (erreur) {
      // Le backend embarqué est démarré une fois pour toutes au lancement de
      // l'application, sans rechargement automatique : tant qu'elle n'a pas été
      // relancée, il sert le code d'avant la mise à jour et ignore les routes
      // du FODEP. Un « Not Found » brut laisserait chercher longtemps.
      _signaler(
        erreur.statusCode == 404
            ? 'Export FODEP indisponible sur le serveur en cours d\'exécution. '
                'Fermez puis relancez l\'application pour redémarrer son '
                'backend.'
            : 'Erreur : ${erreur.message}',
      );
    } catch (erreur) {
      _signaler('Erreur : $erreur');
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  /// Dépose un PDF de déclaration et l'analyse.
  ///
  /// Le fichier n'a pas à venir de cet outil : une déclaration d'un exercice
  /// précédent ou d'une autre entité s'analyse aussi bien. Ce sont les onze
  /// normes de l'EP01 qui sont confrontées à leurs seuils.
  Future<void> _analyser() async {
    // Les deux formats de la déclaration : le classeur transmis à la BCEAO, et
    // son impression. Le classeur est la lecture exacte — ses niveaux sont des
    // nombres, aux cases que le formulaire leur réserve.
    final fichier = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Déclaration FODEP',
          extensions: ['xlsx', 'pdf'],
        ),
      ],
    );
    if (fichier == null || !mounted) return;

    setState(() => _analyseEnCours = true);
    try {
      final octets = await fichier.readAsBytes();
      if (!mounted) return;
      final analyse = await widget.api.analyserDeclarationFodep(
        octets,
        fichier.name,
      );
      if (!mounted) return;
      await AnalyseDeclarationPage.ouvrir(context, analyse);
    } on ApiException catch (erreur) {
      _signaler(
        erreur.statusCode == 404
            ? 'Analyse indisponible sur le serveur en cours d\'exécution. '
                'Fermez puis relancez l\'application pour redémarrer son '
                'backend.'
            : 'Analyse impossible : ${erreur.message}',
      );
    } catch (erreur) {
      _signaler('Analyse impossible : $erreur');
    } finally {
      if (mounted) setState(() => _analyseEnCours = false);
    }
  }

  void _annoncer(
    String message, {
    ({String libelle, VoidCallback surAppui})? action,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // Une remarque à lire demande plus de quatre secondes pour être vue.
        duration: Duration(seconds: action == null ? 4 : 10),
        action: action == null
            ? null
            : SnackBarAction(
                label: action.libelle,
                onPressed: action.surAppui,
              ),
      ),
    );
  }

  /// Affiche une erreur assez longtemps pour être lue et agie.
  void _signaler(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppTheme.danger,
      duration: const Duration(seconds: 8),
      content: Text(message),
    ));
  }

  /// Ce qu'il reste à faire, puis ce qu'il faut savoir.
  ///
  /// La boîte affichait ses remarques d'affilée sous une seule consigne —
  /// « complétez-les à la main avant de déposer la déclaration ». Or on ne
  /// complète pas à la main une convention de report, ni un poste que
  /// l'établissement ne détient pas : la consigne était fausse pour la plupart
  /// des lignes, et les deux ou trois qui appelaient vraiment un geste s'y
  /// noyaient. Chaque réserve porte donc sa nature, et l'écran la range.
  Future<void> _afficherLesReserves(List<ReserveFodep> reserves) async {
    final theme = Theme.of(context);
    List<ReserveFodep> deNature(NatureReserve nature) =>
        [for (final reserve in reserves) if (reserve.nature == nature) reserve];

    final aVerifier = deNature(NatureReserve.aVerifier);
    final conventions = deNature(NatureReserve.convention);
    final informations = deNature(NatureReserve.information);

    await showDialog<void>(
      context: context,
      builder: (contexte) => AlertDialog(
        // Le titre confirme d'abord : la boîte s'ouvre sur un export qui vient
        // de réussir, et accueillir par « À faire avant de transmettre »
        // laissait croire à un échec. Ce qui reste à faire est porté par
        // l'intertitre rouge, qui s'ouvre déjà et compte ses points.
        title: const Text('Bien enregistré'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  aVerifier.isEmpty
                      ? "Rien n'appelle de correction. Les remarques ci-dessous "
                          "disent comment l'application a rempli le "
                          'formulaire : celui qui signe les endosse.'
                      : 'Ce qui suit demande un geste avant de déposer la '
                          "déclaration ; le reste dit comment l'application a rempli le "
                          'formulaire.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
                if (aVerifier.isNotEmpty)
                  _SectionReserves(
                    titre: 'À compléter ou à vérifier',
                    reserves: aVerifier,
                    ouverte: true,
                    couleur: AppTheme.danger,
                  ),
                if (conventions.isNotEmpty)
                  _SectionReserves(
                    titre: "Conventions retenues par l'application",
                    reserves: conventions,
                  ),
                if (informations.isNotEmpty)
                  _SectionReserves(
                    titre: 'Pour information',
                    reserves: informations,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(),
            child: const Text("J'ai lu"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _dateArreteLisible;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 128,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_saisiesModifiees),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Retour'),
          ),
        ),
        title: Text(
          'Déclaration prudentielle (FODEP)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 48),
            children: [
              Text(
                date == null
                    ? 'La date d\'arrêté sera déduite de la date d\'analyse la '
                        'plus récente du portefeuille.'
                    : 'Arrêté au $date, comme la date de fin choisie pour le '
                        'reporting.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 20),
              // L'ordre est celui de la tâche : on renseigne, puis on exporte.
              // L'inverse produit une déclaration dont les états non calculés
              // partent à zéro.
              FutureBuilder<SaisiesFodep>(
                future: _saisies,
                builder: (context, instantane) => _Etape(
                  numero: 1,
                  titre: 'Cases à renseigner',
                  detail: 'Les états que l\'application ne calcule pas partent '
                      'à zéro tant que personne ne les a renseignés. Ce qui est '
                      'saisi prime sur ce zéro ; ce qui reste vide y retombe.',
                  mention: _mentionDesSaisies(instantane.data),
                  action: OutlinedButton(
                    onPressed: _ouvrirLesSaisies,
                    style: _styleContour(theme),
                    child: const Text('Ouvrir les cases'),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Entre les deux étapes, parce que ce choix décide de ce que
              // l'export déclare : il n'est pas une action de plus, c'est un
              // réglage de la déclaration.
              _ChoixMethodeOperationnelle(api: widget.api),
              const SizedBox(height: 14),
              _Etape(
                numero: 2,
                titre: 'Exporter le FODEP',
                detail: 'Le classeur est la pièce à transmettre à la BCEAO. Le '
                    'PDF en est l\'impression, pour relecture, visa et '
                    'archivage. Le format se choisit à l\'export.',
                action: FilledButton.icon(
                  onPressed: _exportEnCours ? null : _exporter,
                  icon: _exportEnCours
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  label: Text(
                    _exportEnCours ? 'Préparation…' : 'Exporter',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Troisième étape, distincte des deux autres : elle ne produit
              // pas la déclaration, elle en relit une. Le PDF déposé n'a pas à
              // venir de cet outil.
              _Etape(
                numero: 3,
                titre: 'Analyser une déclaration',
                detail: 'Déposez une déclaration — la vôtre, celle d\'un '
                    'exercice précédent, celle d\'une autre entité. L\'outil '
                    'confronte les onze normes de l\'EP01 à leurs seuils, et dit '
                    'lesquelles sont respectées, dépassées ou non mesurées.',
                mention: 'Classeur .xlsx ou impression .pdf. Le classeur donne '
                    'la lecture exacte ; un PDF scanné, lui, n\'a pas de couche '
                    'de texte et ne peut pas être lu.',
                action: OutlinedButton.icon(
                  onPressed: _analyseEnCours ? null : _analyser,
                  icon: _analyseEnCours
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(
                    _analyseEnCours ? 'Analyse…' : 'Importer une déclaration',
                  ),
                  style: _styleContour(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _mentionDesSaisies(SaisiesFodep? saisies) {
    if (saisies == null) return null;
    if (saisies.totalCases == 0) return 'Aucune case à renseigner.';
    return '${saisies.totalRenseignees} case(s) renseignée(s) '
        'sur ${saisies.totalCases}.';
  }

  ButtonStyle _styleContour(ThemeData theme) => OutlinedButton.styleFrom(
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
      );
}

/// Une étape de la déclaration : ce qu'elle fait, où elle en est, son action.
/// La méthode de calcul du risque opérationnel retenue par l'établissement.
///
/// Le formulaire porte les deux approches — indicateur de base en EP21 et
/// EP22, standard en EP23 et EP24 — mais un établissement en applique une
/// seule : l'autre reste à zéro, et l'EP08 porte l'exigence sur la ligne
/// correspondante. Le choix vivait jusqu'ici en base sans qu'aucun écran ne
/// permette de le poser, et l'export ne le consultait pas : la déclaration
/// partait toujours en indicateur de base.
///
/// Ce n'est pas une préférence : l'approche standard s'utilise sur accord de
/// la Commission bancaire, et le dire ici engage le déclarant.
class _ChoixMethodeOperationnelle extends StatefulWidget {
  const _ChoixMethodeOperationnelle({required this.api});

  final RwaApiService api;

  @override
  State<_ChoixMethodeOperationnelle> createState() =>
      _ChoixMethodeOperationnelleState();
}

class _ChoixMethodeOperationnelleState
    extends State<_ChoixMethodeOperationnelle> {
  bool? _standard;
  bool _enregistrement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final parametres = await widget.api.fetchAsParametres();
      if (!mounted) return;
      setState(() => _standard = parametres.asAutorisee);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreur = 'Méthode illisible : $erreur');
    }
  }

  Future<void> _choisir(bool standard) async {
    if (_enregistrement || standard == _standard) return;
    final precedent = _standard;
    setState(() {
      _standard = standard;
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await widget.api.updateAsParametres({'as_autorisee': standard});
    } catch (erreur) {
      if (!mounted) return;
      // Le choix n'a pas été retenu : l'écran doit le montrer plutôt que
      // laisser croire à un réglage enregistré.
      setState(() {
        _standard = precedent;
        _erreur = 'Le choix n\'a pas été enregistré : $erreur';
      });
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Méthode du risque opérationnel',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'L\'établissement en applique une seule. Elle décide de l\'état '
            'renseigné et de la ligne de l\'EP08 qui porte l\'exigence ; '
            'l\'autre est déclarée à zéro.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (_standard == null && _erreur == null)
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _OptionMethode(
                  titre: 'Indicateur de base',
                  etats: 'EP21 · EP22',
                  choisie: _standard == false,
                  onChoisir: () => _choisir(false),
                ),
                _OptionMethode(
                  titre: 'Standard',
                  etats: 'EP23 · EP24',
                  precision: 'sur accord de la Commission bancaire',
                  choisie: _standard == true,
                  onChoisir: () => _choisir(true),
                ),
              ],
            ),
          if (_erreur != null) ...[
            const SizedBox(height: 10),
            Text(
              _erreur!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// Une des deux méthodes, avec les états qu'elle renseigne.
class _OptionMethode extends StatelessWidget {
  const _OptionMethode({
    required this.titre,
    required this.etats,
    required this.choisie,
    required this.onChoisir,
    this.precision,
  });

  final String titre;
  final String etats;
  final String? precision;
  final bool choisie;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return InkWell(
      onTap: onChoisir,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 244,
        padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
        decoration: BoxDecoration(
          border: Border.all(
            color: choisie ? accent : theme.dividerColor,
            width: choisie ? 2 : 1,
          ),
          color: choisie ? accent.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              choisie
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: choisie ? accent : theme.colorScheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: choisie ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    etats,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if (precision != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        precision!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
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

class _Etape extends StatelessWidget {
  const _Etape({
    required this.numero,
    required this.titre,
    required this.detail,
    required this.action,
    this.mention,
  });

  final int numero;
  final String titre;
  final String detail;

  /// Où en est l'étape, quand elle a un état à annoncer.
  final String? mention;

  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (mention != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    mention!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          action,
        ],
      ),
    );
  }
}

/// Un groupe de réserves, sous son intitulé.
///
/// Ce qui appelle un geste s'ouvre ; les conventions et les constats se
/// replient. Ils doivent rester consultables — celui qui signe les endosse —
/// sans encombrer la seule chose à faire avant de déposer la déclaration.
class _SectionReserves extends StatefulWidget {
  const _SectionReserves({
    required this.titre,
    required this.reserves,
    this.ouverte = false,
    this.couleur,
  });

  final String titre;
  final List<ReserveFodep> reserves;
  final bool ouverte;
  final Color? couleur;

  @override
  State<_SectionReserves> createState() => _SectionReservesState();
}

class _SectionReservesState extends State<_SectionReserves> {
  late bool _ouverte = widget.ouverte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = widget.couleur ?? theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _ouverte = !_ouverte),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _ouverte ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: couleur,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${widget.titre} (${widget.reserves.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: couleur,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_ouverte)
            for (final reserve in widget.reserves)
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(
                      child: Text(
                        reserve.message,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
