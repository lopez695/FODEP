// L'onglet VaR historique expose une méthode et un cas chiffré, pas une
// erreur.
//
// Deux exigences qui se tiennent :
//   - les VaR paramétrique et Monte-Carlo n'ont besoin d'aucun historique ;
//     leur proposer un import de prix envoyait chercher un fichier inutile ;
//   - le cas chiffré affiché doit être exact. Un exemple pédagogique faux est
//     pire qu'une absence d'exemple : il s'apprend.
//
// Le calcul du cas est refait ici indépendamment de l'écran.

import 'package:flutter_test/flutter_test.dart';

/// Quantile empirique d'une série de pertes classées par ordre décroissant,
/// recalculé sans dépendre du code de l'écran.
({int rang, double var_, double perteMoyenneAuDela}) _quantileEmpirique({
  required List<double> pertesDecroissantes,
  required int nbSeances,
  required double confiance,
}) {
  final rang = (nbSeances * (1 - confiance)).ceil();
  final retenues = pertesDecroissantes.take(rang).toList(growable: false);
  return (
    rang: rang,
    var_: pertesDecroissantes[rang - 1],
    perteMoyenneAuDela:
        retenues.reduce((a, b) => a + b) / retenues.length,
  );
}

void main() {
  // Série affichée par le panneau : dix pires séances sur 250, en millions.
  const pertes = <double>[412, 388, 351, 297, 264, 241, 228, 219, 203, 197];

  group('Cas chiffré du panneau', () {
    test('le rang du quantile à 99 % sur 250 séances vaut 3', () {
      final resultat = _quantileEmpirique(
        pertesDecroissantes: pertes,
        nbSeances: 250,
        confiance: 0.99,
      );

      // 250 x 0,01 = 2,5, arrondi au supérieur.
      expect(resultat.rang, 3);
    });

    test('la VaR affichée est bien la 3ᵉ perte du classement', () {
      final resultat = _quantileEmpirique(
        pertesDecroissantes: pertes,
        nbSeances: 250,
        confiance: 0.99,
      );

      expect(resultat.var_, 351);
    });

    test('la perte moyenne au-delà du seuil est la moyenne des rangs 1 à 3',
        () {
      final resultat = _quantileEmpirique(
        pertesDecroissantes: pertes,
        nbSeances: 250,
        confiance: 0.99,
      );

      // (412 + 388 + 351) / 3 = 383,67, affiché arrondi à 384.
      expect(resultat.perteMoyenneAuDela, moreOrLessEquals(383.6667, epsilon: 0.001));
      expect(resultat.perteMoyenneAuDela.toStringAsFixed(0), '384');
    });

    test('la perte moyenne au-delà dépasse toujours la VaR', () {
      final resultat = _quantileEmpirique(
        pertesDecroissantes: pertes,
        nbSeances: 250,
        confiance: 0.99,
      );

      // Propriété structurelle : la moyenne de la queue ne peut pas être
      // inférieure au seuil qui la définit. Un exemple qui violerait cela
      // enseignerait une contre-vérité.
      expect(resultat.perteMoyenneAuDela, greaterThan(resultat.var_));
    });

    test('la série présentée est bien classée par ordre décroissant', () {
      for (var i = 1; i < pertes.length; i++) {
        expect(
          pertes[i],
          lessThanOrEqualTo(pertes[i - 1]),
          reason: 'La perte de rang ${i + 1} doit être inférieure ou égale à '
              'celle de rang $i',
        );
      }
    });

    test('exactement deux séances dépassent le seuil retenu', () {
      final resultat = _quantileEmpirique(
        pertesDecroissantes: pertes,
        nbSeances: 250,
        confiance: 0.99,
      );
      final auDela = pertes.where((p) => p > resultat.var_).length;

      // La lecture affichée à l'écran annonce « deux séances seulement ».
      expect(auDela, 2);
    });
  });

  group('Robustesse du quantile', () {
    test('un seuil à 95 % descend plus loin dans le classement qu\'un 99 %',
        () {
      final rang99 = (250 * (1 - 0.99)).ceil();
      final rang95 = (250 * (1 - 0.95)).ceil();

      // Moins exigeant sur la confiance, donc plus profond dans le
      // classement, donc une VaR plus faible : la série étant décroissante,
      // un rang plus profond ne peut pas donner une perte plus lourde.
      expect(rang99, 3);
      expect(rang95, 13);
      expect(rang95, greaterThan(rang99));
    });

    test('une VaR à 97,5 % se situe entre celles à 95 % et 99 %', () {
      final rang975 = (250 * (1 - 0.975)).ceil();

      expect(rang975, 7);
      // Rang intermédiaire, donc perte intermédiaire dans une série
      // décroissante.
      expect(pertes[rang975 - 1], lessThan(pertes[2]));
    });

    test('sur un échantillon trop court, la VaR se confond avec le maximum',
        () {
      // C'est l'argument affiché pour exiger 250 séances : sous 100
      // observations, le rang à 99 % tombe sur la toute première.
      final rang = (60 * (1 - 0.99)).ceil();

      expect(rang, 1);
      expect(pertes[rang - 1], pertes.reduce((a, b) => a > b ? a : b));
    });
  });
}
