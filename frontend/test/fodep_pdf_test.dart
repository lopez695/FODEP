// Le PDF du FODEP reproduit le classeur : ses lignes, ses colonnes à leur
// largeur, ses fusions. Pas de page de garde, pas de bandeaux, pas d'encadrés :
// ce qui ne figure pas dans le formulaire n'a pas à figurer dans son impression.
//
// Ces cas reproduisent les formes qui ont fait échouer les versions
// précédentes : un titre fusionné de cent trente caractères, un état à quatorze
// colonnes, une quarantaine d'états. Le générateur paginait alors sans fin, ou
// forçait une hauteur infinie.
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/rapports/models/report_models.dart';
import 'package:rwa_calculator/modules/reporting_global/services/fodep_pdf.dart';

/// Titre d'état tel que le formulaire l'écrit : une cellule fusionnée sur toute
/// la largeur, très longue.
const _titreInterminable =
    'DISPOSITIONS TRANSITOIRES SUR BASE INDIVIDUELLE : RECLASSEMENT ET '
    'RETRAIT PROGRESSIF DES ELEMENTS DE FONDS PROPRES NON ADMISSIBLES';

ContenuFodep _contenu(List<EtatFodep> etats) => ContenuFodep(
      nomFichier: 'FODEP_30062026.xlsx',
      dateArrete: DateTime(2026, 6, 30),
      anomalies: const ['EP01 : normes déclarées à 0 %, donc « CONFORME ».'],
      etats: etats,
    );

LigneFodep _ligne(List<CelluleFodep> cellules) => LigneFodep(cellules: cellules);

CelluleFodep _c(
  String texte, {
  bool gras = false,
  bool droite = false,
  int colonnes = 1,
}) =>
    CelluleFodep(
      texte: texte,
      gras: gras,
      droite: droite,
      colonnes: colonnes,
    );

Future<void> _rend(ContenuFodep contenu) async {
  final pdf = await construireFodepPdf(contenu: contenu);
  expect(String.fromCharCodes(pdf.take(4)), '%PDF',
      reason: 'Le document produit doit être un PDF.');
  expect(pdf.length, greaterThan(1000));
}

void main() {
  // Le générateur charge les polices de l'application : sans binding,
  // rootBundle n'existe pas et le document retomberait sur une police sans
  // Unicode, qui ne sait pas dessiner les apostrophes du formulaire.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un état ordinaire se rend', () async {
    await _rend(_contenu([
      EtatFodep(
        nom: 'EP03',
        largeurs: const [11.0, 10.0, 8.43, 23.18],
        lignes: [
          _ligne([
            _c('CALCUL DES FONDS PROPRES SUR BASE INDIVIDUELLE',
                gras: true, colonnes: 3),
            _c('EP03', gras: true, droite: true),
          ]),
          _ligne([
            _c('Code DISPRU', gras: true),
            _c('Poste', gras: true, colonnes: 2),
            _c('Montant', gras: true),
          ]),
          _ligne([
            _c(''),
            _c('A. Fonds propres de base durs (CET 1)', gras: true, colonnes: 3),
          ]),
          _ligne([
            _c('FPI01'),
            _c('Capital social libéré', colonnes: 2),
            _c('49 323', droite: true),
          ]),
        ],
      ),
    ]));
  });

  test('un titre fusionné plus large que sa colonne ne bloque pas la mise en '
      'page', () async {
    await _rend(_contenu([
      EtatFodep(
        nom: 'EP04',
        largeurs: const [11.0, 40.0, 13.0, 15.0],
        lignes: [
          _ligne([_c(_titreInterminable, gras: true, colonnes: 3), _c('EP04')]),
          _ligne([
            _c('Code DISPRU', gras: true),
            _c('Poste', gras: true),
            _c('Montant', gras: true),
            _c('Formules', gras: true),
          ]),
          _ligne([
            _c('DT001'),
            _c('Taux de retrait des éléments non admissibles'),
            _c('0,9000', droite: true),
            _c('(a)'),
          ]),
        ],
      ),
    ]));
  });

  test('un état large se rend sans déborder', () async {
    await _rend(_contenu([
      EtatFodep(
        nom: 'EP39',
        largeurs: List<double>.filled(14, 9.0),
        lignes: [
          for (var ligne = 0; ligne < 40; ligne++)
            _ligne([
              _c('PA${ligne.toString().padLeft(3, '0')}'),
              _c('Poste $ligne — intitulé assez long pour se replier'),
              for (var colonne = 2; colonne < 14; colonne++)
                _c('1 234 567', droite: true),
            ]),
        ],
      ),
    ]));
  });

  test('la déclaration entière se rend, un état par page', () async {
    // Une quarantaine d'états, comme le formulaire réel : c'est le volume qui
    // avait fait sauter le plafond de pages du générateur.
    await _rend(_contenu([
      for (var etat = 1; etat <= 44; etat++)
        EtatFodep(
          nom: 'EP${etat.toString().padLeft(2, '0')}',
          largeurs: const [11.0, 30.0, 14.0],
          lignes: [
            _ligne([_c('ETAT NUMERO $etat', gras: true, colonnes: 3)]),
            for (var ligne = 0; ligne < 30; ligne++)
              _ligne([
                _c('RA${ligne.toString().padLeft(3, '0')}'),
                _c('Norme prudentielle numéro $ligne'),
                _c('0,1234', droite: true),
              ]),
          ],
        ),
    ]));
  });

  test('une cellule de formule reste vide, sans casser la ligne', () async {
    // Le backend vide les cases calculées par le formulaire : leur valeur
    // n'existe qu'à l'ouverture du classeur. La ligne doit rester complète.
    await _rend(_contenu([
      EtatFodep(
        nom: 'EP01',
        largeurs: const [11.0, 30.0, 14.0, 18.0],
        lignes: [
          _ligne([
            _c('RA001'),
            _c('Ratio CET1'),
            _c('0,1230', droite: true),
            _c(''),
          ]),
        ],
      ),
    ]));
  });

  test('un contenu sans état produit tout de même un fichier lisible', () async {
    await _rend(_contenu(const []));
  });

  test('un état sans largeurs déclarées se rend quand même', () async {
    // Une feuille dont aucune colonne n'est dimensionnée : les cellules doivent
    // se partager la page au lieu de disparaître.
    await _rend(_contenu([
      EtatFodep(
        nom: 'EP3M',
        lignes: [
          _ligne([_c('IM011'), _c('Immobilisations incorporelles'), _c('0')]),
        ],
      ),
    ]));
  });
}
