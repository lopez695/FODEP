// L'unité choisie en haut de l'écran (k, M, Md) doit valoir partout.
//
// Plusieurs écrans écrivaient leurs montants avec un « M » ou un « Md » figé :
// le sélecteur changeait le tableau de bord, pas le registre des dérivés ni les
// limites de participations. Ils passent tous par `AppFormatters.montant`, et
// c'est lui que ces essais tiennent.

import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/core/utils/currency_conversion.dart';
import 'package:rwa_calculator/core/utils/formatters.dart';

void main() {
  tearDown(() => PortfolioAmountUnitPreference.current =
      PortfolioAmountUnit.billion);

  test("le montant suit l'unité choisie", () {
    PortfolioAmountUnitPreference.current = PortfolioAmountUnit.billion;
    expect(AppFormatters.montant(12500000000), endsWith(' Md'));

    PortfolioAmountUnitPreference.current = PortfolioAmountUnit.million;
    expect(AppFormatters.montant(12500000000), endsWith(' M'));

    PortfolioAmountUnitPreference.current = PortfolioAmountUnit.thousand;
    expect(AppFormatters.montant(12500000000), endsWith(' k'));
  });

  test("un petit montant descend d'un cran plutôt que d'afficher zéro", () {
    // 28 M lus en milliards feraient « 0 Md » à deux décimales.
    PortfolioAmountUnitPreference.current = PortfolioAmountUnit.billion;
    final texte = AppFormatters.montant(2800000);
    expect(texte, endsWith(' M'));
    expect(texte, isNot(startsWith('0')));
  });

  test("zéro reste zéro dans l'unité choisie", () {
    PortfolioAmountUnitPreference.current = PortfolioAmountUnit.million;
    expect(AppFormatters.montant(0), '0 M');
  });

  test("le libellé d'en-tête nomme l'unité choisie", () {
    PortfolioAmountUnitPreference.current = PortfolioAmountUnit.billion;
    expect(AppFormatters.libelleUnite(), 'Milliards de FCFA');
    PortfolioAmountUnitPreference.current = PortfolioAmountUnit.million;
    expect(AppFormatters.libelleUnite('EUR'), 'Millions de EUR');
  });
}
