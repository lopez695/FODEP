// Le registre des dérivés, et l'aperçu de l'EP11 qu'il alimente.
//
// L'écran montre les contrats saisis et, dessous, les quinze lignes du
// formulaire telles qu'elles partiront. C'est cette seconde table qui compte :
// une saisie ne se vérifie qu'en regardant la case où elle atterrit, et un
// contrat rangé sous la mauvaise nature ou la mauvaise durée ne se voit pas
// autrement.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/derives/models/derive_models.dart';
import 'package:rwa_calculator/modules/derives/widgets/derive_formulaire.dart';

void main() {
  group('le vocabulaire est celui du formulaire', () {
    test('les cinq natures sont les cinq blocs de l\'EP11', () {
      expect(NatureDerive.values.length, 5);
      expect(
        NatureDerive.values.map((n) => n.wire),
        containsAll(<String>[
          'taux',
          'change_or',
          'titres_propriete',
          'metaux_precieux',
          'autres_produits_de_base',
        ]),
      );
    });

    test('les cinq catégories sont les cinq colonnes de ventilation', () {
      // Ce sont les lettres de la nomenclature FODEP, pas des identifiants
      // choisis ici : les traduire ferait deux endroits où se tromper.
      expect(
        CategorieContrepartieDerive.values.map((c) => c.wire).toList(),
        <String>['a', 'b', 'c', 'd', 'e'],
      );
    });

    test('une valeur inconnue retombe sur un défaut plutôt que de planter', () {
      // Une nouvelle version du formulaire, ou un serveur plus récent, ne doit
      // pas faire échouer l'écran sur une chaîne inattendue.
      expect(NatureDerive.fromWire('cryptomonnaie'), NatureDerive.taux);
      expect(
        CategorieContrepartieDerive.fromWire('z'),
        CategorieContrepartieDerive.institutionsFinancieres,
      );
      expect(TrancheDuree.fromWire('un_siecle'), TrancheDuree.moins1An);
    });
  });

  group('le contrat fait l\'aller-retour avec le serveur', () {
    test('la charge utile porte les codes attendus par le backend', () {
      final contrat = Derive(
        contrepartie: 'BANQUE ATLANTIQUE',
        categorieContrepartie: CategorieContrepartieDerive.souverains,
        nature: NatureDerive.changeOr,
        devise: 'EUR',
        montantNotionnel: 1000,
        coutRemplacement: 250,
        dateEcheance: DateTime(2030, 6, 30),
      );

      final charge = contrat.toPayload();
      expect(charge['categorie_contrepartie'], 'a');
      expect(charge['nature'], 'change_or');
      // La date part en ISO, sans heure : le backend attend une date, et une
      // heure locale ferait basculer l'échéance d'un jour selon le fuseau.
      expect(charge['date_echeance'], '2030-06-30');
      expect(charge['date_conclusion'], isNull);
    });

    test('la tranche vient du serveur, elle ne se saisit pas', () {
      // Elle se déduit de l'échéance et change avec le temps : la figer à la
      // saisie ferait vieillir la déclaration sans qu'on le voie.
      final contrat = Derive.fromJson(const {
        'id': 1,
        'contrepartie': 'CITIBANK',
        'categorie_contrepartie': 'd',
        'nature': 'taux',
        'devise': 'XOF',
        'montant_notionnel': 10000,
        'cout_remplacement': 1000,
        'date_echeance': '2040-01-01',
        'tranche': 'plus_5_ans',
      });
      expect(contrat.tranche, TrancheDuree.plus5Ans);
      expect(contrat.toPayload().containsKey('tranche'), isFalse);
    });
  });

  group('l\'aperçu de l\'EP11', () {
    test('la ventilation retrouve l\'exposition de la ligne', () {
      final ligne = LigneEp11.fromJson(const {
        'code': 'RC051',
        'nature': 'taux',
        'tranche': 'plus_5_ans',
        'libelle': 'Instruments de taux — Durée > 5 ans',
        'nombre_contrats': 2,
        'cout_remplacement': 1000.0,
        'montant_notionnel': 10000.0,
        'ponderation': 0.015,
        'notionnel_pondere': 150.0,
        'exposition': 1150.0,
        'ventilation': {'a': 400.0, 'd': 750.0},
      });

      expect(ligne.notionnelPondere, closeTo(150.0, 0.001));
      expect(ligne.exposition, closeTo(1150.0, 0.001));
      expect(
        ligne.ventilation.values.reduce((a, b) => a + b),
        closeTo(ligne.exposition, 0.001),
      );
    });

    test('un registre vide se lit comme un zéro assumé', () {
      final synthese = SyntheseEp11.fromJson(const {
        'nombre': 0,
        'total_notionnel': 0.0,
        'total_cout_remplacement': 0.0,
        'total_exposition': 0.0,
        'lignes': <dynamic>[],
        'alertes': ['Le registre est vide : l\'EP11 partira à zéro.'],
      });
      expect(synthese.nombre, 0);
      expect(synthese.alertes, isNotEmpty);
    });
  });

  testWidgets('le formulaire refuse un contrat sans contrepartie',
      (tester) async {
    // Sans contrepartie, la ligne n'a pas de colonne de ventilation : elle
    // partirait dans l'EP11 sans qu'on sache où la ranger.
    Derive? rendu;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              rendu = await DeriveFormulaire.show(context);
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('La contrepartie est obligatoire.'), findsOneWidget);
    expect(rendu, isNull, reason: 'le formulaire ne doit pas se fermer');
  });

  testWidgets('un contrat saisi ressort avec sa nature et sa catégorie',
      (tester) async {
    Derive? rendu;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              rendu = await DeriveFormulaire.show(context);
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contrepartie'), 'CITIBANK');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Montant notionnel'), '10000000000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Coût de remplacement'), '1000000000');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(rendu, isNotNull);
    expect(rendu!.contrepartie, 'CITIBANK');
    expect(rendu!.montantNotionnel, 10000000000);
    expect(rendu!.coutRemplacement, 1000000000);
    // Les défauts du formulaire : le cas le plus courant, un swap de taux
    // avec une institution financière.
    expect(rendu!.nature, NatureDerive.taux);
    expect(rendu!.categorieContrepartie,
        CategorieContrepartieDerive.institutionsFinancieres);
  });
}
