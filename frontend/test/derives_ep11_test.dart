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
import 'package:rwa_calculator/core/utils/formatters.dart';
import 'package:rwa_calculator/modules/derives/widgets/derive_formulaire.dart';

/// Deux tiers du portefeuille, tels que le serveur les propose.
const _contreparties = [
  ContrepartieDerive(
    id: 'EXP-2026-00007',
    nom: 'CITIBANK',
    categoriePrudentielle: 'Institutions financières',
    categorieEp11: CategorieContrepartieDerive.institutionsFinancieres,
    notation: 'A',
  ),
  ContrepartieDerive(
    id: 'EXP-2026-00008',
    nom: "ETAT DE COTE D'IVOIRE",
    categoriePrudentielle: 'Souverains',
    categorieEp11: CategorieContrepartieDerive.souverains,
    notation: 'BB',
  ),
];

/// Ce que le serveur propose de couvrir : un crédit de CITIBANK, une
/// obligation d'État, une action.
final _sousJacents = SousJacents(
  credits: [
    CreditCouvrable(
      id: 'EXP-2026-00077',
      contrepartieId: 'EXP-2026-00007',
      contrepartie: 'CITIBANK',
      categoriePrudentielle: 'Institutions financières',
      categorieEp11: CategorieContrepartieDerive.institutionsFinancieres,
      notation: 'A',
      montantBrut: 5000000000,
      dateEcheance: DateTime(2030, 1, 1),
      statut: 'Active',
    ),
  ],
  obligations: [
    ObligationDetenue(
      isin: 'OAT-CI-2030',
      emetteur: "État de Côte d'Ivoire",
      dateEcheance: DateTime(2030, 3, 15),
      valeurNominale: 10000,
      quantite: 150000,
      tauxCouponPct: 5.75,
    ),
  ],
  actions: const [
    ActionDetenue(
      ticker: 'SNTS',
      libelle: 'Sonatel SA',
      secteur: 'Télécommunications',
      quantite: 5000,
    ),
  ],
);

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
        contrepartieId: 'EXP-2026-00007',
        contrepartie: 'BANQUE ATLANTIQUE',
        categorieContrepartie: CategorieContrepartieDerive.souverains,
        nature: NatureDerive.changeOr,
        devise: 'EUR',
        montantNotionnel: 1000,
        coutRemplacement: 250,
        dateEcheance: DateTime(2030, 6, 30),
      );

      final charge = contrat.toPayload();
      // L'identifiant part, pas le nom ni la catégorie : le serveur les
      // relit sur la fiche de la contrepartie.
      expect(charge['contrepartie_id'], 'EXP-2026-00007');
      expect(charge.containsKey('contrepartie'), isFalse);
      expect(charge.containsKey('categorie_contrepartie'), isFalse);
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
    // Sans contrepartie, le contrat n'a ni colonne de ventilation ni notation :
    // il partirait dans l'EP11 sans qu'on sache où le ranger.
    Derive? rendu;
    await _ouvrirFormulaire(tester, (valeur) => rendu = valeur);
    await _onglet(tester, TypeSousJacent.autre);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Choisissez une contrepartie du portefeuille.'),
        findsOneWidget);
    expect(rendu, isNull, reason: 'le formulaire ne doit pas se fermer');
  });

  testWidgets('un contrat saisi ressort avec sa contrepartie et ses montants',
      (tester) async {
    Derive? rendu;
    await _ouvrirFormulaire(tester, (valeur) => rendu = valeur);
    await _onglet(tester, TypeSousJacent.autre);

    // On tape un bout du nom, et on choisit dans la liste.
    await _saisir(tester, DeriveFormulaireCles.contrepartie, 'citi');
    await tester.tap(find.text('CITIBANK'));
    await tester.pumpAndSettle();

    await _saisir(tester, DeriveFormulaireCles.notionnel, '10000000000');
    await _saisir(tester, DeriveFormulaireCles.cout, '1000000000');

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(rendu, isNotNull);
    expect(rendu!.contrepartie, 'CITIBANK');
    expect(rendu!.contrepartieId, 'EXP-2026-00007');
    expect(rendu!.montantNotionnel, 10000000000);
    expect(rendu!.coutRemplacement, 1000000000);
    // La nature par défaut est la plus courante, un swap de taux ; la
    // catégorie, elle, vient de la fiche de CITIBANK.
    expect(rendu!.nature, NatureDerive.taux);
    expect(rendu!.categorieContrepartie,
        CategorieContrepartieDerive.institutionsFinancieres);
  });

  testWidgets('la contrepartie se retrouve par son identifiant',
      (tester) async {
    // Deux tiers peuvent porter le même nom : c'est l'identifiant qui fait
    // la correspondance avec le reste de l'outil.
    await _ouvrirFormulaire(tester, (_) {});
    await _onglet(tester, TypeSousJacent.autre);

    await _saisir(tester, DeriveFormulaireCles.contrepartie, '00008');
    expect(find.text("ETAT DE COTE D'IVOIRE"), findsOneWidget);
    expect(find.text('CITIBANK'), findsNothing);

    await tester.tap(find.text("ETAT DE COTE D'IVOIRE"));
    await tester.pumpAndSettle();
    // Et la fiche dit où le contrat tombera.
    expect(
      find.descendant(
        of: find.byKey(DeriveFormulaireCles.fiche),
        matching: find.text('Souverains'),
      ),
      findsWidgets,
    );
  });

  testWidgets("l'aperçu applique la pondération reçue du serveur",
      (tester) async {
    // La pondération est celle que la BCEAO imprime sur le formulaire. Le
    // formulaire la reçoit de l'écran, qui la tient du serveur : il ne la
    // choisit pas. Ici 0,5 %, quelle que soit la tranche.
    await _ouvrirFormulaire(
      tester,
      (_) {},
      lignes: [
        for (final tranche in TrancheDuree.values)
          LigneEp11(
            code: 'RC0${49 + tranche.index}',
            nature: 'taux',
            tranche: tranche.wire,
            libelle: '',
            nombreContrats: 0,
            coutRemplacement: 0,
            montantNotionnel: 0,
            ponderation: 0.005,
            notionnelPondere: 0,
            exposition: 0,
            ventilation: const {},
          ),
      ],
    );
    await _onglet(tester, TypeSousJacent.autre);

    await _saisir(tester, DeriveFormulaireCles.contrepartie, 'citi');
    await tester.tap(find.text('CITIBANK'));
    await tester.pumpAndSettle();
    await _saisir(tester, DeriveFormulaireCles.notionnel, '10000000000');
    await _saisir(tester, DeriveFormulaireCles.cout, '1000000000');

    final apercu = find.byKey(DeriveFormulaireCles.apercu);
    await tester.ensureVisible(apercu);
    await tester.pumpAndSettle();

    // Écrits dans l'unité choisie en haut de l'écran, comme partout ailleurs.
    String millions(double valeur) => AppFormatters.montant(valeur * 1e6);
    // (d) = 10 000 M × 0,5 % = 50 M ; (e) = 1 000 M + 50 M = 1 050 M.
    expect(find.descendant(of: apercu, matching: find.text(millions(50))),
        findsOneWidget);
    expect(find.descendant(of: apercu, matching: find.text(millions(1050))),
        findsOneWidget);
  });

  testWidgets('le formulaire tient en deux colonnes sur un écran de bureau',
      (tester) async {
    // Et en une seule sur une fenêtre étroite : c'est la taille par défaut des
    // essais ci-dessus, qui échoueraient au moindre débordement.
    await _ouvrirFormulaire(tester, (_) {}, taille: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('CE QUE LE CONTRAT DÉCLARERA'), findsOneWidget);
  });

  testWidgets('la devise se choisit parmi celles que le serveur convertit',
      (tester) async {
    // Une autre serait convertie au taux de repli 1,0, comme si elle était
    // déjà du franc : la liste ne propose que XOF, EUR et USD.
    await _ouvrirFormulaire(tester, (_) {});
    await tester.ensureVisible(find.byKey(DeriveFormulaireCles.devise));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DeriveFormulaireCles.devise));
    await tester.pumpAndSettle();
    for (final devise in devisesDerives) {
      expect(find.text(devise), findsWidgets);
    }
    expect(find.text('GBP'), findsNothing);

    await tester.tap(find.text('EUR').last);
    await tester.pumpAndSettle();
    // Et les montants portent la devise choisie.
    expect(
      find.descendant(
        of: find.byKey(DeriveFormulaireCles.notionnel),
        matching: find.text('EUR'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('les types de contrat suivent la nature du sous-jacent',
      (tester) async {
    await _ouvrirFormulaire(tester, (_) {});

    // Nature par défaut : les taux d'intérêt.
    await tester.ensureVisible(find.byKey(DeriveFormulaireCles.typeContrat));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DeriveFormulaireCles.typeContrat));
    await tester.pumpAndSettle();
    expect(find.text('Swap de taux'), findsWidgets);
    expect(find.text('Change à terme'), findsNothing);
    await tester.tap(find.text('Swap de taux').last);
    await tester.pumpAndSettle();

    // On passe au change : le swap de taux n'y a plus de sens, et s'efface.
    // Le corps défile : chaque liste est ramenée à l'écran avant d'être
    // ouverte, sans quoi le tap tombe à côté et le menu ne s'ouvre pas.
    await tester.ensureVisible(find.byKey(DeriveFormulaireCles.nature));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DeriveFormulaireCles.nature));
    await tester.pumpAndSettle();
    await tester.tap(find.text(NatureDerive.changeOr.label).last);
    await tester.pumpAndSettle();
    expect(find.text('Swap de taux'), findsNothing);

    await tester.ensureVisible(find.byKey(DeriveFormulaireCles.typeContrat));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DeriveFormulaireCles.typeContrat));
    await tester.pumpAndSettle();
    expect(find.text('Change à terme'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un crédit couvert donne sa contrepartie : le client lui-même',
      (tester) async {
    // C'est le seul cas où le sous-jacent et la contrepartie coïncident : le
    // client qui emprunte signe aussi la couverture.
    Derive? rendu;
    await _ouvrirFormulaire(tester, (valeur) => rendu = valeur);

    // Le formulaire s'ouvre sur cet onglet : c'est le cas le plus courant.
    expect(find.text("1 · CRÉDIT D'UN CLIENT"), findsOneWidget);
    await _saisir(tester, DeriveFormulaireCles.credit, '00077');
    await tester.tap(find.text('CITIBANK'));
    await tester.pumpAndSettle();
    await _saisir(tester, DeriveFormulaireCles.notionnel, '1000000000');

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(rendu, isNotNull);
    expect(rendu!.sousJacentType, TypeSousJacent.credit);
    expect(rendu!.sousJacentRef, 'EXP-2026-00077');
    expect(rendu!.contrepartieId, 'EXP-2026-00007');
    // L'échéance proposée est celle du crédit.
    expect(rendu!.dateEcheance, DateTime(2030, 1, 1));
  });

  testWidgets('une obligation fixe la nature et demande qui a signé',
      (tester) async {
    await _ouvrirFormulaire(tester, (_) {});
    await _onglet(tester, TypeSousJacent.obligation);

    expect(find.text('1 · OBLIGATION'), findsOneWidget);
    expect(find.text('2 · SIGNÉ AVEC'), findsOneWidget);

    await _saisir(tester, DeriveFormulaireCles.obligation, 'OAT');
    await tester.tap(find.text("État de Côte d'Ivoire"));
    await tester.pumpAndSettle();

    // Un dérivé sur une obligation porte sur les taux : la nature est fixée.
    expect(find.textContaining('Fixée par le sous-jacent'), findsOneWidget);

    // L'émetteur n'est pas la contrepartie : il faut dire qui a signé.
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez une contrepartie du portefeuille.'),
        findsOneWidget);
  });

  testWidgets('une action fixe la nature « titres de propriété »',
      (tester) async {
    Derive? rendu;
    await _ouvrirFormulaire(tester, (valeur) => rendu = valeur);
    await _onglet(tester, TypeSousJacent.action);
    expect(find.text('1 · ACTION'), findsOneWidget);

    await _saisir(tester, DeriveFormulaireCles.action, 'sonatel');
    await tester.tap(find.text('Sonatel SA'));
    await tester.pumpAndSettle();
    await _saisir(tester, DeriveFormulaireCles.contrepartie, 'citi');
    await tester.tap(find.text('CITIBANK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(rendu, isNotNull);
    expect(rendu!.sousJacentType, TypeSousJacent.action);
    expect(rendu!.sousJacentRef, 'SNTS');
    expect(rendu!.nature, NatureDerive.titresPropriete);
    // La contrepartie reste celui qui a signé, pas Sonatel.
    expect(rendu!.contrepartieId, 'EXP-2026-00007');
  });
}

/// Ouvre le formulaire depuis un bouton, comme l'écran le fait, et transmet ce
/// qu'il renvoie à sa fermeture.
Future<void> _ouvrirFormulaire(
  WidgetTester tester,
  void Function(Derive?) recevoir, {
  Size taille = const Size(800, 600),
  List<LigneEp11> lignes = const [],
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => recevoir(
            await DeriveFormulaire.show(
              context,
              _contreparties,
              lignes: lignes,
              sousJacents: _sousJacents,
            ),
          ),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

/// Saisit dans un champ après l'avoir fait défiler à l'écran : le corps du
/// formulaire défile, et un champ hors de la vue ne reçoit pas le clavier.
Future<void> _saisir(WidgetTester tester, Key cle, String texte) async {
  await tester.ensureVisible(find.byKey(cle));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(cle), texte);
  await tester.pumpAndSettle();
}

/// Choisit un onglet de sous-jacent dans l'en-tête du formulaire.
Future<void> _onglet(WidgetTester tester, TypeSousJacent type) async {
  await tester.tap(find.byKey(DeriveFormulaireCles.onglet(type)));
  await tester.pumpAndSettle();
}
