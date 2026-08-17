// Rend la carte « Participations » dans le contexte exact de l'onglet
// Portefeuille : un SingleChildScrollView, donc une largeur bornée et une
// hauteur infinie. C'est la contrainte qui casse les mises en page trop
// gourmandes, et l'écran ne la donnait à aucun test.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/modules/participations/models/participation_models.dart';
import 'package:rwa_calculator/modules/participations/widgets/concentration_groupes_page.dart';
import 'package:rwa_calculator/modules/participations/widgets/groupes_clients_page.dart';
import 'package:rwa_calculator/modules/participations/widgets/jauge_limite.dart';
import 'package:rwa_calculator/modules/participations/widgets/limites_participations_page.dart';
import 'package:rwa_calculator/modules/participations/widgets/participations_card.dart';
import 'package:rwa_calculator/modules/participations/widgets/participations_dialog.dart';
import 'package:rwa_calculator/modules/participations/widgets/tableau_maison.dart';

/// API qui répond sans réseau, avec une synthèse représentative : une limite
/// proche de son plafond, une non mesurable, et une alerte.
class _ApiBouchonnee extends RwaApiService {
  _ApiBouchonnee() : super(baseUrl: 'http://127.0.0.1:1');

  /// Au moins une participation : c'est la branche non vide du dialogue de
  /// saisie qui rend le tableau, et donc la seule qui pose ce widget.
  @override
  Future<List<Participation>> fetchParticipations() async => const [
        Participation(
          id: 1,
          denomination: 'Sucrivoire SA',
          categorie: CategorieParticipation.entiteCommerciale,
          capitalEntreprise: 40000000000,
          montantBrut: 9000000000,
          montantNet: 8500000000,
        ),
        Participation(
          id: 2,
          denomination: 'SCI Plateau',
          categorie: CategorieParticipation.societeImmobiliere,
          capitalEntreprise: 5000000000,
          montantBrut: 400000000,
          montantNet: 400000000,
        ),
      ];

  /// Les deux pages sœurs du module lisent ces deux jeux.
  @override
  Future<List<GroupeClients>> fetchGroupesClients() async => const [
        GroupeClients(
          id: 1,
          nom: 'Groupe Sucrivoire',
          numeroCentraleRisques: 'CR-000148',
          membres: [
            MembreGroupe(
              id: '10',
              nom: 'Sucrivoire SA',
              pays: "Cote d'Ivoire",
              categorieLien: CategorieLien.controleDeDroit,
              numeroCentraleRisques: 'CR-000149',
              secteurActivite: 'Agro-industrie',
            ),
          ],
        ),
      ];

  @override
  Future<ConcentrationGroupes> fetchConcentrationGroupes() async =>
      ConcentrationGroupes.fromJson(<String, dynamic>{
        'fonds_propres_t1': 13200000000.0,
        'seuil_grand_risque': 3300000000.0,
        'exposition_portefeuille': 42000000000.0,
        // Deux groupes : c'est le minimum pour vérifier que le top 5 n'en
        // affiche qu'un à la fois.
        'groupes': [
          {
            'id': 1,
            'nom': 'Groupe Sucrivoire',
            'numero_centrale_risques': 'CR-000148',
            'exposition_totale': 4100000000.0,
            'part_fonds_propres': 0.31,
            'depasse_le_seuil': true,
            'part_du_plus_gros_membre': 0.78,
            'herfindahl': 0.64,
            'membres': [
              {
                'nom': 'Sucrivoire SA',
                'exposition': 3200000000.0,
                'part_du_groupe': 0.78,
              },
            ],
          },
          {
            'id': 2,
            'nom': 'ORANGE',
            'numero_centrale_risques': 'CR-000212',
            'exposition_totale': 900000000.0,
            'part_fonds_propres': 0.07,
            'depasse_le_seuil': false,
            'part_du_plus_gros_membre': 1.0,
            'herfindahl': 1.0,
            'membres': [
              {
                'nom': 'Orange Cote d\'Ivoire',
                'exposition': 900000000.0,
                'part_du_groupe': 1.0,
              },
            ],
          },
        ],
      });

  @override
  Future<SyntheseParticipations> fetchSyntheseParticipations() async {
    return SyntheseParticipations.fromJson(<String, dynamic>{
      'nombre': 4,
      'nombre_entites_commerciales': 1,
      'total_general': 8500000000.0,
      'total_entites_commerciales': 1200000000.0,
      'totaux_par_categorie': {'entite_commerciale': 1200000000.0},
      // Ordre de grandeur réel de l'assiette : avec un T1 trop petit, la part
      // d'une seule participation le dépasserait, et le cas « respectée » ne
      // serait jamais exercé par le tableau de saisie.
      'fonds_propres_t1': 93322000000.0,
      'fonds_propres_effectifs': 15100000000.0,
      'date_fonds_propres': '2025-12-31',
      'immobilisations_nettes': 1600000000.0,
      'immobilisations_hors_exploitation_nettes': 0.0,
      'limites': [
        {
          'code': 'RA006',
          'libelle':
              'Participation la plus forte dans une entité commerciale',
          'etat': 'EP35',
          'numerateur': 9000000000.0,
          'numerateur_libelle': 'Souscription (montant brut)',
          'denominateur': 40000000000.0,
          'denominateur_libelle': 'Capital de l\'entreprise émettrice',
          'observe': 0.225,
          'limite': 0.25,
          'mesurable': true,
          'respectee': true,
          'excedent': 0.0,
          'concerne': 'Sucrivoire SA',
        },
        {
          'code': 'RA009',
          'libelle':
              'Immobilisations hors exploitation et participations immobilières',
          'etat': 'EP36',
          'numerateur': 0.0,
          'numerateur_libelle':
              'Immobilisations hors exploitation + participations immobilières',
          'denominateur': 0.0,
          'denominateur_libelle': 'Fonds propres de base T1',
          'observe': 0.0,
          'limite': 0.15,
          'mesurable': false,
          'respectee': false,
          'excedent': 0.0,
        },
      ],
      'alertes': [
        'Aucune immobilisation « hors exploitation » n\'est déclarée : la '
            'limite RA009 ne porte que sur les participations immobilières.',
      ],
    });
  }
}

Widget _app({required Widget corps}) {
  return MaterialApp(
    // Mêmes délégués que l'application : ce sont eux qui chargent les
    // symboles de date du français, dont AppFormatters.shortDate a besoin.
    locale: const Locale('fr', 'FR'),
    supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: corps,
  );
}

Future<void> _poser(WidgetTester tester, double largeur) async {
  tester.view.physicalSize = Size(largeur, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _app(
      corps: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [ParticipationsCard(api: _ApiBouchonnee())],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// La page « Détails », telle que le bouton de la carte l'ouvre.
Future<void> _poserLaPage(WidgetTester tester, double largeur) async {
  tester.view.physicalSize = Size(largeur, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _app(corps: LimitesParticipationsPage(api: _ApiBouchonnee())),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la carte se rend dans une colonne défilante', (tester) async {
    await _poser(tester, 1440);
    expect(tester.takeException(), isNull);

    expect(find.text('Participations'), findsOneWidget);

    // « Détails » ouvre un écran de lecture : même traitement que « Analyse »
    // sur la carte des groupes, donc un bouton à contour et non un fond teinté.
    // Trois dessins pour un même rôle obligeraient à réapprendre la carte.
    expect(find.widgetWithText(BoutonSecondaire, 'Détails'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    expect(find.textContaining('Les 2 limites sont respectées'), findsNothing);
    // Une limite non mesurable prime sur une limite proche du plafond : c'est
    // l'ordre dans lequel il faut agir.
    expect(find.textContaining('n\'est pas mesurable'), findsOneWidget);
  });

  testWidgets('la carte se rend dans une fenêtre étroite', (tester) async {
    await _poser(tester, 900);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la page des limites se rend, lignes dépliées comprises',
      (tester) async {
    await _poserLaPage(tester, 1440);
    expect(tester.takeException(), isNull);

    // La colonne « Situation » vit dans un IntrinsicHeight : elle mesure ses
    // cellules avant de les poser, et une cellule flexible y échouerait.
    expect(find.text(EtatLimite.procheDuPlafond.libelle), findsOneWidget);
    expect(find.text(EtatLimite.nonMesurable.libelle), findsOneWidget);

    // Le dépliage montre le calcul : c'est lui qui rend le ratio contestable.
    await tester.tap(find.text('RA006'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Marge restante'), findsOneWidget);
  });

  // Le corps du dialogue de saisie est un SingleChildScrollView : la hauteur
  // qu'il donne à son contenu est infinie. Une ListView ne peut pas s'y
  // dimensionner, et la mise en page échouait dès l'ouverture — mais seulement
  // avec au moins une participation en base, la branche vide n'affichant aucun
  // tableau.
  testWidgets('le dialogue de saisie s\'ouvre avec des participations en base',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late BuildContext contexte;
    await tester.pumpWidget(
      _app(
        corps: Builder(
          builder: (ctx) {
            contexte = ctx;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    // ignore: unawaited_futures
    ParticipationsDialog.show(contexte, _ApiBouchonnee());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sucrivoire SA'), findsOneWidget);
    expect(find.text('SCI Plateau'), findsOneWidget);

    // Les montants vivent dans des colonnes intitulées une fois, plus dans une
    // phrase répétée sous chaque nom.
    expect(find.text('Capital de l\'émetteur'), findsOneWidget);
    expect(find.text('Souscription brute'), findsOneWidget);
    expect(find.text('Libéré net'), findsOneWidget);
    expect(find.textContaining('· brut '), findsNothing);

    /// Couleur d'un pourcentage affiché, pour vérifier qu'il porte son état.
    Color? teinteDe(String pourcentage) =>
        tester.widget<Text>(find.text(pourcentage)).style?.color;

    // 22,5 % pour un plafond de 25 % : 90 % de la marge consommée. Ni dépassée
    // ni banale — c'est l'état que l'ancienne pastille rendait invisible.
    expect(teinteDe('22.5 %'), limiteProche);
    // 9,1 % du T1 pour un plafond de 15 % : de la marge, donc respectée.
    expect(teinteDe('9.1 %'), limiteRespectee);
    // La part du capital d'une société immobilière n'est visée par aucune
    // limite de l'EP01 : elle reste grise pour ne pas s'annoncer plafonnée.
    expect(teinteDe('8.0 %'), limiteInconnue);
  });

  testWidgets('la barre de titre distingue la saisie de la consultation',
      (tester) async {
    await _poserLaPage(tester, 1440);

    // « Gérer les participations » est la seule action de cette barre qui
    // écrive : elle est remplie, les autres restent des pastilles discrètes.
    // Sans cette hiérarchie, il faut lire les trois libellés pour trouver
    // celle qui compte.
    Finder bouton(String libelle) => find.ancestor(
          of: find.text(libelle),
          matching: find.byType(BoutonEnTete),
        );

    for (final libelle in ['Retour', 'Gérer les participations', 'Recalculer']) {
      expect(bouton(libelle), findsOneWidget, reason: libelle);
    }

    expect(
      tester.widget<BoutonEnTete>(bouton('Gérer les participations')).principal,
      isTrue,
    );
    for (final libelle in ['Retour', 'Recalculer']) {
      expect(
        tester.widget<BoutonEnTete>(bouton(libelle)).principal,
        isFalse,
        reason: '$libelle ne modifie aucune donnée.',
      );
    }

    // Une seule action principale par barre : deux se disputeraient l'œil.
    final principaux = tester
        .widgetList<BoutonEnTete>(find.byType(BoutonEnTete))
        .where((bouton) => bouton.principal);
    expect(principaux.length, 1);

    // Et sa teinte vient du thème, comme celle du bouton « Ajouter une
    // participation » du dialogue de saisie. L'accent étant réglable par
    // l'utilisateur, une couleur figée ici cesserait d'y correspondre.
    final rempli = tester.widget<FilledButton>(
      find.descendant(
        of: bouton('Gérer les participations'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      rempli.style?.backgroundColor,
      isNull,
      reason: 'Le remplissage doit rester celui du thème.',
    );
  });

  // Les deux autres pages du module posent, comme celle des limites, une
  // ListView non bornée dans un Align + ConstrainedBox. Le motif est le meme
  // que celui qui a fait echouer la saisie : il vaut d'etre verifie ici plutot
  // que decouvert a l'ouverture.
  testWidgets('la page des groupes de clients liés se rend', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(corps: GroupesClientsPage(api: _ApiBouchonnee())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Groupe Sucrivoire'), findsWidgets);
  });

  testWidgets('la page de concentration des groupes se rend', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(corps: ConcentrationGroupesPage(api: _ApiBouchonnee())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Sucrivoire'), findsWidgets);

    // La page est une ListView : la section du classement n'est pas construite
    // tant qu'elle n'a pas été atteinte. Sans ce défilement, les vérifications
    // ci-dessous passeraient sur du vide.
    await tester.scrollUntilVisible(
      find.text('Top 5 des membres'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Le classement ne montre que le groupe choisi : empiler une carte par
    // groupe faisait grandir la page avec le portefeuille. Le membre du second
    // groupe reste donc absent tant qu'il n'est pas sélectionné.
    //
    // `textContaining` et non `text` : la légende numérote ses lignes, le
    // libellé exact est « 1. Orange Cote d'Ivoire ». Sur l'égalité stricte,
    // l'absence serait vraie pour la mauvaise raison et le test ne prouverait
    // plus rien après la sélection.
    expect(find.textContaining('Orange Cote'), findsNothing);

    // Et son sélecteur change bien de groupe.
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ORANGE').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Orange Cote'), findsWidgets);
  });
}
