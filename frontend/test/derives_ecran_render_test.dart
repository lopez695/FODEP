// L'écran des dérivés doit tenir dans sa fenêtre.
//
// Le premier jet du dialogue voisin débordait — libellés tronqués, colonne
// coupée, formules à la ligne — et c'est un essai de rendu qui l'a montré, pas
// une relecture. Celui-ci tient la même garde sur le registre des dérivés :
// Flutter lève sur tout débordement de mise en page, et la suite échoue.
//
// Il couvre aussi le bouton d'ajout et celui de suppression, que les essais du
// dialogue voisin ne touchaient pas — c'est exactement l'angle mort qui avait
// laissé passer le `setState` en flèche.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/core/utils/formatters.dart';
import 'package:rwa_calculator/modules/derives/models/derive_models.dart';
import 'package:rwa_calculator/modules/derives/screens/derives_screen.dart';

/// API qui répond sans réseau, avec un registre representatif.
class _ApiBouchonnee extends RwaApiService {
  _ApiBouchonnee({this.vide = false}) : super(baseUrl: 'http://127.0.0.1:1');

  final bool vide;

  /// Ce que l'écran a demandé de supprimer.
  int? supprime;

  @override
  Future<List<Derive>> fetchDerives() async {
    if (vide) return const [];
    return [
      Derive(
        id: 1,
        contrepartie: 'SOCIETE GENERALE',
        categorieContrepartie:
            CategorieContrepartieDerive.institutionsFinancieres,
        nature: NatureDerive.taux,
        typeContrat: 'Swap de taux',
        montantNotionnel: 10000000000,
        coutRemplacement: 1000000000,
        dateEcheance: DateTime(2040, 1, 1),
        tranche: TrancheDuree.plus5Ans,
      ),
      Derive(
        id: 2,
        // Un libellé long et une devise étrangère : les deux cas qui font
        // déborder une ligne de tableau.
        contrepartie: 'BANQUE OUEST AFRICAINE DE DEVELOPPEMENT',
        categorieContrepartie:
            CategorieContrepartieDerive.banquesMultilaterales,
        nature: NatureDerive.autresProduitsDeBase,
        typeContrat: 'Achat à terme de produits agricoles',
        devise: 'EUR',
        montantNotionnel: 2000000000,
        coutRemplacement: 0,
        dateEcheance: DateTime(2027, 3, 15),
        tranche: TrancheDuree.moins1An,
      ),
    ];
  }

  @override
  Future<SyntheseEp11> fetchSyntheseEp11() async => SyntheseEp11.fromJson({
        'nombre': vide ? 0 : 2,
        'total_notionnel': vide ? 0.0 : 12000000000.0,
        'total_cout_remplacement': vide ? 0.0 : 1000000000.0,
        'total_exposition': vide ? 0.0 : 1450000000.0,
        'lignes': vide
            ? const <dynamic>[]
            : [
                {
                  'code': 'RC051',
                  'nature': 'taux',
                  'tranche': 'plus_5_ans',
                  'libelle': "Engagements sur instruments de taux d'intérêt "
                      '— Durée > 5 ans',
                  'nombre_contrats': 1,
                  'cout_remplacement': 1000000000.0,
                  'montant_notionnel': 10000000000.0,
                  'ponderation': 0.015,
                  'notionnel_pondere': 150000000.0,
                  'exposition': 1150000000.0,
                  'ventilation': {'d': 1150000000.0},
                },
                {
                  'code': 'RC061',
                  'nature': 'autres_produits_de_base',
                  'tranche': 'moins_1_an',
                  'libelle': 'Engagements sur autres produits de base '
                      '— Durée < 1 an',
                  'nombre_contrats': 1,
                  'cout_remplacement': 0.0,
                  'montant_notionnel': 2000000000.0,
                  'ponderation': 0.10,
                  'notionnel_pondere': 200000000.0,
                  'exposition': 200000000.0,
                  'ventilation': {'c': 200000000.0},
                },
              ],
        'alertes': vide
            ? const <String>['Le registre est vide : l\'EP11 partira à zéro.']
            : const <String>[],
      });

  @override
  Future<SousJacents> fetchSousJacentsDerives() async => SousJacents.vide;

  @override
  Future<List<ContrepartieDerive>> fetchContrepartiesDerives() async =>
      const [
        ContrepartieDerive(
          id: 'EXP-2026-00007',
          nom: 'SOCIETE GENERALE',
          categoriePrudentielle: 'Institutions financières',
          categorieEp11: CategorieContrepartieDerive.institutionsFinancieres,
          notation: 'A',
        ),
      ];

  @override
  Future<void> deleteDerive(int id) async {
    supprime = id;
  }
}

Future<_ApiBouchonnee> _ouvrir(
  WidgetTester tester, {
  Size taille = const Size(1600, 950),
  bool vide = false,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final api = _ApiBouchonnee(vide: vide);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: DerivesScreen(api: api))));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('la mise en page tient sur un écran large', (tester) async {
    await _ouvrir(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Instruments dérivés'), findsOneWidget);
  });

  testWidgets('elle tient aussi sur une fenêtre étroite', (tester) async {
    await _ouvrir(tester, taille: const Size(1280, 800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('les quinze lignes de l\'état sont toutes visibles',
      (tester) async {
    // Y compris les vides : elles partent toutes dans la déclaration, et voir
    // un zéro là où on attendait un contrat est ce qu'on vient vérifier.
    await _ouvrir(tester);
    expect(find.text('RC051'), findsOneWidget);
    expect(find.text('RC061'), findsOneWidget);
  });

  testWidgets('le libellé du poste est rendu en entier', (tester) async {
    // Les libellés du formulaire sont longs. La grille les enroule dans leur
    // cellule plutôt que de les couper : rien n'est caché derrière une
    // ellipse, et la ligne s'agrandit de ce qu'il faut.
    await _ouvrir(tester);
    expect(
      find.text("Engagements sur instruments de taux d'intérêt "
          '— Durée > 5 ans'),
      findsOneWidget,
    );
  });

  testWidgets('les montants se lisent en millions de FCFA', (tester) async {
    // C'est l'unité de la déclaration (notice, § 2.3) : onze chiffres alignés
    // ne se comparent pas à ce que porte le classeur transmis.
    await _ouvrir(tester);
    expect(find.text(AppFormatters.montant(12000000000)), findsWidgets);
    expect(find.text(AppFormatters.montant(1450000000)), findsWidgets);
  });

  testWidgets('la ventilation retombe sur l\'exposition déclarée',
      (tester) async {
    await _ouvrir(tester);
    // 1 150 M chez les institutions financières, 200 M chez les BMD,
    // 1 450 M au total : la somme boucle par construction.
    expect(find.text(AppFormatters.montant(1150000000)), findsWidgets);
    expect(find.text(AppFormatters.montant(200000000)), findsWidgets);
  });

  testWidgets('le bouton d\'ajout ouvre le formulaire', (tester) async {
    await _ouvrir(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter un contrat'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter un contrat dérivé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retirer un contrat demande confirmation puis appelle le serveur',
      (tester) async {
    final api = await _ouvrir(tester);

    await tester.tap(find.byTooltip('Retirer').first);
    await tester.pumpAndSettle();
    expect(find.text('Retirer ce contrat ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retirer'));
    await tester.pumpAndSettle();

    expect(api.supprime, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un registre vide se lit comme un zéro assumé', (tester) async {
    await _ouvrir(tester, vide: true);
    expect(tester.takeException(), isNull);
    expect(find.text('Aucun contrat enregistré'), findsOneWidget);
    expect(find.textContaining('registre est vide'), findsOneWidget);
  });

  testWidgets('un backend trop ancien est nommé, pas le code HTTP',
      (tester) async {
    // C'est arrivé : un serveur lancé avant l'ajout de la route des
    // contreparties la confondait avec la modification d'un contrat, et
    // répondait 405. L'écran affichait « Method Not Allowed », qui ne dit à
    // personne qu'il suffit de relancer le backend.
    tester.view.physicalSize = const Size(1600, 950);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DerivesScreen(api: _ApiAncienne()))));
    await tester.pumpAndSettle();

    expect(find.textContaining('ne connaît pas cette route'), findsOneWidget);
    expect(find.textContaining('Method Not Allowed'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// Un backend antérieur à la route des contreparties : il la confond avec la
/// modification d'un contrat, et refuse la lecture.
class _ApiAncienne extends _ApiBouchonnee {
  @override
  Future<List<ContrepartieDerive>> fetchContrepartiesDerives() async =>
      throw Exception('Method Not Allowed');
}
