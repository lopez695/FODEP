import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/dashboard_models.dart';
import '../widgets/dashboard_design.dart';

/// Saisie d'un exercice ANTÉRIEUR des fonds propres.
///
/// Distinct du formulaire « Mettre à jour » de la carte, qui ne touche que
/// l'exercice en cours — mais bâti sur le même habillage : trois colonnes par
/// tier, mêmes champs, mêmes boutons. Ce qui change d'un formulaire à l'autre,
/// c'est l'exercice visé, pas la façon de saisir.
///
/// L'historique n'est pas une commodité : les limites des EP36 à EP38 se
/// mesurent, dit le formulaire prudentiel, sur les fonds propres de l'exercice
/// PRÉCÉDENT.
class FondsPropresExerciceDialog extends StatefulWidget {
  const FondsPropresExerciceDialog({
    super.key,
    required this.api,
    this.initial,
    this.anneesPrises = const [],
    this.exerciceEnCours,
  });

  final RwaApiService api;

  /// L'exercice à corriger, ou `null` pour en ouvrir un nouveau.
  final FondsPropresExercice? initial;

  /// Les millésimes déjà enregistrés : en ouvrir un qui existe déjà
  /// l'écraserait sans le dire.
  final List<int> anneesPrises;

  /// L'exercice déclaré. Viser celui-là depuis ce formulaire n'est pas
  /// interdit — c'est parfois voulu — mais ce n'est pas son objet, et
  /// l'écraser par mégarde s'est déjà produit. Le formulaire le dit.
  final int? exerciceEnCours;

  static Future<bool> ouvrir(
    BuildContext context,
    RwaApiService api, {
    FondsPropresExercice? initial,
    List<int> anneesPrises = const [],
    int? exerciceEnCours,
  }) async {
    final enregistre = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: FondsPropresExerciceDialog(
          api: api,
          initial: initial,
          anneesPrises: anneesPrises,
          exerciceEnCours: exerciceEnCours,
        ),
      ),
    );
    return enregistre ?? false;
  }

  @override
  State<FondsPropresExerciceDialog> createState() =>
      _FondsPropresExerciceDialogState();
}

class _FondsPropresExerciceDialogState
    extends State<FondsPropresExerciceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _annee;
  late final Map<String, TextEditingController> _postes;
  bool _enregistrement = false;
  String? _erreur;

  // Les onze postes saisis, dans l'ordre du formulaire prudentiel.
  static const _cet1 = <(String, String)>[
    ('capital_ordinaire', 'Capital ordinaire'),
    ('reserves', 'Réserves'),
    ('resultats_report', 'Résultats en report'),
    ('resultat_eligible', 'Résultat éligible'),
    ('deductions_prud_cet1', 'Réduction prudentielle'),
  ];
  static const _at1 = <(String, String)>[
    ('instruments_at1', 'Instruments additionnels'),
    ('primes_emission_at1', 'Primes d\'émission'),
    ('deductions_prud_at1', 'Réduction prudentielle'),
  ];
  static const _t2 = <(String, String)>[
    ('dettes_subordonnees_t2', 'Dettes subordonnées'),
    ('provisions_generales_t2', 'Provisions générales'),
    ('deductions_prud_t2', 'Réduction prudentielle'),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _annee = TextEditingController(
      text: '${initial?.exercice ?? _anneeLibre()}',
    );
    double v(double Function(FondsPropresExercice) lire) =>
        initial == null ? 0.0 : lire(initial);
    _postes = {
      'capital_ordinaire': _ctrl(v((e) => e.capitalOrdinaire)),
      'reserves': _ctrl(v((e) => e.reserves)),
      'resultats_report': _ctrl(v((e) => e.resultatsReport)),
      'resultat_eligible': _ctrl(v((e) => e.resultatEligible)),
      'deductions_prud_cet1': _ctrl(v((e) => e.deductionsPrudCet1)),
      'instruments_at1': _ctrl(v((e) => e.instrumentsAt1)),
      'primes_emission_at1': _ctrl(v((e) => e.primesEmissionAt1)),
      'deductions_prud_at1': _ctrl(v((e) => e.deductionsPrudAt1)),
      'dettes_subordonnees_t2': _ctrl(v((e) => e.dettesSubordonneesT2)),
      'provisions_generales_t2': _ctrl(v((e) => e.provisionsGeneralesT2)),
      'deductions_prud_t2': _ctrl(v((e) => e.deductionsPrudT2)),
    };
    // Les totaux se recalculent à la frappe, comme sur « Mettre à jour ».
    for (final c in _postes.values) {
      c.addListener(() => setState(() {}));
    }
  }

  /// Le millésime le plus récent encore libre, en descendant : c'est celui
  /// qu'on vient compléter neuf fois sur dix.
  int _anneeLibre() {
    var annee = widget.anneesPrises.isEmpty
        ? DateTime.now().year - 1
        : widget.anneesPrises.reduce((a, b) => a < b ? a : b) - 1;
    while (widget.anneesPrises.contains(annee)) {
      annee--;
    }
    return annee;
  }

  TextEditingController _ctrl(double valeur) => TextEditingController(
        text: valeur == 0 ? '' : valeur.toStringAsFixed(0),
      );

  @override
  void dispose() {
    _annee.dispose();
    for (final c in _postes.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Vrai quand l'année saisie est celle de l'exercice déclaré.
  bool get _viseExerciceEnCours {
    final annee = int.tryParse(_annee.text.trim());
    return annee != null && annee == widget.exerciceEnCours;
  }

  double _lire(String cle) =>
      double.tryParse(_postes[cle]!.text.trim().replaceAll(' ', '')) ?? 0.0;

  // Les mêmes agrégats que le serveur : un total négatif retombe à zéro.
  double get _totalCet1 => (_lire('capital_ordinaire') +
          _lire('reserves') +
          _lire('resultats_report') +
          _lire('resultat_eligible') -
          _lire('deductions_prud_cet1').abs())
      .clamp(0.0, double.infinity);
  double get _totalAt1 => (_lire('instruments_at1') +
          _lire('primes_emission_at1') -
          _lire('deductions_prud_at1').abs())
      .clamp(0.0, double.infinity);
  double get _totalT2 => (_lire('dettes_subordonnees_t2') +
          _lire('provisions_generales_t2') -
          _lire('deductions_prud_t2').abs())
      .clamp(0.0, double.infinity);

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await widget.api.updateFondsPropres(FondsPropresUpdate(
        exercice: int.parse(_annee.text.trim()),
        capitalOrdinaire: _lire('capital_ordinaire'),
        reserves: _lire('reserves'),
        resultatsReport: _lire('resultats_report'),
        resultatEligible: _lire('resultat_eligible'),
        deductionsPrudCet1: _lire('deductions_prud_cet1'),
        instrumentsAt1: _lire('instruments_at1'),
        primesEmissionAt1: _lire('primes_emission_at1'),
        deductionsPrudAt1: _lire('deductions_prud_at1'),
        dettesSubordonneesT2: _lire('dettes_subordonnees_t2'),
        provisionsGeneralesT2: _lire('provisions_generales_t2'),
        deductionsPrudT2: _lire('deductions_prud_t2'),
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enregistrement = false;
          _erreur = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final correction = widget.initial != null;
    final largeurEcran = MediaQuery.of(context).size.width;
    final largeur = largeurEcran > 1200
        ? 1080.0
        : (largeurEcran > 1000
            ? 960.0
            : (largeurEcran > 800 ? 780.0 : largeurEcran * 0.95));

    return Container(
      width: largeur,
      constraints: const BoxConstraints(maxHeight: 800),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      // Le formulaire englobe tout, champ d'annee compris : `validate()` doit
      // le couvrir, sinon une annee invalide ou deja prise partirait sans un
      // mot.
      child: Form(
        key: _formKey,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  correction
                      ? '${'Exercice'.tr(context)} ${widget.initial!.exercice}'
                      : 'Ajouter un exercice antérieur'.tr(context),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, color: c.ink),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _enregistrement
                    ? null
                    : () => Navigator.of(context).pop(false),
                color: c.muted,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Devise de saisie :'.tr(context),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.muted)),
              const SizedBox(width: 8),
              Text('FCFA (XOF)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.ink)),
              const SizedBox(width: 24),
              Text('Exercice :'.tr(context),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.muted)),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                height: 34,
                child: TextFormField(
                  controller: _annee,
                  enabled: !correction,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.ink),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '2025',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final annee = int.tryParse((v ?? '').trim());
                    if (annee == null || annee < 2000 || annee > 2100) {
                      return 'Année invalide'.tr(context);
                    }
                    if (!correction && widget.anneesPrises.contains(annee)) {
                      return 'Cet exercice est déjà enregistré'.tr(context);
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_viseExerciceEnCours)
            _bandeau(
              const Color(0xFFFEF3C7),
              const Color(0xFFF59E0B),
              const Color(0xFF92400E),
              Icons.warning_amber_rounded,
              'Cet exercice est celui qui est déclaré. Enregistrer remplacera '
                  'les fonds propres en cours, pas une ligne d\'historique.',
            )
          else
            _bandeau(
              isDark ? const Color(0xFF13203A) : const Color(0xFFEEF2FF),
              isDark ? const Color(0xFF1E3A5F) : const Color(0xFFC7D2FE),
              isDark ? const Color(0xFF93C5FD) : const Color(0xFF4338CA),
              Icons.history_toggle_off_outlined,
              'Ce formulaire ne touche pas les fonds propres de l\'exercice '
                  'en cours, qui se saisissent depuis « Mettre à jour ».',
            ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _colonne(
                        c,
                        isDark,
                        'CET1',
                        'Fonds propres de base de catégorie 1',
                        const Color(0xFF1E40AF),
                        _cet1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _colonne(
                        c,
                        isDark,
                        'AT1',
                        'Fonds propres additionnels de catégorie 1',
                        const Color(0xFF1E3A8A),
                        _at1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _colonne(
                        c,
                        isDark,
                        'TIER 2',
                        'Capital complémentaire',
                        const Color(0xFF475569),
                        _t2,
                      ),
                    ),
                  ],
                ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border, width: Dash.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _total(c, 'Total CET1', _totalCet1, const Color(0xFF1E40AF)),
                _total(c, 'Total AT1', _totalAt1, const Color(0xFF1E3A8A)),
                _total(c, 'Total Tier 2', _totalT2, const Color(0xFF475569)),
                Container(width: 1, height: 28, color: c.divider),
                _total(c, 'Fonds Propres Globaux',
                    _totalCet1 + _totalAt1 + _totalT2,
                    const Color(0xFF10B981),
                    fort: true),
              ],
            ),
          ),
          if (_erreur != null) ...[
            const SizedBox(height: 12),
            Text(_erreur!,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFDC2626))),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _enregistrement
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: c.ink,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: Text('Annuler'.tr(context)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _enregistrement ? null : _enregistrer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sidebar,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                child: _enregistrement
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Enregistrer'.tr(context)),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _bandeau(Color fond, Color bord, Color encre, IconData icone,
      String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bord),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 15, color: encre),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message.tr(context),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500, color: encre)),
          ),
        ],
      ),
    );
  }

  /// Une colonne par tier, comme sur « Mettre à jour » : barre de couleur en
  /// tête, titre, sous-titre, puis les champs sous un filet.
  Widget _colonne(DashColors c, bool isDark, String titre, String sousTitre,
      Color couleur, List<(String, String)> postes) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: couleur),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(sousTitre.tr(context),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B))),
              ],
            ),
          ),
          Divider(
              height: 1,
              thickness: 0.5,
              color:
                  isDark ? const Color(0x1F94A3B8) : const Color(0x1F64748B)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (final (cle, libelle) in postes)
                  _champ(libelle, _postes[cle]!, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _champ(String libelle, TextEditingController ctrl, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1F94A3B8) : const Color(0x1F64748B),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(libelle.tr(context),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569))),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 7,
            child: SizedBox(
              height: 32,
              child: TextFormField(
                controller: ctrl,
                textAlign: TextAlign.right,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s-]')),
                ],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '0',
                  hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _total(DashColors c, String libelle, double valeur, Color couleur,
      {bool fort = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(libelle.tr(context),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: c.muted)),
        const SizedBox(height: 2),
        Text(
          valeur == 0 ? '—' : valeur.toStringAsFixed(0),
          style: TextStyle(
              fontSize: fort ? 15 : 13.5,
              fontWeight: FontWeight.w800,
              color: couleur),
        ),
      ],
    );
  }
}
