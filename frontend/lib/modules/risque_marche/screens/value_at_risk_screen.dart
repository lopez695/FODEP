// Onglet VALUE AT RISK (VaR) alimenté par le backend.
//
// Les trois méthodes (historique, paramétrique, Monte-Carlo) sont calculées
// côté serveur via /api/var/* ; cet écran ne fait aucun calcul financier,
// il ne fait qu'afficher les données reçues (valeurs en Md FCFA, formatées
// en convention française à l'affichage).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import 'dart:io' show PathAccessException;

import 'package:file_selector/file_selector.dart';
import '../../../core/services/api_client.dart';
import '../../../shared/utils/file_save.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../core/utils/currency_conversion.dart';

const Color _varNavy = Color(0xFF0F1B3D);
const Color _varDeepBlue = Color(0xFF001F4E);
const Color _varPrimary = Color(0xFF2563EB);
const Color _varBarBlue = Color(0xFF9DC2F9);
const Color _varDanger = Color(0xFFEF4444);
const Color _varOrange = Color(0xFFF59E0B);
const Color _varMuted = Color(0xFF64748B);
const Color _varBorder = Color(0xFFDDE7F5);
const Color _varSurface = Color(0xFFFFFFFF);
const Color _varSurfaceSoft = Color(0xFFF8FAFC);

const double _parameterPanelWidth = 220;

final NumberFormat _formatMd = NumberFormat('#,##0.0', 'fr_FR');
final NumberFormat _formatAxe = NumberFormat('#,##0.#', 'fr_FR');
final NumberFormat _formatPct2 = NumberFormat('#,##0.00', 'fr_FR');
final NumberFormat _formatEntier = NumberFormat('#,##0', 'fr_FR');

/// Unité d'affichage adaptée à l'ordre de grandeur du portefeuille : au-delà
/// de 1 Md on lit en milliards, en dessous en millions, afin qu'un petit
/// portefeuille (actions de quelques centaines de millions) ne soit pas réduit
/// à « 0,0 Md ». La même unité est appliquée aux cartes KPI et à l'axe du
/// graphique pour rester cohérente.
PortfolioAmountUnit _uniteEchelleVar(double portefeuilleMd) =>
    portefeuilleMd.abs() >= 1.0
        ? PortfolioAmountUnit.billion
        : PortfolioAmountUnit.million;

(String, String) _mdFormat(num valeur, {PortfolioAmountUnit? unit}) {
  if (unit != null) {
    final scaled = (valeur * 1e9) / unit.divisor;
    return (_formatMd.format(scaled), unit.label);
  }
  if (valeur == 0) return ('0,0', 'Md');
  final absVal = valeur.abs();
  if (absVal < 0.001) {
    final format = NumberFormat('#,##0', 'fr_FR');
    return (format.format(valeur * 1000000), 'k');
  } else if (absVal < 0.01) {
    final format = NumberFormat('#,##0.00', 'fr_FR');
    return (format.format(valeur * 1000), 'M');
  } else if (absVal < 0.1) {
    final format = NumberFormat('#,##0.0', 'fr_FR');
    return (format.format(valeur * 1000), 'M');
  }
  return (_formatMd.format(valeur), 'Md');
}

String _md(num valeur, {PortfolioAmountUnit? unit}) {
  final res = _mdFormat(valeur, unit: unit);
  return '${res.$1} ${res.$2}';
}

String _pourcentage(double fraction) =>
    '${_formatPct2.format(fraction * 100)} %';

// Paramétrique et Monte-Carlo en tête : elles fonctionnent dès qu'un
// portefeuille est importé (mode réglementaire), sans historique de prix.
// Historique en dernier - verrouillée tant qu'aucun historique réel n'est
// disponible (voir `sansCalculPossible` ci-dessous).
enum VarMethode { parametrique, monteCarlo, historique }

extension on VarMethode {
  String get segment => switch (this) {
        VarMethode.historique => 'historique',
        VarMethode.parametrique => 'parametrique',
        VarMethode.monteCarlo => 'montecarlo',
      };

  String get libelle => switch (this) {
        VarMethode.historique => 'VaR Historique',
        VarMethode.parametrique => 'VaR Paramétrique',
        VarMethode.monteCarlo => 'VaR Monte-Carlo',
      };

  /// Sans calcul possible aujourd'hui : aucune source disponible ne fournit
  /// la série de prix observés (250 séances minimum) que la méthode exige.
  ///
  /// L'onglet reste NAVIGABLE : il expose la méthodologie et un cas chiffré,
  /// au lieu d'un cadenas qui n'explique rien. Il ne déclenche simplement
  /// aucun appel de calcul.
  bool get sansCalculPossible => this == VarMethode.historique;
}

/// Classe d'histogramme reçue du backend.
class _ClasseHistogramme {
  const _ClasseHistogramme(this.borneInf, this.borneSup, this.effectif);

  final double borneInf;
  final double borneSup;
  final int effectif;
}

/// Réponse d'un endpoint /api/var/*, sans aucun recalcul côté client.
class _ReponseVar {
  const _ReponseVar({
    required this.methode,
    required this.sourceDonnees,
    required this.valeurPortefeuille,
    required this.varValeur,
    required this.expectedShortfall,
    required this.pirePerte,
    required this.p95,
    this.p975,
    required this.p99,
    required this.tauxDepassementPct,
    required this.nombreObservations,
    required this.histogramme,
    this.courbeNormale = const [],
    this.hypotheseNormaleDouteuse = false,
    this.nbSimulations,
    this.graine,
    this.icVarBasse,
    this.icVarHaute,
    this.durationModifiee,
    this.durationModifieePortefeuille,
  });

  final String methode;
  final String sourceDonnees;
  final double valeurPortefeuille;
  final double varValeur;
  final double expectedShortfall;
  final double pirePerte;
  final double p95;
  final double? p975;
  final double p99;
  final double tauxDepassementPct;
  final int nombreObservations;
  final List<_ClasseHistogramme> histogramme;
  final List<Offset> courbeNormale;
  final bool hypotheseNormaleDouteuse;
  final int? nbSimulations;
  final int? graine;
  final double? icVarBasse;
  final double? icVarHaute;
  final double? durationModifiee;

  /// Duration modifiée du portefeuille calculée par le backend (flux
  /// amortis, pondérée par le capital restant dû) : valeur de référence.
  final double? durationModifieePortefeuille;

  static double _d(dynamic valeur) => (valeur as num).toDouble();

  factory _ReponseVar.fromJson(Map<String, dynamic> json) {
    final classes = <_ClasseHistogramme>[
      for (final brut in (json['histogramme'] as List))
        _ClasseHistogramme(
          _d((brut as Map)['borne_inf']),
          _d(brut['borne_sup']),
          (brut['effectif'] as num).toInt(),
        ),
    ];
    final courbe = <Offset>[
      for (final point in (json['courbe_normale'] as List? ?? const []))
        Offset(_d((point as Map)['x']), _d(point['y'])),
    ];
    final ic = json['ic_var_95'] as Map?;
    return _ReponseVar(
      methode: json['methode'] as String,
      sourceDonnees: json['source_donnees'] as String,
      valeurPortefeuille: _d(json['valeur_portefeuille']),
      varValeur: _d(json['var']),
      expectedShortfall: _d(json['expected_shortfall']),
      pirePerte: _d(json['pire_perte']),
      p95: _d(json['p95']),
      p975: json['p975'] == null ? null : _d(json['p975']),
      p99: _d(json['p99']),
      tauxDepassementPct: _d(json['taux_depassement_pct']),
      nombreObservations: (json['nombre_observations'] as num).toInt(),
      histogramme: classes,
      courbeNormale: courbe,
      hypotheseNormaleDouteuse:
          json['hypothese_normale_douteuse'] as bool? ?? false,
      nbSimulations: (json['nb_simulations'] as num?)?.toInt(),
      graine: (json['graine'] as num?)?.toInt(),
      icVarBasse: ic == null ? null : _d(ic['borne_basse']),
      icVarHaute: ic == null ? null : _d(ic['borne_haute']),
      durationModifiee: json['parametres'] != null &&
              json['parametres']['duration_modifiee'] != null
          ? _d(json['parametres']['duration_modifiee'])
          : null,
      durationModifieePortefeuille:
          json['duration_modifiee_portefeuille'] == null
              ? null
              : _d(json['duration_modifiee_portefeuille']),
    );
  }
}

class ValueAtRiskScreen extends StatefulWidget {
  const ValueAtRiskScreen({super.key, required this.api});

  final RwaApiService api;
  static double? lastDashboardDurationModifiee;

  /// Capital restant dû du tableau de bord Sensibilité, en FCFA (pas en Md).
  static double? lastDashboardCrd;

  @override
  State<ValueAtRiskScreen> createState() => _ValueAtRiskScreenState();
}

class _ValueAtRiskScreenState extends State<ValueAtRiskScreen> {
  static const String _portefeuilleDefaut = 'obligations';
  static const double _confianceDefaut = 0.99;
  static const int _horizonDefaut = 1;
  static const int _fenetreDefaut = 500;
  static const double _volatiliteDefaut = 0.03;
  static const double _durationDefaut = 3.4;
  static const int _simulationsDefaut = 10000;
  static const double _betaDefaut = 1.0;

  static const String _paysCourbeDefaut = "Côte d'Ivoire";

  VarMethode _methode = VarMethode.parametrique;
  String _portefeuille = _portefeuilleDefaut;
  double _confiance = _confianceDefaut;
  int _horizon = _horizonDefaut;
  int _fenetre = _fenetreDefaut;
  double _volatilite = _volatiliteDefaut;
  double _beta = _betaDefaut;
  double? _durationModifiee;
  int _nbSimulations = _simulationsDefaut;
  String _paysCourbe = _paysCourbeDefaut;
  bool _actualisationEnCours = false;

  _ReponseVar? _reponse;
  bool _chargement = false;
  String? _erreur;
  bool _donneesAbsentes = false;
  int _requeteEnCours = 0;
  Timer? _relanceAutomatique;

  // Cadrage professionnel du graphique : l'axe des pertes est figé sur la
  // première distribution du contexte courant (méthode + portefeuille +
  // données) pour que les recalculs déplacent visiblement la cloche et les
  // seuils au lieu de re-normaliser l'échelle à chaque réponse. La réponse
  // précédente reste tracée en filigrane pour la comparaison avant/après.
  double? _axeXMin;
  double? _axeXMax;
  _ReponseVar? _reponsePrecedente;

  // Sans données, l'écran réinterroge le serveur à intervalle régulier :
  // les fichiers déposés dans data/ sont ainsi chargés automatiquement.
  static const Duration _delaiRelance = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    // Duration de référence : celle du tableau de bord Sensibilité si déjà
    // calculée, sinon null - le backend applique alors sa propre duration
    // (mêmes conventions : flux amortis pondérés par le capital restant dû)
    // et la renvoie pour affichage.
    _durationModifiee = ValueAtRiskScreen.lastDashboardDurationModifiee;
    _charger();
  }

  @override
  void dispose() {
    _relanceAutomatique?.cancel();
    super.dispose();
  }

  void _programmerRelanceAutomatique() {
    _relanceAutomatique?.cancel();
    _relanceAutomatique = Timer(_delaiRelance, () {
      if (mounted && _erreur != null) _charger();
    });
  }

  /// Récupère en ligne la dernière courbe de taux UEMOA (UMOA-Titres) pour le
  /// pays sélectionné, puis relance le calcul avec la courbe actualisée.
  Future<void> _actualiserCourbe() async {
    setState(() => _actualisationEnCours = true);
    try {
      final resume = await widget.api.actualiserCourbeUemoa(_paysCourbe);
      if (!mounted) return;
      final date = resume['date'] ?? '';
      final points = resume['nombre_points'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Courbe $_paysCourbe actualisée (au $date, $points points).',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec de l\'actualisation : $e'),
          backgroundColor: _varDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _actualisationEnCours = false);
    }
  }

  Future<void> _importerHistorique() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Fichiers Excel',
        extensions: ['xlsx'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      setState(() {
        _chargement = true;
        _erreur = null;
      });

      final bytes = await file.readAsBytes();
      await widget.api.uploadVarHistory(bytes, file.name);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Historique importé avec succès.'),
          backgroundColor: Colors.green,
        ),
      );

      _charger(nouveauContexte: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Échec de l\'importation : $e';
      });
    }
  }

  Future<void> _telechargerModele() async {
    try {
      final bytes = await widget.api.downloadVarHistoryTemplate();
      if (!mounted) return;
      final location = await getSaveLocation(
        suggestedName: 'modele_import_var.xlsx',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Excel', extensions: ['xlsx']),
        ],
      );
      if (!mounted || location == null) return;
      await saveBytesAtLocation(location, bytes, requiredExtension: '.xlsx');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modèle enregistré.'),
          backgroundColor: Colors.green,
        ),
      );
    } on PathAccessException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d\'enregistrer : le fichier est probablement déjà '
            'ouvert. Fermez-le puis réessayez.',
          ),
          backgroundColor: _varDanger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Téléchargement impossible : $e'),
          backgroundColor: _varDanger,
        ),
      );
    }
  }

  /// Bornes complètes de la distribution (histogramme, cloche théorique,
  /// VaR, IC) : servent de référence pour figer l'axe des pertes.
  (double, double)? _bornesDistribution(_ReponseVar r) {
    if (r.histogramme.isEmpty && r.courbeNormale.isEmpty) return null;
    var borneMin = r.histogramme.isNotEmpty
        ? r.histogramme.first.borneInf
        : r.courbeNormale.first.dx;
    var borneMax = r.histogramme.isNotEmpty
        ? r.histogramme.last.borneSup
        : r.courbeNormale.first.dx;
    for (final point in r.courbeNormale) {
      borneMin = math.min(borneMin, point.dx);
      borneMax = math.max(borneMax, point.dx);
    }
    borneMax = math.max(borneMax, r.varValeur);
    if (r.icVarHaute != null) {
      borneMax = math.max(borneMax, r.icVarHaute!);
    }
    return (borneMin, borneMax);
  }

  /// Recale l'axe figé sur la distribution courante (bouton « recadrer »).
  void _recadrerAxe() {
    final r = _reponse;
    if (r == null) return;
    final bornes = _bornesDistribution(r);
    if (bornes == null) return;
    setState(() {
      _axeXMin = bornes.$1;
      _axeXMax = bornes.$2;
    });
  }

  /// [nouveauContexte] : la distribution de référence change (méthode,
  /// portefeuille, nouvel import) - l'axe figé et la comparaison
  /// avant/après repartent de zéro.
  Future<void> _charger({bool nouveauContexte = false}) async {
    // La VaR historique n'interroge pas le serveur : elle n'a pas de série de
    // prix à exploiter et affiche sa méthodologie. Lancer l'appel produisait
    // un 422 présenté comme une panne.
    if (_methode.sansCalculPossible) {
      _relanceAutomatique?.cancel();
      setState(() {
        _chargement = false;
        _erreur = null;
        _donneesAbsentes = false;
      });
      return;
    }
    final numero = ++_requeteEnCours;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final json = await widget.api.fetchVarAnalysis(
        methode: _methode.segment,
        typePortefeuille: _portefeuille,
        niveauConfiance: _confiance,
        horizonJours: _horizon,
        fenetreJours: _fenetre,
        // Le bêta est transmis séparément : c'est le backend qui applique
        // VaR = Z x sigma x beta x PV (aucun calcul financier côté client).
        volatilite: _methode != VarMethode.historique ? _volatilite : null,
        beta: _methode != VarMethode.historique && _portefeuille == 'actions'
            ? _beta
            : null,
        durationModifiee:
            _methode != VarMethode.historique && _portefeuille == 'obligations'
                ? _durationModifiee
                : null,
        // lastDashboardCrd est en FCFA ; l'API VaR attend des Md FCFA.
        valeurPortefeuille: _portefeuille == 'obligations' &&
                ValueAtRiskScreen.lastDashboardCrd != null
            ? ValueAtRiskScreen.lastDashboardCrd! / 1e9
            : null,
        nbSimulations:
            _methode == VarMethode.monteCarlo ? _nbSimulations : null,
      );
      if (!mounted || numero != _requeteEnCours) return;
      _relanceAutomatique?.cancel();
      final nouvelle = _ReponseVar.fromJson(json);
      // Changement de référentiel implicite : une valeur de portefeuille ou
      // une source de données différente signifie que le book a changé
      // (nouvel import, CRD recalculé, courbe actualisée) - le cadrage et
      // la comparaison repartent alors de la nouvelle distribution.
      final ancienne = _reponse;
      final contexteChange = nouveauContexte ||
          ancienne == null ||
          ancienne.sourceDonnees != nouvelle.sourceDonnees ||
          (nouvelle.valeurPortefeuille - ancienne.valeurPortefeuille).abs() >
              ancienne.valeurPortefeuille.abs() * 1e-6;
      setState(() {
        // Filigrane avant/après : uniquement au sein d'un même contexte.
        _reponsePrecedente = contexteChange ? null : ancienne;
        _reponse = nouvelle;
        _chargement = false;
        _donneesAbsentes = false;

        // Axe figé : initialisé sur la première distribution du contexte,
        // puis étendu seulement si les données réelles (histogramme, VaR,
        // IC) le débordent - la cloche théorique, elle, est écrêtée au
        // tracé pour que les variations de paramètres restent visibles.
        if (contexteChange) {
          _axeXMin = null;
          _axeXMax = null;
        }
        if (_axeXMin == null || _axeXMax == null) {
          final bornes = _bornesDistribution(nouvelle);
          if (bornes != null) {
            _axeXMin = bornes.$1;
            _axeXMax = bornes.$2;
          }
        } else {
          if (nouvelle.histogramme.isNotEmpty) {
            _axeXMin = math.min(_axeXMin!, nouvelle.histogramme.first.borneInf);
            _axeXMax = math.max(_axeXMax!, nouvelle.histogramme.last.borneSup);
          }
          _axeXMax = math.max(_axeXMax!, nouvelle.varValeur);
          if (nouvelle.icVarHaute != null) {
            _axeXMax = math.max(_axeXMax!, nouvelle.icVarHaute!);
          }
        }
      });
    } catch (erreur) {
      if (!mounted || numero != _requeteEnCours) return;
      final donneesAbsentes = erreur is ApiException &&
          erreur.detail is Map &&
          (erreur.detail as Map)['code'] == 'VAR_DONNEES_ABSENTES';
      setState(() {
        _chargement = false;
        _erreur = erreur.toString();
        _donneesAbsentes = donneesAbsentes;
        if (donneesAbsentes) {
          // Les données absentes rendent l'ancienne réponse caduque.
          _reponse = null;
          _reponsePrecedente = null;
          _axeXMin = null;
          _axeXMax = null;
        }
      });
      _programmerRelanceAutomatique();
    }
  }

  void _changerMethode(VarMethode methode) {
    if (methode == _methode) return;
    setState(() => _methode = methode);
    _charger(nouveauContexte: true);
  }

  void _reinitialiser() {
    setState(() {
      _portefeuille = _portefeuilleDefaut;
      _confiance = _confianceDefaut;
      _horizon = _horizonDefaut;
      _fenetre = _fenetreDefaut;
      _volatilite = _volatiliteDefaut;
      _beta = _betaDefaut;
      _durationModifiee = ValueAtRiskScreen.lastDashboardDurationModifiee;
      _nbSimulations = _simulationsDefaut;
    });
    _charger(nouveauContexte: true);
  }

  void onHorizon(int value) => setState(() => _horizon = value);
  void onFenetre(int value) => setState(() => _fenetre = value);
  void onVolatilite(double value) => setState(() => _volatilite = value);
  void onVolatiliteEnd(double value) => _charger();
  void onBeta(double value) => setState(() => _beta = value);
  void onBetaEnd(double value) => _charger();
  void onDuration(double value) => setState(() => _durationModifiee = value);
  void onDurationEnd(double value) => _charger();
  void onNbSimulations(int value) => setState(() => _nbSimulations = value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: PageHeader(
            title: 'VALUE AT RISK (VaR)',
            titleFontSize: 22,
            trailing: _SelecteurMethode(
              selection: _methode,
              onChanged: _changerMethode,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              0,
              AppTheme.pagePadding,
              AppTheme.pagePadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _parameterPanelWidth,
                  child: _PanneauParametres(
                    methode: _methode,
                    portefeuille: _portefeuille,
                    confiance: _confiance,
                    horizon: _horizon,
                    fenetre: _fenetre,
                    volatilite: _volatilite,
                    beta: _beta,
                    durationModifiee: _durationModifiee ??
                        _reponse?.durationModifieePortefeuille ??
                        ValueAtRiskScreen.lastDashboardDurationModifiee ??
                        _durationDefaut,
                    nbSimulations: _nbSimulations,
                    onPortefeuille: (valeur) {
                      setState(() {
                        _portefeuille = valeur;
                        if (valeur == 'obligations') {
                          _durationModifiee =
                              ValueAtRiskScreen.lastDashboardDurationModifiee;
                        } else {
                          _durationModifiee = null;
                        }
                      });
                      _charger(nouveauContexte: true);
                    },
                    onConfiance: (valeur) {
                      setState(() => _confiance = valeur);
                      _charger();
                    },
                    onHorizon: (valeur) {
                      setState(() => _horizon = valeur);
                      _charger();
                    },
                    onFenetre: (valeur) {
                      setState(() => _fenetre = valeur);
                      _charger();
                    },
                    onVolatilite: (valeur) {
                      setState(() => _volatilite = valeur);
                    },
                    onVolatiliteEnd: (valeur) {
                      _charger();
                    },
                    onBeta: (valeur) {
                      setState(() => _beta = valeur);
                    },
                    onBetaEnd: (valeur) {
                      _charger();
                    },
                    onDuration: (valeur) {
                      setState(() => _durationModifiee = valeur);
                    },
                    onDurationEnd: (valeur) {
                      _charger();
                    },
                    onNbSimulations: (valeur) {
                      setState(() => _nbSimulations = valeur);
                      _charger();
                    },
                    paysCourbe: _paysCourbe,
                    actualisationEnCours: _actualisationEnCours,
                    onPaysCourbe: (valeur) =>
                        setState(() => _paysCourbe = valeur),
                    onActualiserCourbe: _actualiserCourbe,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _contenuPrincipal()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _contenuPrincipal() {
    if (_methode.sansCalculPossible) {
      return const _PanneauVarHistoriqueMethodologie();
    }
    final reponse = _reponse;
    if (_erreur != null && reponse == null) {
      return _CarteVar(
        // Défilable : un message d'erreur long (ex. liste de titres sans
        // historique) ne doit pas pousser les boutons d'action hors de la
        // carte (RenderFlex overflow).
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _donneesAbsentes
                      ? Icons.info_outline
                      : Icons.warning_amber_rounded,
                  size: 42,
                  color: _donneesAbsentes ? _varPrimary : Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _donneesAbsentes
                      ? 'Aucune donnée chargée'
                      : 'Erreur lors de l\'évaluation',
                  style: const TextStyle(
                    color: _varNavy,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    _donneesAbsentes
                        ? 'Veuillez importer les données de prix dans le fichier Excel pour évaluer la Value at Risk.'
                        : _erreur!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _varMuted, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                // L'import d'un historique de prix ne concerne QUE la VaR
                // historique. Le proposer sur une panne paramétrique ou
                // Monte-Carlo envoyait l'utilisateur chercher un fichier qui
                // n'aurait rien changé : ces deux méthodes partent d'une
                // volatilité, pas d'une série observée.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_donneesAbsentes) ...[
                      _BoutonImportModele(
                        onImporter: _importerHistorique,
                        onTelecharger: _telechargerModele,
                        compact: false,
                      ),
                      const SizedBox(width: 10),
                    ],
                    OutlinedButton(
                      onPressed: _charger,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (reponse == null) {
      return const _CarteVar(
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RangeeKpi(
          methode: _methode,
          reponse: reponse,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _CarteVar(
            child: _PanneauGraphique(
              methode: _methode,
              reponse: reponse,
              reponsePrecedente: _reponsePrecedente,
              confiance: _confiance,
              axeXMin: _axeXMin,
              axeXMax: _axeXMax,
              chargement: _chargement,
              erreur: _erreur,
              onReinitialiser: _reinitialiser,
              onImporterHistorique: _importerHistorique,
              onTelechargerModele: _telechargerModele,
              onRecadrer: _recadrerAxe,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sélecteur de méthode (onglets en haut à droite)
// ---------------------------------------------------------------------------

class _SelecteurMethode extends StatelessWidget {
  const _SelecteurMethode({required this.selection, required this.onChanged});

  final VarMethode selection;
  final ValueChanged<VarMethode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _varSurface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _varBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final methode in VarMethode.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: _OngletMethode(
                methode: methode,
                actif: methode == selection,
                onTap: () => onChanged(methode),
              ),
            ),
        ],
      ),
    );
  }
}

class _OngletMethode extends StatelessWidget {
  const _OngletMethode({
    required this.methode,
    required this.actif,
    required this.onTap,
  });

  final VarMethode methode;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // L'onglet sans calcul possible reste NAVIGABLE : il mène à la
    // méthodologie et au cas chiffré. Il se distingue par une pastille
    // « Méthodologie », pas par un cadenas qui laissait croire à une
    // fonctionnalité bridée.
    final sansCalcul = methode.sansCalculPossible;
    final onglet = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? Colors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              methode.libelle,
              style: TextStyle(
                color: actif ? Colors.white : _varNavy,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (sansCalcul) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: actif
                      ? Colors.white.withValues(alpha: 0.22)
                      : _varMuted.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Méthodologie',
                  style: TextStyle(
                    color: actif ? Colors.white : _varMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (!sansCalcul) return onglet;
    return Tooltip(
      message: 'Aucune série de prix observés n\'est disponible : cet onglet '
          'expose la méthode et un cas chiffré.',
      child: onglet,
    );
  }
}

// ---------------------------------------------------------------------------
// Panneau des paramètres de calcul
// ---------------------------------------------------------------------------

class _PanneauParametres extends StatelessWidget {
  const _PanneauParametres({
    required this.methode,
    required this.portefeuille,
    required this.confiance,
    required this.horizon,
    required this.fenetre,
    required this.volatilite,
    required this.beta,
    required this.durationModifiee,
    required this.nbSimulations,
    required this.onPortefeuille,
    required this.onConfiance,
    required this.onHorizon,
    required this.onFenetre,
    required this.onVolatilite,
    required this.onVolatiliteEnd,
    required this.onBeta,
    required this.onBetaEnd,
    required this.onDuration,
    required this.onDurationEnd,
    required this.onNbSimulations,
    required this.paysCourbe,
    required this.actualisationEnCours,
    required this.onPaysCourbe,
    required this.onActualiserCourbe,
  });

  final VarMethode methode;
  final String portefeuille;
  final double confiance;
  final int horizon;
  final int fenetre;
  final double volatilite;
  final double beta;
  final double durationModifiee;
  final int nbSimulations;
  final ValueChanged<String> onPortefeuille;
  final ValueChanged<double> onConfiance;
  final ValueChanged<int> onHorizon;
  final ValueChanged<int> onFenetre;
  final ValueChanged<double> onVolatilite;
  final ValueChanged<double> onVolatiliteEnd;
  final ValueChanged<double> onBeta;
  final ValueChanged<double> onBetaEnd;
  final ValueChanged<double> onDuration;
  final ValueChanged<double> onDurationEnd;
  final ValueChanged<int> onNbSimulations;
  final String paysCourbe;
  final bool actualisationEnCours;
  final ValueChanged<String> onPaysCourbe;
  final VoidCallback onActualiserCourbe;

  @override
  Widget build(BuildContext context) {
    return _CarteVar(
      color: Colors.indigo.shade50,
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paramètres de calcul',
              style: TextStyle(
                color: _varNavy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _GroupeChoix<String>(
              libelle: 'Type de portefeuille',
              valeur: portefeuille,
              valeurs: const ['obligations', 'actions'],
              libellePour: (valeur) =>
                  valeur == 'obligations' ? 'Obligations' : 'Actions',
              onChanged: onPortefeuille,
            ),
            _GroupeChoix<double>(
              libelle: 'Niveau de confiance',
              valeur: confiance,
              valeurs: const [0.95, 0.975, 0.99],
              libellePour: _pourcentage,
              onChanged: onConfiance,
            ),
            _GroupeChoix<int>(
              libelle: 'Horizon',
              valeur: horizon,
              valeurs: const [1, 3, 10, 21],
              libellePour: (valeur) => switch (valeur) {
                1 => '1 jour',
                21 => '1 mois',
                _ => '$valeur jours',
              },
              onChanged: onHorizon,
            ),
            if (methode == VarMethode.historique)
              _GroupeChoix<int>(
                libelle: 'Fenêtre historique',
                valeur: fenetre,
                valeurs: const [250, 500, 1000],
                libellePour: (valeur) => '$valeur jours',
                onChanged: onFenetre,
              ),
            if (methode != VarMethode.historique)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            portefeuille == 'obligations'
                                ? 'Volatilité des taux'
                                : 'Volatilité du marché',
                            style: const TextStyle(
                              color: _varNavy,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${(volatilite * 100).toInt()} %',
                          style: const TextStyle(
                            color: _varPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: volatilite,
                      min: 0.0,
                      max: 1.0,
                      divisions: 100,
                      activeColor: _varPrimary,
                      inactiveColor: _varBorder,
                      onChanged: onVolatilite,
                      onChangeEnd: onVolatiliteEnd,
                    ),
                  ],
                ),
              ),
            if (methode != VarMethode.historique && portefeuille == 'actions')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Bêta pondéré',
                            style: TextStyle(
                              color: _varNavy,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          beta.toStringAsFixed(2),
                          style: const TextStyle(
                            color: _varPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: beta.clamp(0.0, 3.0),
                      min: 0.0,
                      max: 3.0,
                      divisions: 300,
                      activeColor: _varPrimary,
                      inactiveColor: _varBorder,
                      onChanged: onBeta,
                      onChangeEnd: onBetaEnd,
                    ),
                  ],
                ),
              ),
            if (methode != VarMethode.historique &&
                portefeuille == 'obligations')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Duration modifiée',
                            style: TextStyle(
                              color: _varNavy,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          durationModifiee.toStringAsFixed(1),
                          style: const TextStyle(
                            color: _varPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: durationModifiee,
                      min: 0.0,
                      max: 30.0,
                      divisions: 300,
                      activeColor: _varPrimary,
                      inactiveColor: _varBorder,
                      onChanged: onDuration,
                      onChangeEnd: onDurationEnd,
                    ),
                  ],
                ),
              ),
            if (methode == VarMethode.monteCarlo)
              _GroupeChoix<int>(
                libelle: 'Nombre de simulations',
                valeur: nbSimulations,
                valeurs: const [1000, 10000, 50000],
                libellePour: (valeur) => _formatEntier.format(valeur),
                onChanged: onNbSimulations,
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupeChoix<T> extends StatelessWidget {
  const _GroupeChoix({
    required this.libelle,
    required this.valeur,
    required this.valeurs,
    required this.libellePour,
    required this.onChanged,
  });

  final String libelle;
  final T valeur;
  final List<T> valeurs;
  final String Function(T) libellePour;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            style: const TextStyle(
              color: _varMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: _varSurfaceSoft,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: _varBorder),
            ),
            child: Row(
              children: [
                for (final choix in valeurs)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (choix != valeur) onChanged(choix);
                      },
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: choix == valeur
                              ? _varDeepBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          libellePour(choix),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: choix == valeur ? Colors.white : _varNavy,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// Cartes KPI
// ---------------------------------------------------------------------------

class _RangeeKpi extends StatelessWidget {
  const _RangeeKpi({required this.methode, required this.reponse});

  final VarMethode methode;
  final _ReponseVar reponse;

  @override
  Widget build(BuildContext context) {
    final libelleVar = switch (methode) {
      VarMethode.historique => 'VAR HISTORIQUE',
      VarMethode.parametrique => 'VAR PARAMÉTRIQUE',
      VarMethode.monteCarlo => 'VAR MONTE-CARLO',
    };
    final libellePire = methode == VarMethode.monteCarlo
        ? 'PIRE PERTE SIMULÉE'
        : 'PIRE PERTE OBSERVÉE';
    // Sans observation (mode réglementaire), il n'existe aucune pire perte
    // observée : la carte affiche un tiret plutôt qu'un zéro trompeur.
    final double? pirePerte =
        methode != VarMethode.monteCarlo && reponse.nombreObservations == 0
            ? null
            : reponse.pirePerte;
    final cartes = <(String, double?, Color, IconData)>[
      (
        'VALEUR DU PORTEFEUILLE',
        reponse.valeurPortefeuille,
        _varNavy,
        Icons.account_balance_wallet_outlined
      ),
      (libelleVar, reponse.varValeur, _varNavy, Icons.analytics_outlined),
      (
        'EXPECTED SHORTFALL',
        reponse.expectedShortfall,
        _varNavy,
        Icons.trending_down_outlined
      ),
      (libellePire, pirePerte, _varDanger, Icons.warning_amber_outlined),
    ];
    final unite = _uniteEchelleVar(reponse.valeurPortefeuille);
    return Row(
      children: [
        for (var indice = 0; indice < cartes.length; indice++) ...[
          if (indice > 0) const SizedBox(width: 12),
          Expanded(
            child: _CarteKpi(
              libelle: cartes[indice].$1,
              valeur: cartes[indice].$2,
              accent: cartes[indice].$3,
              icone: cartes[indice].$4,
              unite: unite,
            ),
          ),
        ],
      ],
    );
  }
}

class _CarteKpi extends StatelessWidget {
  const _CarteKpi({
    required this.libelle,
    required this.valeur,
    required this.accent,
    required this.icone,
    required this.unite,
  });

  final String libelle;
  final double? valeur;
  final Color accent;
  final IconData icone;
  final PortfolioAmountUnit unite;

  @override
  Widget build(BuildContext context) {
    final unit = unite;
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: _varBorder, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.indigo.shade400,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          valeur == null
              ? const Text(
                  '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _varNavy,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _mdFormat(valeur!, unit: unit).$1,
                        style: const TextStyle(
                          color: _varNavy,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextSpan(
                        text: ' ${_mdFormat(valeur!, unit: unit).$2}',
                        style: const TextStyle(
                          color: _varMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panneau graphique
// ---------------------------------------------------------------------------

class _PanneauGraphique extends StatelessWidget {
  const _PanneauGraphique({
    required this.methode,
    required this.reponse,
    required this.reponsePrecedente,
    required this.confiance,
    required this.axeXMin,
    required this.axeXMax,
    required this.chargement,
    required this.erreur,
    required this.onReinitialiser,
    required this.onImporterHistorique,
    required this.onTelechargerModele,
    required this.onRecadrer,
  });

  final VarMethode methode;
  final _ReponseVar reponse;
  final _ReponseVar? reponsePrecedente;
  final double confiance;
  final double? axeXMin;
  final double? axeXMax;
  final bool chargement;
  final String? erreur;
  final VoidCallback onReinitialiser;
  final VoidCallback onImporterHistorique;
  final VoidCallback onTelechargerModele;
  final VoidCallback onRecadrer;

  @override
  Widget build(BuildContext context) {
    // Même unité que les cartes KPI : adaptée à la taille du portefeuille
    // pour ne pas afficher un axe entièrement à « 0 ».
    final unit = _uniteEchelleVar(reponse.valeurPortefeuille);
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
                  Row(
                    children: [
                      if (reponse.sourceDonnees == 'simulation') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _varSurfaceSoft,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _varBorder),
                          ),
                          child: const Text(
                            'Données simulées',
                            style: TextStyle(
                              color: _varMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (chargement) ...[
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Recadrer l\'axe sur la distribution courante',
              child: InkWell(
                onTap: onRecadrer,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _varBorder),
                  ),
                  child: const Icon(
                    Icons.center_focus_strong,
                    size: 15,
                    color: _varMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _BoutonImportModele(
              onImporter: onImporterHistorique,
              onTelecharger: onTelechargerModele,
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Réinitialiser les paramètres',
              child: InkWell(
                onTap: onReinitialiser,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _varBorder),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    size: 15,
                    color: _varMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (erreur != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              erreur!,
              style: const TextStyle(color: _varDanger, fontSize: 11.5),
            ),
          ),
        if (methode == VarMethode.parametrique &&
            reponse.hypotheseNormaleDouteuse)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'La distribution observée s\'écarte de la loi normale '
              '(asymétrie ou queues épaisses), la VaR paramétrique peut '
              'sous-estimer le risque.',
              style: TextStyle(
                color: _varOrange.withValues(alpha: 0.95),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: _GraphiqueVarInteractif(
            methode: methode,
            reponse: reponse,
            reponsePrecedente: reponsePrecedente,
            confiance: confiance,
            unit: unit,
            xMinFige: axeXMin,
            xMaxFige: axeXMax,
          ),
        ),
      ],
    );
  }
}

/// Enveloppe interactive du graphique VaR : suit la souris pour afficher un
/// repère (ligne + point + infobulle) sur la courbe ou l'histogramme au
/// survol, sans quoi le graphique dessiné au canvas resterait statique.
class _GraphiqueVarInteractif extends StatefulWidget {
  const _GraphiqueVarInteractif({
    required this.methode,
    required this.reponse,
    required this.reponsePrecedente,
    required this.confiance,
    required this.unit,
    required this.xMinFige,
    required this.xMaxFige,
  });

  final VarMethode methode;
  final _ReponseVar reponse;
  final _ReponseVar? reponsePrecedente;
  final double confiance;
  final PortfolioAmountUnit unit;
  final double? xMinFige;
  final double? xMaxFige;

  @override
  State<_GraphiqueVarInteractif> createState() =>
      _GraphiqueVarInteractifState();
}

class _GraphiqueVarInteractifState extends State<_GraphiqueVarInteractif> {
  Offset? _survol;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => setState(() => _survol = event.localPosition),
      onExit: (_) => setState(() => _survol = null),
      child: CustomPaint(
        painter: _HistogrammeVarPainter(
          methode: widget.methode,
          reponse: widget.reponse,
          reponsePrecedente: widget.reponsePrecedente,
          confiance: widget.confiance,
          unit: widget.unit,
          xMinFige: widget.xMinFige,
          xMaxFige: widget.xMaxFige,
          survol: _survol,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bouton combiné historique de prix (importer / télécharger le modèle)
// ---------------------------------------------------------------------------

enum _ActionImportModele { importer, telecharger }

/// Un seul point d'entrée pour l'historique de prix VaR : on clique et on
/// choisit d'importer un fichier ou de télécharger le modèle Excel vide.
/// `compact` affiche une icône ronde (utilisée dans l'en-tête du graphique,
/// une fois une méthode déjà chargée) ; sinon un bouton étiqueté, utilisé
/// dans l'écran d'erreur/données absentes où c'est la seule action possible.
class _BoutonImportModele extends StatelessWidget {
  const _BoutonImportModele({
    required this.onImporter,
    required this.onTelecharger,
    this.compact = true,
  });

  final VoidCallback onImporter;
  final VoidCallback onTelecharger;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bouton = PopupMenuButton<_ActionImportModele>(
      tooltip: 'Historique de prix',
      onSelected: (action) {
        switch (action) {
          case _ActionImportModele.importer:
            onImporter();
          case _ActionImportModele.telecharger:
            onTelecharger();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _ActionImportModele.importer,
          child: _MenuImportModeleItem(
            icon: Icons.upload_file,
            label: 'Importer l\'historique',
          ),
        ),
        PopupMenuItem(
          value: _ActionImportModele.telecharger,
          child: _MenuImportModeleItem(
            icon: Icons.description_outlined,
            label: 'Télécharger le modèle',
          ),
        ),
      ],
      child: compact
          ? Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _varBorder),
              ),
              child: const Icon(
                Icons.upload_file,
                size: 15,
                color: _varMuted,
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: _varBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file, size: 15, color: _varPrimary),
                  SizedBox(width: 8),
                  Text(
                    'Historique de prix',
                    style: TextStyle(
                      color: _varPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.expand_more, size: 16, color: _varPrimary),
                ],
              ),
            ),
    );
    return compact
        ? Tooltip(message: 'Historique de prix', child: bouton)
        : bouton;
  }
}

class _MenuImportModeleItem extends StatelessWidget {
  const _MenuImportModeleItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _varMuted),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Peintre de l'histogramme
// ---------------------------------------------------------------------------

class _HistogrammeVarPainter extends CustomPainter {
  _HistogrammeVarPainter({
    required this.methode,
    required this.reponse,
    required this.reponsePrecedente,
    required this.confiance,
    required this.unit,
    required this.xMinFige,
    required this.xMaxFige,
    this.survol,
  });

  final VarMethode methode;
  final _ReponseVar reponse;

  /// Réponse du recalcul précédent, tracée en filigrane pour la
  /// comparaison avant/après (même contexte uniquement).
  final _ReponseVar? reponsePrecedente;
  final double confiance;
  final PortfolioAmountUnit unit;

  /// Axe des pertes figé sur la distribution de référence du contexte :
  /// les recalculs déplacent alors visiblement la cloche et les seuils.
  final double? xMinFige;
  final double? xMaxFige;

  /// Position locale du curseur (repère de survol), nulle hors interaction.
  final Offset? survol;

  static const double _gauche = 56;
  static const double _droite = 18;
  static const double _haut = 56;
  static const double _bas = 52;

  @override
  void paint(Canvas canvas, Size size) {
    final classes = reponse.histogramme;
    // Sans histogramme mais avec courbe normale (mode réglementaire sans
    // historique) : la cloche théorique est tracée seule.
    if (classes.isEmpty && reponse.courbeNormale.isEmpty) return;
    final zone = Rect.fromLTRB(
      _gauche,
      _haut,
      math.max(_gauche + 10, size.width - _droite),
      math.max(_haut + 10, size.height - _bas),
    );

    double xMin;
    double xMax;
    if (xMinFige != null && xMaxFige != null) {
      // Axe figé : le cadre reste stable d'un recalcul à l'autre. Seules
      // les données réelles (histogramme, VaR, IC) peuvent l'étendre ; la
      // cloche théorique est écrêtée au tracé si elle déborde.
      xMin = xMinFige!;
      xMax = math.max(xMaxFige!, reponse.varValeur);
      if (classes.isNotEmpty) {
        xMin = math.min(xMin, classes.first.borneInf);
        xMax = math.max(xMax, classes.last.borneSup);
      }
      if (reponse.icVarHaute != null) {
        xMax = math.max(xMax, reponse.icVarHaute!);
      }
    } else {
      // Cadrage automatique : ajusté à l'étendue de la distribution.
      xMin = classes.isNotEmpty
          ? classes.first.borneInf
          : reponse.courbeNormale.first.dx;
      xMax = classes.isNotEmpty
          ? classes.last.borneSup
          : reponse.courbeNormale.last.dx;
      for (final point in reponse.courbeNormale) {
        xMin = math.min(xMin, point.dx);
        xMax = math.max(xMax, point.dx);
      }
      xMax = math.max(xMax, reponse.varValeur);
      if (reponse.icVarHaute != null) {
        xMax = math.max(xMax, reponse.icVarHaute!);
      }
    }
    final margeX = (xMax - xMin).abs() < 1e-9 ? 1.0 : (xMax - xMin) * 0.02;
    xMin -= margeX;
    xMax += margeX;

    var yMax = 0.0;
    for (final classe in classes) {
      yMax = math.max(yMax, classe.effectif.toDouble());
    }
    for (final point in reponse.courbeNormale) {
      yMax = math.max(yMax, point.dy);
    }
    if (yMax <= 0) yMax = 1;
    yMax *= 1.08;

    double xPixel(double valeur) =>
        zone.left + (valeur - xMin) / (xMax - xMin) * zone.width;
    double yPixel(double valeur) => zone.bottom - (valeur / yMax) * zone.height;

    _peindreGrille(canvas, zone, yMax, xMin, xMax, xPixel);
    _peindreZoneExtreme(canvas, zone, xPixel);
    _peindreBandeIc(canvas, zone, xPixel);
    _peindreBarres(canvas, zone, classes, xPixel, yPixel);
    _peindreComparaison(canvas, zone, xPixel, yPixel);
    _peindreCourbeNormale(canvas, zone, xPixel, yPixel);
    _peindrePercentiles(canvas, zone, xPixel);
    _peindreLigneVar(canvas, zone, xPixel);
    _peindreAxes(canvas, zone, size);
    _peindreLegendeComparaison(canvas, zone);
    _peindreSurvol(canvas, zone, xMin, xMax, xPixel, yPixel);
  }

  /// Repère interactif au survol : ligne verticale, point sur la courbe (ou
  /// la barre) la plus proche, et infobulle avec la valeur pointée. Rien à
  /// afficher hors de la zone de tracé ou en l'absence de donnée à ce point.
  void _peindreSurvol(
    Canvas canvas,
    Rect zone,
    double xMin,
    double xMax,
    double Function(double) xPixel,
    double Function(double) yPixel,
  ) {
    final position = survol;
    if (position == null || !zone.contains(position)) return;

    final xValeur = xMin + (position.dx - zone.left) / zone.width * (xMax - xMin);
    final classe = reponse.histogramme.isNotEmpty ? _classePour(xValeur) : null;
    final densite =
        reponse.histogramme.isEmpty ? _densiteInterpolee(xValeur) : null;
    if (classe == null && densite == null) return;

    final yValeur = classe != null ? classe.effectif.toDouble() : densite!;
    final xLigne = position.dx;
    final yPoint = math.max(zone.top, yPixel(yValeur));

    canvas.save();
    canvas.clipRect(zone);
    canvas.drawLine(
      Offset(xLigne, zone.top),
      Offset(xLigne, zone.bottom),
      Paint()
        ..color = _varNavy.withValues(alpha: 0.28)
        ..strokeWidth = 1,
    );
    canvas.restore();

    canvas.drawCircle(Offset(xLigne, yPoint), 4, Paint()..color = _varPrimary);
    canvas.drawCircle(
      Offset(xLigne, yPoint),
      4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final libelle = classe != null
        ? '${_md(xValeur, unit: unit)} · ${_formatEntier.format(classe.effectif)} obs.'
        : '${_md(xValeur, unit: unit)} · densité ${densite!.round()}';
    final largeurEstimee = libelle.length * 6.2 + 18;
    final xEtiquette = xLigne + largeurEstimee + 10 > zone.right
        ? xLigne - largeurEstimee - 10
        : xLigne + 10;
    _etiquette(
      canvas,
      libelle,
      Offset(
        math.max(zone.left, math.min(xEtiquette, zone.right - largeurEstimee)),
        math.max(zone.top - 4, yPoint - 34),
      ),
      couleurTexte: _varDeepBlue,
      couleurBord: _varPrimary.withValues(alpha: 0.6),
    );
  }

  /// Classe d'histogramme contenant la valeur donnée, s'il y en a une.
  _ClasseHistogramme? _classePour(double x) {
    for (final classe in reponse.histogramme) {
      if (x >= classe.borneInf && x <= classe.borneSup) return classe;
    }
    return null;
  }

  /// Densité de la courbe normale interpolée linéairement entre les deux
  /// points encadrant la valeur (la courbe backend est déjà échantillonnée
  /// finement, l'interpolation reste donc visuellement fidèle).
  double? _densiteInterpolee(double x) {
    final points = reponse.courbeNormale;
    if (points.isEmpty) return null;
    if (x <= points.first.dx) return points.first.dy;
    if (x >= points.last.dx) return points.last.dy;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (x >= a.dx && x <= b.dx) {
        final t = (x - a.dx) / (b.dx - a.dx);
        return a.dy + (b.dy - a.dy) * t;
      }
    }
    return null;
  }

  /// Légende discrète du filigrane, uniquement quand il est visible.
  void _peindreLegendeComparaison(Canvas canvas, Rect zone) {
    if (reponsePrecedente == null) return;
    final y = zone.bottom + 38;
    canvas.drawLine(
      Offset(zone.center.dx - 60, y),
      Offset(zone.center.dx - 46, y),
      Paint()
        ..color = _varDeepBlue.withValues(alpha: 0.30)
        ..strokeWidth = 2,
    );
    _texte(
      canvas,
      'recalcul précédent',
      Offset(zone.center.dx - 40, y - 6),
      couleur: _varMuted,
      taille: 9.5,
    );
  }

  /// Filigrane avant/après : cloche et ligne VaR du recalcul précédent,
  /// estompées, pour lire immédiatement l'effet d'un changement de
  /// paramètre sur l'axe figé.
  void _peindreComparaison(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
    double Function(double) yPixel,
  ) {
    final precedente = reponsePrecedente;
    if (precedente == null) return;

    if (methode == VarMethode.parametrique &&
        precedente.courbeNormale.isNotEmpty) {
      final chemin = Path();
      var premier = true;
      for (final point in precedente.courbeNormale) {
        final position = Offset(
          xPixel(point.dx),
          math.max(zone.top, yPixel(point.dy)),
        );
        if (premier) {
          chemin.moveTo(position.dx, position.dy);
          premier = false;
        } else {
          chemin.lineTo(position.dx, position.dy);
        }
      }
      canvas.save();
      canvas.clipRect(zone);
      canvas.drawPath(
        chemin,
        Paint()
          ..color = _varDeepBlue.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.restore();
    }

    // Ligne VaR précédente : uniquement si elle est distincte de la
    // courante (sinon rien n'a changé, inutile de surcharger).
    final xPrecedent = xPixel(precedente.varValeur);
    final xCourant = xPixel(reponse.varValeur);
    if (xPrecedent >= zone.left &&
        xPrecedent <= zone.right &&
        (xPrecedent - xCourant).abs() > 2) {
      _ligneVerticalePointillee(
        canvas,
        xPrecedent,
        zone.top,
        zone.bottom,
        Paint()
          ..color = _varDanger.withValues(alpha: 0.38)
          ..strokeWidth = 1.4,
      );
      _texte(
        canvas,
        'VaR préc.',
        Offset(xPrecedent, zone.top - 12),
        couleur: _varDanger.withValues(alpha: 0.55),
        taille: 9.5,
        centreHorizontal: true,
      );
    }
  }

  void _peindreGrille(
    Canvas canvas,
    Rect zone,
    double yMax,
    double xMin,
    double xMax,
    double Function(double) xPixel,
  ) {
    final stylo = Paint()
      ..color = _varBorder.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    // Graduations entières de l'axe des fréquences.
    final pas = _pasEntier(yMax);
    for (var valeur = 0; valeur <= yMax; valeur += pas) {
      final y = zone.bottom - (valeur / yMax) * zone.height;
      canvas.drawLine(Offset(zone.left, y), Offset(zone.right, y), stylo);
      _texte(
        canvas,
        _formatEntier.format(valeur),
        Offset(zone.left - 8, y),
        couleur: _varMuted,
        taille: 10,
        alignementDroite: true,
        centreVertical: true,
      );
    }

    // Graduations horizontales en convention française.
    const nombreTicks = 8;
    for (var indice = 0; indice <= nombreTicks; indice++) {
      final valeur = xMin + (xMax - xMin) * indice / nombreTicks;
      final x = xPixel(valeur);
      canvas.drawLine(
        Offset(x, zone.bottom),
        Offset(x, zone.bottom + 4),
        Paint()
          ..color = _varMuted
          ..strokeWidth = 1,
      );
      // Valeur du tick dans l'unité d'affichage ; les valeurs qui
      // arrondiraient à zéro sont ramenées à 0 pour éviter un « -0 ».
      var valeurAxe = valeur * 1e9 / unit.divisor;
      if (valeurAxe.abs() < 0.05) valeurAxe = 0;
      _texte(
        canvas,
        _formatAxe.format(valeurAxe),
        Offset(x, zone.bottom + 7),
        couleur: _varMuted,
        taille: 10,
        centreHorizontal: true,
      );
    }
  }

  int _pasEntier(double yMax) {
    final brut = yMax / 5;
    if (brut <= 1) return 1;
    final magnitude = math.pow(10, (math.log(brut) / math.ln10).floor());
    for (final facteur in [1, 2, 5, 10]) {
      final pas = (magnitude * facteur).round();
      if (pas >= brut) return math.max(1, pas);
    }
    return math.max(1, brut.ceil());
  }

  void _peindreZoneExtreme(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
  ) {
    final xVar = xPixel(reponse.varValeur).clamp(zone.left, zone.right);
    final rect = Rect.fromLTRB(xVar, zone.top, zone.right, zone.bottom);
    if (rect.width <= 0) return;
    canvas.drawRect(
      rect,
      Paint()..color = _varOrange.withValues(alpha: 0.12),
    );
  }

  void _peindreBandeIc(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
  ) {
    final basse = reponse.icVarBasse;
    final haute = reponse.icVarHaute;
    if (basse == null || haute == null) return;
    final gauche = xPixel(basse).clamp(zone.left, zone.right);
    final droite = xPixel(haute).clamp(zone.left, zone.right);
    if (droite - gauche <= 0) return;
    canvas.drawRect(
      Rect.fromLTRB(gauche, zone.top, droite, zone.bottom),
      Paint()..color = _varDanger.withValues(alpha: 0.08),
    );
  }

  void _peindreBarres(
    Canvas canvas,
    Rect zone,
    List<_ClasseHistogramme> classes,
    double Function(double) xPixel,
    double Function(double) yPixel,
  ) {
    for (final classe in classes) {
      if (classe.effectif <= 0) continue;
      final gauche = xPixel(classe.borneInf);
      final droite = xPixel(classe.borneSup);
      final haut = yPixel(classe.effectif.toDouble());
      final milieu = (classe.borneInf + classe.borneSup) / 2;
      final couleur = milieu >= reponse.varValeur ? _varOrange : _varBarBlue;
      final rect = Rect.fromLTRB(
        gauche + 1,
        haut,
        math.max(gauche + 2, droite - 1),
        zone.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        Paint()..color = couleur.withValues(alpha: 0.85),
      );
    }
  }

  void _peindreCourbeNormale(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
    double Function(double) yPixel,
  ) {
    if (methode != VarMethode.parametrique || reponse.courbeNormale.isEmpty) {
      return;
    }
    final chemin = Path();
    var premier = true;
    for (final point in reponse.courbeNormale) {
      final position = Offset(
        xPixel(point.dx),
        math.max(zone.top, yPixel(point.dy)),
      );
      if (premier) {
        chemin.moveTo(position.dx, position.dy);
        premier = false;
      } else {
        chemin.lineTo(position.dx, position.dy);
      }
    }
    // Avec un axe figé, la cloche peut déborder du cadre : écrêtage.
    canvas.save();
    canvas.clipRect(zone);
    // Sans histogramme, la cloche théorique est légèrement remplie pour
    // rester lisible seule.
    if (reponse.histogramme.isEmpty && reponse.courbeNormale.isNotEmpty) {
      final remplissage = Path.from(chemin)
        ..lineTo(xPixel(reponse.courbeNormale.last.dx), zone.bottom)
        ..lineTo(xPixel(reponse.courbeNormale.first.dx), zone.bottom)
        ..close();
      canvas.drawPath(
        remplissage,
        Paint()..color = _varDeepBlue.withValues(alpha: 0.07),
      );
    }
    canvas.drawPath(
      chemin,
      Paint()
        ..color = _varDeepBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  void _peindrePercentiles(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
  ) {
    // Hauteurs étagées pour éviter le chevauchement des étiquettes
    // lorsque les seuils sont proches.
    final seuils = <(double, String, double)>[
      (reponse.p95, 'P95', 26),
      if (reponse.p975 != null) (reponse.p975!, 'P97,5', 52),
      (reponse.p99, 'P99', reponse.p975 != null ? 78 : 52),
    ];
    for (final (valeur, libelle, hauteur) in seuils) {
      final x = xPixel(valeur);
      if (x < zone.left || x > zone.right) continue;
      final stylo = Paint()
        ..color = _varNavy.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      _ligneVerticalePointillee(canvas, x, zone.top, zone.bottom, stylo);
      _etiquette(
        canvas,
        libelle,
        Offset(x - 14, zone.bottom - hauteur),
        couleurTexte: _varNavy,
        couleurBord: _varBorder,
      );
    }
  }

  void _peindreLigneVar(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
  ) {
    final x = xPixel(reponse.varValeur).clamp(zone.left, zone.right);
    canvas.drawLine(
      Offset(x, zone.top - 6),
      Offset(x, zone.bottom),
      Paint()
        ..color = _varDanger
        ..strokeWidth = 2,
    );
    final libelle =
        'VaR ${_pourcentage(confiance)} : ${_md(reponse.varValeur, unit: unit)}';
    final largeurEstimee = libelle.length * 6.4 + 18;
    final xEtiquette =
        x + largeurEstimee + 12 > zone.right ? x - largeurEstimee - 10 : x + 10;
    _etiquette(
      canvas,
      libelle,
      Offset(math.max(zone.left, xEtiquette), zone.top - 46),
      couleurTexte: _varDanger,
      couleurBord: _varDanger.withValues(alpha: 0.55),
    );
  }

  void _peindreAxes(Canvas canvas, Rect zone, Size size) {
    final stylo = Paint()
      ..color = _varMuted.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(zone.left, zone.top),
      Offset(zone.left, zone.bottom),
      stylo,
    );
    canvas.drawLine(
      Offset(zone.left, zone.bottom),
      Offset(zone.right, zone.bottom),
      stylo,
    );

    // Titre de l'axe vertical : effectifs avec histogramme, densité
    // relative (pic = 100) quand seule la loi théorique est tracée.
    _texte(
      canvas,
      reponse.histogramme.isEmpty ? 'Densité (base 100)' : 'Fréquence',
      Offset(zone.left - 46, zone.top - 18),
      couleur: _varMuted,
      taille: 10.5,
    );

    // Titre et sens de lecture de l'axe horizontal.
    _texte(
      canvas,
      'Pertes / gains (${unit.label})',
      Offset(zone.center.dx, zone.bottom + 24),
      couleur: _varMuted,
      taille: 10.5,
      centreHorizontal: true,
    );
    _texte(
      canvas,
      '← gains',
      Offset(zone.left, zone.bottom + 24),
      couleur: _varMuted,
      taille: 10.5,
    );
    _texte(
      canvas,
      'pertes sévères →',
      Offset(zone.right, zone.bottom + 24),
      couleur: _varMuted,
      taille: 10.5,
      alignementDroite: true,
    );
  }

  void _ligneVerticalePointillee(
    Canvas canvas,
    double x,
    double haut,
    double bas,
    Paint stylo,
  ) {
    const segment = 4.0;
    const espace = 4.0;
    var y = haut;
    while (y < bas) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(bas, y + segment)),
        stylo,
      );
      y += segment + espace;
    }
  }

  void _texte(
    Canvas canvas,
    String contenu,
    Offset position, {
    required Color couleur,
    required double taille,
    bool alignementDroite = false,
    bool centreHorizontal = false,
    bool centreVertical = false,
  }) {
    final peintre = TextPainter(
      text: TextSpan(
        text: contenu,
        style: TextStyle(
          color: couleur,
          fontSize: taille,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var decalage = position;
    if (alignementDroite) {
      decalage = decalage.translate(-peintre.width, 0);
    } else if (centreHorizontal) {
      decalage = decalage.translate(-peintre.width / 2, 0);
    }
    if (centreVertical) {
      decalage = decalage.translate(0, -peintre.height / 2);
    }
    peintre.paint(canvas, decalage);
  }

  void _etiquette(
    Canvas canvas,
    String contenu,
    Offset position, {
    required Color couleurTexte,
    required Color couleurBord,
  }) {
    final peintre = TextPainter(
      text: TextSpan(
        text: contenu,
        style: TextStyle(
          color: couleurTexte,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      peintre.width + 14,
      peintre.height + 8,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(
        rrect, Paint()..color = Colors.white.withValues(alpha: 0.92));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = couleurBord
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    peintre.paint(canvas, position.translate(7, 4));
  }

  @override
  bool shouldRepaint(covariant _HistogrammeVarPainter ancien) {
    return ancien.reponse != reponse ||
        ancien.reponsePrecedente != reponsePrecedente ||
        ancien.methode != methode ||
        ancien.confiance != confiance ||
        ancien.xMinFige != xMinFige ||
        ancien.xMaxFige != xMaxFige ||
        ancien.survol != survol;
  }
}

// ---------------------------------------------------------------------------
// Carte de base
// ---------------------------------------------------------------------------

class _CarteVar extends StatelessWidget {
  const _CarteVar({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = _varSurface,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _varBorder),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// VaR historique : méthodologie et cas chiffré
// ---------------------------------------------------------------------------

/// Panneau de la VaR historique, en l'absence de série de prix réelle.
///
/// Décision assumée : plutôt qu'un écran d'erreur ou une distribution
/// fabriquée, la méthode est exposée pour ce qu'elle est, avec un cas chiffré
/// entièrement vérifiable à la main. Un lecteur qui n'a jamais calculé de VaR
/// doit pouvoir refaire les lignes ci-dessous sur un coin de table et
/// retrouver le même nombre.
///
/// Les nombres du cas ne sont PAS le portefeuille : ce sont des données
/// d'illustration, et l'écran le dit.
class _PanneauVarHistoriqueMethodologie extends StatelessWidget {
  const _PanneauVarHistoriqueMethodologie();

  /// Dix pires séances d'un échantillon fictif de 250, en millions de FCFA,
  /// classées de la perte la plus lourde à la plus légère.
  static const List<double> _pertesTriees = [
    412,
    388,
    351,
    297,
    264,
    241,
    228,
    219,
    203,
    197,
  ];

  static const int _nbSeances = 250;
  static const double _confiance = 0.99;

  /// Rang du quantile : 250 x (1 - 99 %) = 2,5, arrondi au supérieur.
  static int get _rang => (_nbSeances * (1 - _confiance)).ceil();

  static double get _var => _pertesTriees[_rang - 1];

  /// Perte moyenne au-delà de la VaR : moyenne des rangs 1 à [_rang].
  static double get _perteMoyenneAuDela {
    final retenues = _pertesTriees.take(_rang).toList(growable: false);
    return retenues.reduce((a, b) => a + b) / retenues.length;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CarteVar(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Méthode de la VaR historique',
                  style: TextStyle(
                    color: _varNavy,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Aucune loi de probabilité n\'est supposée. On observe ce '
                  'que le portefeuille a réellement perdu, séance après '
                  'séance, puis on lit directement dans cette série le seuil '
                  'qui n\'a été dépassé que dans 1 % des cas.',
                  style: TextStyle(
                    color: _varMuted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                _EtapeMethodologie(
                  numero: 1,
                  titre: 'Reconstituer la série des variations',
                  texte: 'Pour chaque séance de la fenêtre, on revalorise le '
                      'portefeuille ACTUEL avec les prix de la veille, puis '
                      'avec ceux du jour. La différence est le gain ou la '
                      'perte qu\'il aurait subi ce jour-là. La composition ne '
                      'change jamais : seuls les prix bougent.',
                ),
                _EtapeMethodologie(
                  numero: 2,
                  titre: 'Classer les pertes, de la plus lourde à la plus '
                      'légère',
                  texte: 'Les gains restent dans la série mais se retrouvent '
                      'en fin de classement : ils ne jouent aucun rôle dans '
                      'le seuil de perte.',
                ),
                _EtapeMethodologie(
                  numero: 3,
                  titre: 'Lire la perte au rang correspondant au seuil',
                  texte: 'À 99 % sur 250 séances, le rang vaut '
                      '250 × (1 − 0,99) = 2,5, arrondi à 3. La VaR est la '
                      'troisième perte du classement. Arrondir vers le haut '
                      'est le choix prudent : il retient une perte plus '
                      'lourde, jamais plus légère.',
                ),
                SizedBox(height: 4),
                _EncadreFormule(
                  formule: 'VaR = perte de rang ⌈n × (1 − c)⌉',
                  legende: 'n = nombre de séances observées, '
                      'c = niveau de confiance',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CarteVar(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        'Cas chiffré, de bout en bout',
                        style: TextStyle(
                          color: _varNavy,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _varOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Données d\'illustration',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Portefeuille de 12,4 Md FCFA, fenêtre de 250 séances, '
                  'niveau de confiance 99 %. Voici les dix pires séances de '
                  'la fenêtre, en millions de FCFA :',
                  style: TextStyle(
                    color: _varMuted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _TableauPertesClassees(
                  pertes: _pertesTriees,
                  rangRetenu: _rang,
                ),
                const SizedBox(height: 14),
                const _EncadreFormule(
                  formule: 'Rang = ⌈250 × (1 − 0,99)⌉ = ⌈2,5⌉ = 3',
                  legende: 'La VaR est donc la 3ᵉ perte du classement',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ResultatCas(
                        libelle: 'VaR 99 % à 1 jour',
                        valeur: '${_var.toStringAsFixed(0)} M FCFA',
                        note: '3ᵉ perte du classement',
                        couleur: _varDanger,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ResultatCas(
                        libelle: 'Perte moyenne au-delà du seuil',
                        valeur:
                            '${_perteMoyenneAuDela.toStringAsFixed(0)} M FCFA',
                        note: 'Moyenne des rangs 1 à 3',
                        couleur: _varOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Lecture : sur les 250 séances observées, deux seulement ont '
                  'coûté plus de ${_var.toStringAsFixed(0)} M FCFA. Un jour de '
                  'marché sur cent, la perte dépasse ce seuil ; ces jours-là, '
                  'elle s\'est élevée à '
                  '${_perteMoyenneAuDela.toStringAsFixed(0)} M FCFA en '
                  'moyenne. La VaR dit à partir de quel montant on entre dans '
                  'le 1 % défavorable, jamais jusqu\'où la perte peut aller : '
                  'c\'est le rôle de la seconde mesure.',
                  style: const TextStyle(
                    color: _varNavy,
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _CarteVar(
            padding: EdgeInsets.all(18),
            color: _varSurfaceSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ce que la méthode exige, et pourquoi elle est inactive ici',
                  style: TextStyle(
                    color: _varNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                _PointExigence(
                  texte: 'Une série de prix observés, une valeur par séance et '
                      'par titre. Les titres publics de la zone étant émis par '
                      'adjudication et non cotés en continu, cette série '
                      'n\'existe pas dans les fichiers dont nous disposons.',
                ),
                _PointExigence(
                  texte: 'Une profondeur suffisante : 250 séances au minimum. '
                      'En deçà, le rang du quantile tombe sur les toutes '
                      'premières observations et la VaR se confond avec la '
                      'perte maximale de l\'échantillon.',
                ),
                _PointExigence(
                  texte: 'Une composition figée sur toute la fenêtre. Une '
                      'ligne entrée en portefeuille il y a trois mois n\'a pas '
                      'd\'historique sur les neuf précédents : elle doit être '
                      'reconstituée à partir d\'un titre de référence, ou '
                      'écartée.',
                ),
                SizedBox(height: 12),
                Text(
                  'Tant que ces conditions ne sont pas réunies, l\'onglet '
                  'reste inactif. Publier un quantile calculé sur une série '
                  'reconstituée reviendrait à présenter comme observé un '
                  'chiffre qui ne l\'est pas. Les VaR paramétrique et '
                  'Monte-Carlo, elles, n\'ont pas besoin d\'historique : elles '
                  'partent d\'une volatilité et d\'une hypothèse de '
                  'distribution, et restent disponibles.',
                  style: TextStyle(
                    color: _varMuted,
                    fontSize: 12.5,
                    height: 1.55,
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

class _EtapeMethodologie extends StatelessWidget {
  const _EtapeMethodologie({
    required this.numero,
    required this.titre,
    required this.texte,
  });

  final int numero;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _varDeepBlue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    color: _varNavy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  texte,
                  style: const TextStyle(
                    color: _varMuted,
                    fontSize: 12.3,
                    height: 1.5,
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

class _EncadreFormule extends StatelessWidget {
  const _EncadreFormule({required this.formule, required this.legende});

  final String formule;
  final String legende;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _varDeepBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: const Border(
          left: BorderSide(color: _varDeepBlue, width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formule,
            style: const TextStyle(
              color: _varNavy,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            legende,
            style: const TextStyle(
              color: _varMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Classement des pertes, la ligne du quantile mise en évidence.
class _TableauPertesClassees extends StatelessWidget {
  const _TableauPertesClassees({
    required this.pertes,
    required this.rangRetenu,
  });

  final List<double> pertes;
  final int rangRetenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _varBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: _varDeepBlue,
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Rang',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Perte de la séance',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Position par rapport au seuil',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < pertes.length; i++)
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: i + 1 == rangRetenu
                  ? _varDanger.withValues(alpha: 0.09)
                  : (i.isOdd ? _varSurfaceSoft : Colors.transparent),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i + 1 == rangRetenu ? _varDanger : _varNavy,
                        fontSize: 12,
                        fontWeight: i + 1 == rangRetenu
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      '${pertes[i].toStringAsFixed(0)} M',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: i + 1 == rangRetenu ? _varDanger : _varNavy,
                        fontSize: 12,
                        fontWeight: i + 1 == rangRetenu
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      i + 1 < rangRetenu
                          ? 'Au-delà du seuil'
                          : i + 1 == rangRetenu
                              ? 'Seuil retenu : VaR 99 %'
                              : 'En deçà du seuil',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: i + 1 == rangRetenu ? _varDanger : _varMuted,
                        fontSize: 11,
                        fontWeight: i + 1 == rangRetenu
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
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

class _ResultatCas extends StatelessWidget {
  const _ResultatCas({
    required this.libelle,
    required this.valeur,
    required this.note,
    required this.couleur,
  });

  final String libelle;
  final String valeur;
  final String note;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            style: const TextStyle(
              color: _varMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valeur,
            style: TextStyle(
              color: couleur,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(
              color: _varMuted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointExigence extends StatelessWidget {
  const _PointExigence({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: const BoxDecoration(
              color: _varPrimary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(
                color: _varMuted,
                fontSize: 12.3,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
