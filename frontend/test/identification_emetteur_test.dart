// Deux lignes du même émetteur doivent n'occuper qu'un rang, quelle que soit
// la graphie du nom dans le fichier importé.
//
// Le regroupement comparait les noms caractère par caractère. Toute variation
// d'écriture créait un émetteur de plus, et le sens de l'erreur est le plus
// gênant : une exposition scindée SOUS-ESTIME la concentration. Une
// contrepartie pesant 12 % passait pour deux lignes à 6 %, sous le seuil
// d'attention d'un état de grands risques.

import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

void main() {
  group('clé canonique d\'un émetteur', () {
    test('la casse, les accents et les espaces ne séparent plus', () {
      const reference = 'Nokoué Ciments SA';
      final cle = marketIssuerCanonicalKey(reference);

      for (final graphie in [
        'NOKOUÉ CIMENTS SA',
        'nokoué ciments sa',
        'Nokoue Ciments SA',
        'Nokoué  Ciments   SA',
        '  Nokoué Ciments SA  ',
        'Nokoué Ciments S.A.',
        'Nokoué Ciments',
      ]) {
        expect(
          marketIssuerCanonicalKey(graphie),
          cle,
          reason: '« $graphie » doit rejoindre « $reference ».',
        );
      }
    });

    test('les formes juridiques ne sont retirées qu\'en fin de nom', () {
      // « SA » au milieu d'un nom en fait partie : le retirer confondrait
      // deux entités distinctes.
      expect(
        marketIssuerCanonicalKey('SA Brasseries du Wouri'),
        isNot(marketIssuerCanonicalKey('Brasseries du Wouri')),
      );
      expect(
        marketIssuerCanonicalKey('Brasseries du Wouri SA'),
        marketIssuerCanonicalKey('Brasseries du Wouri'),
      );
    });

    test('deux émetteurs réellement distincts le restent', () {
      // Le rapprochement ne doit jamais fusionner deux contreparties : ce
      // serait SURESTIMER une concentration, l'erreur inverse mais aussi
      // fausse.
      final distincts = [
        'Banque Régionale du Littoral',
        'Union Bancaire du Sahel',
        'Nokoué Ciments SA',
        'Nokoué Cimenteries SA',
        'Sanaga Utilities SA',
        'Sanaga Utilities Holding SA',
      ];
      final cles = distincts.map(marketIssuerCanonicalKey).toSet();
      expect(
        cles,
        hasLength(distincts.length),
        reason: 'Aucun de ces noms ne désigne la même entité.',
      );
    });

    test('un nom vide retombe sur une clé unique et explicite', () {
      expect(marketIssuerCanonicalKey(''), 'NON RENSEIGNE');
      expect(marketIssuerCanonicalKey('   '), 'NON RENSEIGNE');
      // Un nom réduit à sa seule forme juridique n'est pas un nom.
      expect(marketIssuerCanonicalKey('SA'), 'SA');
    });
  });

  group('nom retenu pour l\'affichage', () {
    test('la graphie la plus fréquente l\'emporte', () {
      expect(
        marketIssuerPreferredLabel([
          'Nokoué Ciments SA',
          'Nokoué Ciments SA',
          'NOKOUE CIMENTS SA',
        ]),
        'Nokoué Ciments SA',
      );
    });

    test('à fréquence égale, la graphie la plus complète l\'emporte', () {
      expect(
        marketIssuerPreferredLabel(['Nokoué Ciments', 'Nokoué Ciments SA']),
        'Nokoué Ciments SA',
      );
    });

    test('sans aucune graphie, le libellé reste explicite', () {
      expect(marketIssuerPreferredLabel(const []), 'Non renseigné');
      expect(marketIssuerPreferredLabel(const ['   ']), 'Non renseigné');
    });
  });

  group('regroupement des plus et moins-values', () {
    MarketPortfolioRecord ligne(String emetteur, double cours) {
      return MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.equities,
        values: {
          'Emetteur': emetteur,
          'Devise': 'XOF',
          'Quantité': 1000,
          "Prix d'acquisition": 100,
          'Cours actuel': cours,
        },
      );
    }

    test('deux graphies du même émetteur n\'occupent qu\'un rang', () {
      final dataset = MarketPortfolioDataset(
        portfolioType: MarketPortfolioType.equities,
        fileName: 'essai.xlsx',
        importedAt: DateTime(2026, 7, 22),
        headers: const ['Emetteur'],
        records: [
          ligne('Nokoué Ciments SA', 120),
          ligne('NOKOUE CIMENTS S.A.', 130),
        ],
      );

      final lignes = dataset.latentPnlByIssuer;

      expect(lignes, hasLength(1),
          reason: 'Une seule contrepartie, un seul rang.');
      expect(lignes.single.gain, 50000, reason: '20 000 + 30 000.');
      expect(lignes.single.cost, 200000);
      // Le nom affiché reste une graphie du fichier, jamais la clé technique.
      expect(lignes.single.issuer, isNot(contains('NON RENSEIGNE')));
    });
  });
}
