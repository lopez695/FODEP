// L'écran des dispositions transitoires doit tenir dans sa fenêtre.
//
// La première version débordait : libellés tronqués au milieu d'un mot,
// colonne de droite coupée en bas, formules qui passaient à la ligne. Un essai
// de rendu tranche ce genre de chose mieux qu'une relecture — Flutter lève sur
// tout débordement de mise en page, et la suite échoue.
//
// Ce qui se vérifie ici : la mise en page tient à deux tailles de fenêtre, les
// codes DISPRU sont tous présents (c'est par eux que le déclarant retrouve sa
// case sur le formulaire), et les lignes calculées suivent la frappe.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/core/utils/formatters.dart';
import 'package:rwa_calculator/modules/dispositions_transitoires/models/dispositions_transitoires_models.dart';
import 'package:rwa_calculator/modules/dispositions_transitoires/widgets/dispositions_transitoires_dialog.dart';

/// API qui répond sans réseau, sur un exercice déjà renseigné.
class _ApiBouchonnee extends RwaApiService {
  _ApiBouchonnee({this.renseigne = true})
      : super(baseUrl: 'http://127.0.0.1:1');

  final bool renseigne;

  /// Ce que le dialogue a envoyé, pour vérifier que la saisie part bien.
  DispositionsTransitoires? enregistre;

  @override
  Future<void> saveDispositionsTransitoires(
    DispositionsTransitoires dispositions,
  ) async {
    enregistre = dispositions;
  }

  @override
  Future<DispositionsTransitoires?> fetchDispositionsTransitoires([
    int? exercice,
  ]) async {
    if (!renseigne) return null;
    return const DispositionsTransitoires(
      exercice: 2026,
      partCapitalNonAdmissible: 10000000000,
      provisionsReglementees: 2000000000,
      fondsAffectes: 1000000000,
      cet1EnCirculation: 20000000000,
      cet1EligibleAt1: 3000000000,
      cet1EligibleT2Autres: 1000000000,
      dettesSubordonnees2018: 8000000000,
      partDettesNonAdmissible: 4000000000,
      ecartsReevaluation: 1000000000,
      t2EnCirculation: 3000000000,
    );
  }

  @override
  Future<SyntheseEp04> fetchSyntheseEp04([int? exercice]) async =>
      SyntheseEp04.fromJson({
        'exercice': renseigne ? 2026 : null,
        'taux_de_retrait': 0.9,
        'renseigne': renseigne,
        'report_ep03': renseigne
            ? const {
                'FPI07': 11700000000.0,
                'FPI25': 3000000000.0,
                'FPI33': 1000000000.0,
                'FPI34': 3000000000.0,
              }
            : const <String, dynamic>{},
        'lignes': const <dynamic>[],
        'alertes': renseigne
            ? const <String>[]
            : const <String>['Aucune disposition transitoire n\'est enregistrée.'],
      });
}

Future<_ApiBouchonnee> _ouvrir(
  WidgetTester tester, {
  Size taille = const Size(1440, 900),
  bool renseigne = true,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final api = _ApiBouchonnee(renseigne: renseigne);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () =>
              DispositionsTransitoiresDialog.show(context, api, 2026),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('la mise en page tient sur un écran de bureau', (tester) async {
    await _ouvrir(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Dispositions transitoires sur les fonds propres'),
        findsOneWidget);
  });

  testWidgets('elle tient aussi sur une fenêtre étroite', (tester) async {
    // Un portable de 1280 de large reste courant, et le dialogue s'y ouvre
    // avec ses deux colonnes.
    await _ouvrir(tester, taille: const Size(1280, 800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('chaque case du formulaire porte son code DISPRU',
      (tester) async {
    // C'est l'adresse de la case sur l'état : sans elle, une saisie ne se
    // retrouve pas sur le classeur transmis.
    await _ouvrir(tester);
    for (final code in const [
      'DT002', 'DT003', 'DT004', 'DT007', 'DT009',
      'DT010', 'DT011', 'DT012', 'DT013', 'DT016',
      'FPI25', 'FPI33', 'FPI35', 'FPI36',
    ]) {
      expect(find.text(code), findsWidgets, reason: '$code manque à l\'écran');
    }
  });

  testWidgets('les lignes calculées sont annoncées par leur formule',
      (tester) async {
    await _ouvrir(tester);
    // Le formulaire imprime ces formules et attend le résultat : les montrer
    // évite qu'un montant calculé passe pour une saisie oubliée.
    expect(find.text('(f) = c + d + e'), findsOneWidget);
    expect(find.text('(n) = k + l + m'), findsOneWidget);
    expect(find.textContaining('(g) = f ×'), findsOneWidget);
    expect(find.text('(i) = min(g, h)'), findsWidgets);
    expect(find.text('(q) = min(o, p)'), findsWidgets);
  });

  testWidgets('le total suit la frappe, sans attendre l\'enregistrement',
      (tester) async {
    await _ouvrir(tester);

    // L'état se déclare en millions de FCFA (notice, § 2.3) : c'est sous cette
    // forme que l'écran rend ses calculs, et le séparateur de milliers vient
    // de la locale — on le demande au formateur plutôt que de l'écrire ici.
    expect(find.text(AppFormatters.montant(13e9)), findsOneWidget);

    // On porte le capital non admissible de 10 à 20 Md : le total suit.
    final champ = find.byType(TextField).first;
    await tester.enterText(champ, '20000000000');
    await tester.pumpAndSettle();
    expect(find.text(AppFormatters.montant(23e9)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("enregistrer ne casse pas le rechargement de l'état",
      (tester) async {
    // Le rechargement passe par setState. Une flèche y renverrait le Future
    // affecté, que Flutter refuse — et l'écran affichait alors « Enregistrement
    // impossible » sur une saisie pourtant partie. Les essais de rendu ne
    // touchaient pas ce bouton : ils ne pouvaient pas le voir.
    final api = await _ouvrir(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(api.enregistre, isNotNull, reason: 'la saisie doit partir');
    expect(api.enregistre!.exercice, 2026);
    expect(api.enregistre!.partCapitalNonAdmissible, 10000000000);
    // Et l'échec ne doit pas s'afficher pour un enregistrement réussi.
    expect(find.textContaining('Enregistrement impossible'), findsNothing);
  });

  testWidgets('un exercice vide affiche son bandeau sans déborder',
      (tester) async {
    await _ouvrir(tester, renseigne: false);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Aucune disposition transitoire'),
        findsOneWidget);
  });
}
