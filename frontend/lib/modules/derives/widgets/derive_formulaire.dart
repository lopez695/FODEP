import 'package:flutter/material.dart';

import '../models/derive_models.dart';

/// Saisie d'un contrat dérivé.
///
/// Le formulaire ne demande que ce que l'EP11 réclame : la nature du
/// sous-jacent et l'échéance décident de la ligne, la catégorie de la
/// contrepartie décide de la colonne, le notionnel et le coût de remplacement
/// portent les montants. Le type de contrat n'est là que pour reconnaître sa
/// propre saisie — le formulaire ne le demande pas.
///
/// L'échéance est saisie, jamais la tranche de durée : celle-ci se déduit et
/// change avec le temps. La figer à la saisie ferait vieillir la déclaration
/// sans qu'on le voie.
class DeriveFormulaire extends StatefulWidget {
  const DeriveFormulaire({super.key, this.derive});

  final Derive? derive;

  static Future<Derive?> show(BuildContext context, [Derive? derive]) {
    return showDialog<Derive>(
      context: context,
      builder: (_) => DeriveFormulaire(derive: derive),
    );
  }

  @override
  State<DeriveFormulaire> createState() => _DeriveFormulaireState();
}

class _DeriveFormulaireState extends State<DeriveFormulaire> {
  final _cle = GlobalKey<FormState>();

  late final TextEditingController _contrepartie;
  late final TextEditingController _typeContrat;
  late final TextEditingController _devise;
  late final TextEditingController _notionnel;
  late final TextEditingController _coutRemplacement;
  late final TextEditingController _commentaire;

  late NatureDerive _nature;
  late CategorieContrepartieDerive _categorie;
  late DateTime _echeance;
  DateTime? _conclusion;

  @override
  void initState() {
    super.initState();
    final existant = widget.derive;
    _contrepartie = TextEditingController(text: existant?.contrepartie ?? '');
    _typeContrat = TextEditingController(text: existant?.typeContrat ?? '');
    _devise = TextEditingController(text: existant?.devise ?? 'XOF');
    _notionnel = TextEditingController(
        text: existant == null ? '' : _texte(existant.montantNotionnel));
    _coutRemplacement = TextEditingController(
        text: existant == null ? '' : _texte(existant.coutRemplacement));
    _commentaire = TextEditingController(text: existant?.commentaire ?? '');
    _nature = existant?.nature ?? NatureDerive.taux;
    _categorie = existant?.categorieContrepartie ??
        CategorieContrepartieDerive.institutionsFinancieres;
    _echeance = existant?.dateEcheance ??
        DateTime.now().add(const Duration(days: 365));
    _conclusion = existant?.dateConclusion;
  }

  static String _texte(double valeur) =>
      valeur == valeur.roundToDouble() ? valeur.toStringAsFixed(0) : '$valeur';

  @override
  void dispose() {
    _contrepartie.dispose();
    _typeContrat.dispose();
    _devise.dispose();
    _notionnel.dispose();
    _coutRemplacement.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  double _nombre(TextEditingController controleur) {
    final texte = controleur.text.trim().replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(texte) ?? 0.0;
  }

  Future<void> _choisirDate({required bool echeance}) async {
    final initiale = echeance ? _echeance : (_conclusion ?? DateTime.now());
    final choisie = await showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (choisie == null) return;
    setState(() {
      if (echeance) {
        _echeance = choisie;
      } else {
        _conclusion = choisie;
      }
    });
  }

  void _valider() {
    if (!(_cle.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      Derive(
        id: widget.derive?.id,
        contrepartie: _contrepartie.text.trim(),
        categorieContrepartie: _categorie,
        nature: _nature,
        typeContrat:
            _typeContrat.text.trim().isEmpty ? null : _typeContrat.text.trim(),
        devise: _devise.text.trim().toUpperCase(),
        montantNotionnel: _nombre(_notionnel),
        coutRemplacement: _nombre(_coutRemplacement),
        dateConclusion: _conclusion,
        dateEcheance: _echeance,
        commentaire:
            _commentaire.text.trim().isEmpty ? null : _commentaire.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.derive == null
          ? 'Ajouter un contrat dérivé'
          : 'Modifier le contrat'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _cle,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _contrepartie,
                  decoration: const InputDecoration(
                    labelText: 'Contrepartie',
                    helperText: 'La banque ou l\'entreprise avec qui le '
                        'contrat est conclu.',
                  ),
                  validator: (valeur) => (valeur ?? '').trim().isEmpty
                      ? 'La contrepartie est obligatoire.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CategorieContrepartieDerive>(
                  initialValue: _categorie,
                  // Sans cela, l'element prend sa largeur naturelle et
                  // « Organismes publics hors administration centrale »
                  // deborde du menu.
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie de la contrepartie',
                    helperText: 'Décide de la colonne de ventilation de '
                        'l\'EP11.',
                  ),
                  items: [
                    for (final categorie in CategorieContrepartieDerive.values)
                      DropdownMenuItem(
                        value: categorie,
                        child: Text(categorie.label,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (valeur) => setState(
                      () => _categorie = valeur ?? _categorie),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<NatureDerive>(
                  initialValue: _nature,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Nature du sous-jacent',
                    helperText: 'Décide du bloc de l\'EP11, et donc de la '
                        'pondération appliquée au notionnel.',
                  ),
                  items: [
                    for (final nature in NatureDerive.values)
                      DropdownMenuItem(
                        value: nature,
                        child:
                            Text(nature.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (valeur) =>
                      setState(() => _nature = valeur ?? _nature),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _typeContrat,
                  decoration: const InputDecoration(
                    labelText: 'Type de contrat (facultatif)',
                    hintText: 'Swap de taux, change à terme, option…',
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _notionnel,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant notionnel',
                        helperText: 'Colonne (b) de l\'EP11.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _devise,
                      decoration: const InputDecoration(labelText: 'Devise'),
                      validator: (valeur) =>
                          (valeur ?? '').trim().length == 3
                              ? null
                              : 'Trois lettres.',
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _coutRemplacement,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Coût de remplacement',
                    helperText: 'Colonne (a) : la valeur de marché du contrat '
                        'quand elle est en faveur de l\'établissement. Zéro '
                        'sinon.',
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _champDate(
                      libelle: 'Échéance',
                      valeur: _echeance,
                      aide: 'Décide de la tranche de durée résiduelle.',
                      onTap: () => _choisirDate(echeance: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _champDate(
                      libelle: 'Conclusion (facultatif)',
                      valeur: _conclusion,
                      aide: null,
                      onTap: () => _choisirDate(echeance: false),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commentaire,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Commentaire (facultatif)'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _valider, child: const Text('Enregistrer')),
      ],
    );
  }

  Widget _champDate({
    required String libelle,
    required DateTime? valeur,
    required String? aide,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: libelle,
          helperText: aide,
          helperMaxLines: 2,
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
        ),
        child: Text(valeur == null
            ? '—'
            : '${valeur.day.toString().padLeft(2, '0')}/'
                '${valeur.month.toString().padLeft(2, '0')}/${valeur.year}'),
      ),
    );
  }
}
