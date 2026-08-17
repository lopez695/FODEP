// La variation latente d'un émetteur se mesure sur TOUT son coût de revient.
//
// Une ligne au pair (gain nul) n'apporte rien au résultat, mais elle a bien
// coûté quelque chose. L'écarter de l'agrégation retirait son coût du
// dénominateur et surévaluait la variation de l'émetteur.

import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

MarketPortfolioRecord _ligne({
  required String emetteur,
  required double coutUnitaire,
  required double coursActuel,
  required double quantite,
}) {
  return MarketPortfolioRecord(
    portfolioType: MarketPortfolioType.equities,
    values: {
      'Emetteur': emetteur,
      'Devise': 'XOF',
      'Quantité': quantite,
      "Prix d'acquisition": coutUnitaire,
      'Cours actuel': coursActuel,
    },
  );
}

MarketPortfolioDataset _portefeuille(List<MarketPortfolioRecord> lignes) {
  return MarketPortfolioDataset(
    portfolioType: MarketPortfolioType.equities,
    fileName: 'essai.xlsx',
    importedAt: DateTime(2026, 7, 22),
    headers: const [
      'Emetteur',
      'Devise',
      'Quantité',
      "Prix d'acquisition",
      'Cours actuel',
    ],
    records: lignes,
  );
}

void main() {
  group('plus et moins-values latentes par émetteur', () {
    test('une ligne au pair reste dans le coût de revient', () {
      // Deux lignes de 1 M : l'une gagne 100 k, l'autre est au pair.
      // Coût de revient attendu : 2 M, et non 1 M — sans quoi la variation
      // afficherait +10 % au lieu de +5 %.
      final dataset = _portefeuille([
        _ligne(
          emetteur: 'Émetteur A',
          coutUnitaire: 1000,
          coursActuel: 1100,
          quantite: 1000,
        ),
        _ligne(
          emetteur: 'Émetteur A',
          coutUnitaire: 1000,
          coursActuel: 1000,
          quantite: 1000,
        ),
      ]);

      final lignes = dataset.latentPnlByIssuer;

      expect(lignes, hasLength(1));
      expect(lignes.single.gain, 100000);
      expect(
        lignes.single.cost,
        2000000,
        reason: 'Le coût de la ligne au pair doit rester au dénominateur.',
      );
    });

    test('un émetteur entièrement au pair sort du classement', () {
      // Ni plus-value ni moins-value : sa place dans un état de variations
      // latentes n'aurait aucun sens.
      final dataset = _portefeuille([
        _ligne(
          emetteur: 'Émetteur au pair',
          coutUnitaire: 500,
          coursActuel: 500,
          quantite: 1000,
        ),
      ]);

      expect(dataset.latentPnlByIssuer, isEmpty);
    });

    test('le classement va de la plus forte variation à la plus faible', () {
      // Gains et pertes confondus : c'est l'ampleur du mouvement qui classe,
      // et la plus lourde moins-value passe avant un petit gain.
      final dataset = _portefeuille([
        _ligne(
          emetteur: 'Petit gain',
          coutUnitaire: 100,
          coursActuel: 110,
          quantite: 1000,
        ),
        _ligne(
          emetteur: 'Grosse perte',
          coutUnitaire: 100,
          coursActuel: 40,
          quantite: 1000,
        ),
      ]);

      final lignes = dataset.latentPnlByIssuer;

      expect(lignes.first.issuer, 'Grosse perte');
      expect(lignes.first.gain, lessThan(0));
      expect(lignes.last.issuer, 'Petit gain');
    });

    test('les lignes d\'un même émetteur ne forment qu\'un rang', () {
      final dataset = _portefeuille([
        _ligne(
          emetteur: 'Émetteur B',
          coutUnitaire: 100,
          coursActuel: 120,
          quantite: 1000,
        ),
        _ligne(
          emetteur: 'Émetteur B',
          coutUnitaire: 200,
          coursActuel: 180,
          quantite: 1000,
        ),
      ]);

      final lignes = dataset.latentPnlByIssuer;

      expect(lignes, hasLength(1), reason: 'Un émetteur, un seul rang.');
      expect(lignes.single.cost, 300000);
      // +20 000 sur la première ligne, -20 000 sur la seconde : le résultat
      // net est nul, mais l'émetteur a bougé et conserve donc sa place.
      expect(lignes.single.gain, 0);
    });
  });
}
