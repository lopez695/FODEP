// L'écran de résultat d'une analyse de déclaration.
//
// Ce qui doit se lire sans effort : combien de normes sont dépassées, et
// lesquelles. Le sens de chaque norme y figure aussi — un niveau observé ne se
// juge pas sans savoir s'il est plafonné ou planchérisé.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/rapports/models/report_models.dart';
import 'package:rwa_calculator/modules/rapports/screens/analyse_declaration_page.dart';

NormeAnalysee _norme(
  String code, {
  required double seuil,
  double? observe,
  required bool minimum,
  required SituationNorme situation,
  double? ecart,
  String libelle = 'Norme prudentielle',
  String reference = 'EP02',
}) =>
    NormeAnalysee(
      code: code,
      libelle: libelle,
      reference: reference,
      seuil: seuil,
      observe: observe,
      minimum: minimum,
      situation: situation,
      ecart: ecart,
    );

Future<void> _poser(WidgetTester tester, AnalyseDeclaration analyse) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AnalyseDeclarationPage(analyse: analyse),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('une déclaration conforme l\'annonce', (tester) async {
    await _poser(
      tester,
      AnalyseDeclaration(
        nomFichier: 'FODEP_30062026.pdf',
        pages: 59,
        normes: [
          _norme('RA001',
              seuil: 0.075,
              observe: 0.123,
              minimum: true,
              situation: SituationNorme.respectee,
              ecart: 0.048,
              libelle: 'Ratio de fonds propres CET 1 (%)'),
          _norme('RA006',
              seuil: 0.25,
              observe: 0.225,
              minimum: false,
              situation: SituationNorme.respectee,
              ecart: 0.025,
              reference: 'EP35'),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Les 2 normes sont respectées'), findsOneWidget);
    // L'origine est annoncée : une impression, avec son nombre de pages.
    expect(
      find.text('FODEP_30062026.pdf · impression, 59 page(s) · '
          '2 norme(s) trouvée(s)'),
      findsOneWidget,
    );
    // Les contrôles de cohérence demandent le classeur : la section le dit
    // plutôt que de rester vide sans explication.
    expect(find.text('Cohérence interne'), findsOneWidget);
    expect(find.textContaining('demandent le classeur'), findsOneWidget);

    // Le sens de la norme est affiché : il décide de la conformité.
    expect(find.text('plancher'), findsOneWidget);
    expect(find.text('plafond'), findsOneWidget);

    // Seuils et niveaux observés, en points de pourcentage.
    expect(find.text('7.50 %'), findsOneWidget);
    expect(find.text('12.30 %'), findsOneWidget);
  });

  testWidgets('un dépassement passe devant tout le reste', (tester) async {
    await _poser(
      tester,
      AnalyseDeclaration(
        nomFichier: 'declaration.pdf',
        pages: 60,
        normes: [
          // Un plafond franchi et une norme non mesurée : c'est le dépassement
          // qui doit s'annoncer, parce que c'est lui qui se corrige.
          _norme('RA006',
              seuil: 0.25,
              observe: 0.31,
              minimum: false,
              situation: SituationNorme.depassee,
              ecart: -0.06,
              reference: 'EP35'),
          _norme('RA004',
              seuil: 0.25,
              minimum: false,
              situation: SituationNorme.nonMesuree,
              reference: 'EP29'),
        ],
        avertissements: const [
          'Niveau observe absent pour RA004 : la case est calculee par le '
              'formulaire.',
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Une norme est dépassée'), findsOneWidget);
    expect(find.text('Dépassée'), findsOneWidget);
    expect(find.text('Non mesurée'), findsOneWidget);
    // Sans niveau observé, la colonne reste vide plutôt que d'afficher un zéro.
    expect(find.text('—'), findsWidgets);
    expect(find.textContaining('la case est calculee'), findsOneWidget);
  });

  testWidgets('la lecture d\'un classeur porte ses contrôles et sa carte',
      (tester) async {
    await _poser(
      tester,
      AnalyseDeclaration(
        nomFichier: 'FODEP_30062026.xlsx',
        pages: 0,
        classeur: true,
        normes: [
          _norme('RA001',
              seuil: 0.075,
              observe: 0.123,
              minimum: true,
              situation: SituationNorme.respectee,
              ecart: 0.048),
        ],
        controles: const [
          // Un écart d'une unité sur dix-sept lignes arrondies : la tolérance
          // arithmétique le couvre, ce n'est pas une erreur de somme.
          ControleCoherence(
            etat: 'EP20',
            libelle: 'TOTAL EXPOSITIONS SUR LES AUTRES ACTIFS',
            colonne: 'Actifs pondérés',
            attendu: 57624,
            constate: 57625,
            ecart: 1,
            tolerance: 8.5,
            statut: StatutControle.arrondi,
          ),
          // Celui-ci dépasse la tolérance : le total contredit ses lignes.
          ControleCoherence(
            etat: 'EP34',
            libelle: 'TOTAL DES PARTICIPATIONS',
            colonne: 'Libéré net',
            attendu: 8500,
            constate: 9200,
            ecart: 700,
            tolerance: 2.5,
            statut: StatutControle.ecart,
          ),
        ],
        inventaire: const [
          EtatRenseigne(nom: 'EP01', lignes: 23, toutAZero: false),
          EtatRenseigne(nom: 'EP22', lignes: 12, toutAZero: true),
        ],
      ),
    );

    expect(tester.takeException(), isNull);

    // L'origine : le classeur est la pièce transmise, pas son impression.
    expect(find.textContaining('classeur — pièce transmise'), findsOneWidget);

    // Les trois volets de l'analyse.
    expect(find.text('Normes prudentielles'), findsOneWidget);
    expect(find.text('Cohérence interne'), findsOneWidget);
    expect(find.text('Carte de la déclaration'), findsOneWidget);

    // Un écart au-delà des arrondis se distingue d'un écart d'arrondi.
    expect(find.text('Arrondi'), findsOneWidget);
    expect(find.text('Écart'), findsWidgets);
    expect(find.text('57 624'), findsOneWidget);
    expect(find.text('700'), findsOneWidget);

    // La carte marque l'état qui ne porte que des zéros.
    expect(find.text('EP22'), findsOneWidget);
    expect(find.text('à zéro'), findsOneWidget);
  });

  testWidgets('un PDF sans norme lisible le dit', (tester) async {
    await _poser(
      tester,
      const AnalyseDeclaration(
        nomFichier: 'scan.pdf',
        pages: 12,
        avertissements: [
          'Ce PDF ne contient aucun texte : il s\'agit probablement d\'un scan.',
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('probablement d\'un scan'), findsOneWidget);
    expect(
      find.text('Aucune norme lisible dans ce document.'),
      findsOneWidget,
    );
  });
}
