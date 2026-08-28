// Ce que l'écran « Capital réglementaire » montre du socle Pilier 1.
//
// Trois choses s'y jouent, et chacune s'est déjà perdue ailleurs dans l'outil.
//
// Les DEUX seuils : le minimum du Titre III et ce minimum augmenté du coussin
// de conservation. N'afficher que le premier ferait état d'une marge que
// l'EP01 de la déclaration ne reconnaît pas — c'est lui qui mesure contre
// 11,5 %.
//
// Le DÉFICIT : quand les fonds propres ne couvrent pas l'exigence globale,
// l'écran doit le nommer, pas afficher un écart négatif au milieu d'autres
// chiffres.
//
// Et l'analyse de l'EP01 qui ne DÉMARRE PAS toute seule : elle renseigne le
// classeur entier avant de le relire. La déclencher au chargement rendrait la
// page inutilisable le temps du calcul.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/modules/dashboard/models/dashboard_models.dart';
import 'package:rwa_calculator/modules/icaap/models/icaap_models.dart';
import 'package:rwa_calculator/modules/icaap/screens/capital_reglementaire_screen.dart';
import 'package:rwa_calculator/modules/rapports/models/report_models.dart';

const FondsPropresDetail _fondsPropres = FondsPropresDetail(
  capitalOrdinaire: 0,
  reserves: 0,
  resultatsReport: 0,
  resultatEligible: 0,
  deductionsPrudCet1: 0,
  cet1: 87000,
  instrumentsAt1: 0,
  primesEmissionAt1: 0,
  deductionsPrudAt1: 0,
  at1: 0,
  tier1: 87000,
  dettesSubordonneesT2: 0,
  provisionsGeneralesT2: 0,
  deductionsPrudT2: 0,
  tier2: 20000,
  totalFp: 107000,
  exercice: 2026,
);

CapitalReglementaire _socle({
  double marge = -10000,
  List<String> avertissements = const [],
}) {
  return CapitalReglementaire(
    cycle: const CycleIcaap(exercice: 2026),
    fondsPropres: _fondsPropres,
    exigences: const [
      ExigenceRisque(
        code: 'credit',
        libelle: 'Risque de crédit',
        apr: 800000,
        exigence: 64000,
        part: 80.0,
        anglePilier2: 'Concentration, risque résiduel.',
      ),
      ExigenceRisque(
        code: 'marche',
        libelle: 'Risque de marché',
        apr: 200000,
        exigence: 16000,
        part: 20.0,
        anglePilier2: 'Positions hors Pilier 1.',
      ),
    ],
    aprTotal: 1000000,
    exigenceTotale: 80000,
    ratios: const [
      NiveauRatio(
        code: 'solvabilite',
        libelle: 'Ratio de solvabilité total',
        observe: 10.7,
        minimum: 9.0,
        exigenceAvecCoussin: 11.5,
        ecartMinimum: 1.7,
        ecartAvecCoussin: -0.8,
        situation: situationSousCoussin,
        fondsPropresRequis: 115000,
      ),
      NiveauRatio(
        code: 'levier',
        libelle: 'Ratio de levier',
        observe: 8.8,
        minimum: 3.0,
        exigenceAvecCoussin: 3.0,
        ecartMinimum: 5.8,
        ecartAvecCoussin: 5.8,
        situation: situationRespectee,
        fondsPropresRequis: 31000,
      ),
    ],
    exigenceGlobale: ExigenceGlobale(
      aprTotal: 1000000,
      minimumSolvabilite: 9.0,
      coussinConservation: 2.5,
      coussinContracyclique: 0.0,
      coussinSystemique: 0.0,
      exigenceGlobale: 11.5,
      fondsPropresRequis: 115000,
      fondsPropresDisponibles: 105000,
      marge: marge,
    ),
    assietteLevier: 1057000,
    avertissements: avertissements,
  );
}

/// Sert un socle figé, et compte les analyses EP01 demandées.
class _ApiFictive extends RwaApiService {
  _ApiFictive(this._reponse) : super(baseUrl: 'http://127.0.0.1:1');

  final CapitalReglementaire _reponse;
  int analysesDemandees = 0;

  @override
  Future<CapitalReglementaire> fetchIcaapCapitalReglementaire() async =>
      _reponse;

  @override
  Future<AnalyseDeclaration> fetchAnalyseFodepCourante() async {
    analysesDemandees += 1;
    return const AnalyseDeclaration(
      nomFichier: 'Declaration en cours',
      pages: 0,
      normes: [],
      controles: [],
      inventaire: [],
      classeur: true,
      avertissements: [],
      reserves: [],
    );
  }
}

Future<void> _afficher(WidgetTester tester, _ApiFictive api) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: CapitalReglementaireScreen(api: api)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('les deux seuils du ratio de solvabilité sont montrés',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _afficher(tester, _ApiFictive(_socle()));

    expect(find.text('9,00 %'), findsWidgets, reason: 'le minimum du Titre III');
    expect(find.text('11,50 %'), findsWidgets,
        reason: 'le minimum augmenté du coussin, celui que l\'EP01 mesure');
  });

  testWidgets('un coussin entamé n\'est pas annoncé comme respecté',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _afficher(tester, _ApiFictive(_socle()));

    expect(find.text('Coussin entamé'), findsOneWidget);
  });

  testWidgets('un manque de fonds propres se nomme déficit', (tester) async {
    tester.view.physicalSize = const Size(1800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _afficher(tester, _ApiFictive(_socle(marge: -10000)));

    expect(find.text('Déficit'), findsOneWidget);
  });

  testWidgets('un excédent ne se nomme pas déficit', (tester) async {
    tester.view.physicalSize = const Size(1800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _afficher(tester, _ApiFictive(_socle(marge: 4000)));

    expect(find.text('Déficit'), findsNothing);
    expect(find.text("Matelas au-delà de l'exigence"), findsOneWidget);
  });

  testWidgets('une brique absente est signalée, pas affichée en zéro',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _afficher(
      tester,
      _ApiFictive(_socle(avertissements: const [
        'Risque opérationnel non calculé : renseignez le PNB.',
      ])),
    );

    expect(find.text('Données incomplètes'), findsOneWidget);
    expect(
      find.text('• Risque opérationnel non calculé : renseignez le PNB.'),
      findsOneWidget,
    );
  });

  testWidgets('l\'analyse de l\'EP01 attend qu\'on la demande', (tester) async {
    tester.view.physicalSize = const Size(1800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _ApiFictive(_socle());
    await _afficher(tester, api);

    expect(api.analysesDemandees, 0,
        reason: 'renseigner le classeur entier au chargement fige la page');

    await tester.tap(find.text('Confronter aux onze normes'));
    await tester.pumpAndSettle();

    expect(api.analysesDemandees, 1);
  });
}
