// Le YTM obligataire se déduit de la courbe des taux, jamais du coupon.
//
// Sans prix de marché dans le fichier importé, le prix est reconstruit en
// actualisant l'échéancier sur la courbe de la zone, puis le YTM est le taux
// unique qui redonne ce prix. Une ligne dont la zone n'est pas reconnue ne
// trouve aucune courbe : elle est actualisée à son propre coupon et ressort
// mécaniquement au pair. Ce cas doit rester signalé, pas silencieux.

import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';

MarketPortfolioRecord _obligation({
  required String zone,
  double coupon = 0.06,
  int maturiteMois = 36,
}) {
  return MarketPortfolioRecord(
    portfolioType: MarketPortfolioType.bonds,
    values: {
      'ID Titre': 'OB-TEST',
      'Emetteur': 'Trésor public',
      'Zone': zone,
      'Devise': 'XOF',
      'Valeur nominale unitaire': 10000,
      'quantités': 1000,
      'Capital initial': 10000000,
      'Coupon (%)': coupon * 100,
      'Profil d\'amortissement': 'In fine',
      'Fréquence de paiement des intérêts': 'Annuelle',
      'Maturité (mois)': maturiteMois,
      'Maturité résiduelle (mois)': maturiteMois,
    },
  );
}

/// Actualisation d'un échéancier in fine sur une courbe donnée, indépendante
/// du code de production : l'attendu doit être calculable à la main.
double _prixSurCourbe({
  required double nominal,
  required double coupon,
  required int annees,
  required List<double> tauxParAnnee,
}) {
  var prix = 0.0;
  for (var t = 1; t <= annees; t++) {
    final flux = nominal * coupon + (t == annees ? nominal : 0);
    prix += flux / _puissance(1 + tauxParAnnee[t - 1], t);
  }
  return prix;
}

double _puissance(double base, int exposant) {
  var resultat = 1.0;
  for (var i = 0; i < exposant; i++) {
    resultat *= base;
  }
  return resultat;
}

/// Taux unique qui reproduit un prix donné, par dichotomie.
double _ytmParDichotomie({
  required double nominal,
  required double coupon,
  required int annees,
  required double prix,
}) {
  var bas = -0.5;
  var haut = 2.0;
  for (var i = 0; i < 200; i++) {
    final milieu = (bas + haut) / 2;
    var valeur = 0.0;
    for (var t = 1; t <= annees; t++) {
      final flux = nominal * coupon + (t == annees ? nominal : 0);
      valeur += flux / _puissance(1 + milieu, t);
    }
    if (valeur > prix) {
      bas = milieu;
    } else {
      haut = milieu;
    }
  }
  return (bas + haut) / 2;
}

void main() {
  group('Logique du YTM de courbe, vérifiée indépendamment', () {
    // Courbe UEMOA aux échéances 1, 2 et 3 ans.
    const courbe = [0.064718, 0.069247, 0.072709];

    test('un titre décoté rend plus que son coupon', () {
      final prix = _prixSurCourbe(
        nominal: 100,
        coupon: 0.06,
        annees: 3,
        tauxParAnnee: courbe,
      );
      final ytm = _ytmParDichotomie(
        nominal: 100,
        coupon: 0.06,
        annees: 3,
        prix: prix,
      );

      expect(prix, lessThan(100));
      expect(ytm, greaterThan(0.06));
      expect(ytm, moreOrLessEquals(0.0725, epsilon: 0.0005));
    });

    test('un titre au pair rend exactement son coupon', () {
      // Courbe plate à 6 % : le prix retombe sur le nominal.
      final prix = _prixSurCourbe(
        nominal: 100,
        coupon: 0.06,
        annees: 3,
        tauxParAnnee: const [0.06, 0.06, 0.06],
      );
      final ytm = _ytmParDichotomie(
        nominal: 100,
        coupon: 0.06,
        annees: 3,
        prix: prix,
      );

      expect(prix, moreOrLessEquals(100, epsilon: 1e-9));
      expect(ytm, moreOrLessEquals(0.06, epsilon: 1e-6));
    });

    test('un titre en prime rend moins que son coupon', () {
      final prix = _prixSurCourbe(
        nominal: 100,
        coupon: 0.09,
        annees: 3,
        tauxParAnnee: courbe,
      );
      final ytm = _ytmParDichotomie(
        nominal: 100,
        coupon: 0.09,
        annees: 3,
        prix: prix,
      );

      expect(prix, greaterThan(100));
      expect(ytm, lessThan(0.09));
    });

    test('le YTM reste encadré par les taux de la courbe traversés', () {
      final prix = _prixSurCourbe(
        nominal: 100,
        coupon: 0.06,
        annees: 3,
        tauxParAnnee: courbe,
      );
      final ytm = _ytmParDichotomie(
        nominal: 100,
        coupon: 0.06,
        annees: 3,
        prix: prix,
      );

      // Aucun taux unique ne peut sortir de l'intervalle des taux qui ont
      // servi à construire le prix.
      expect(ytm, greaterThanOrEqualTo(courbe.first));
      expect(ytm, lessThanOrEqualTo(courbe.last));
    });
  });

  group('Zone du fichier importé', () {
    test('une zone reconnue est exploitable pour aller chercher une courbe',
        () {
      for (final zone in ['UEMOA', 'uemoa', 'Zone UEMOA', 'CEMAC']) {
        final ligne = _obligation(zone: zone);
        expect(ligne.zone.toLowerCase(), contains(zone.toLowerCase().trim()));
      }
    });

    test('une zone absente laisse la ligne sans courbe applicable', () {
      final ligne = MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: {
          'ID Titre': 'OB-SANS-ZONE',
          'Capital initial': 10000000,
          'Coupon (%)': 6,
          'Maturité résiduelle (mois)': 36,
        },
      );

      // Le libellé de repli ne correspond à aucune zone de cotation : c'est
      // exactement le cas qui doit être signalé à l'écran plutôt que produire
      // un titre au pair silencieux.
      expect(ligne.zone, 'Non renseignée');
      final normalisee = ligne.zone.toLowerCase();
      expect(normalisee.contains('uemoa'), isFalse);
      expect(normalisee.contains('cemac'), isFalse);
    });

    test('une zone mal orthographiée ne résout aucune courbe', () {
      final ligne = _obligation(zone: 'UMOA');
      final normalisee = ligne.zone.toLowerCase();
      expect(normalisee.contains('uemoa'), isFalse);
      expect(normalisee.contains('cemac'), isFalse);
    });
  });
}
