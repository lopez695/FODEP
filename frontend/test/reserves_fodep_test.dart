// Les réserves de lecture d'une déclaration, et ce qu'elles attendent.
//
// L'écran les affichait d'affilée sous une même consigne — « complétez-les à
// la main avant de déposer la déclaration ». Or on ne complète pas à la main
// une convention de report, ni un poste que l'établissement ne détient pas :
// les deux ou trois remarques qui appelaient vraiment un geste se noyaient
// dans les autres. Chacune porte donc sa nature, et c'est elle qui décide de
// la place que l'écran lui donne.
//
// Une réserve mal étiquetée doit remonter, jamais disparaître : le risque
// n'est pas d'en montrer une de trop, c'est d'en taire une.
import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/rapports/models/report_models.dart';

void main() {
  test('une réserve typée garde sa nature et son message', () {
    final reserve = ReserveFodep.depuisJson(<String, dynamic>{
      'nature': 'convention',
      'message': 'Les déductions AT1 sont déclarées sur la ligne FPI27.',
    });

    expect(reserve.nature, NatureReserve.convention);
    expect(reserve.message, contains('FPI27'));
  });

  test('les trois natures du backend sont reconnues', () {
    for (final (code, attendue) in const [
      ('a_verifier', NatureReserve.aVerifier),
      ('convention', NatureReserve.convention),
      ('information', NatureReserve.information),
    ]) {
      expect(NatureReserve.depuis(code), attendue, reason: code);
    }
  });

  test('une nature inconnue est traitée comme une vérification', () {
    // Un backend plus récent que l'écran ne doit pas faire disparaître une
    // remarque dans un groupe replié : elle remonte en tête de liste.
    final reserve = ReserveFodep.depuisJson(<String, dynamic>{
      'nature': 'discordance',
      'message': 'EP03 et le tableau de bord ne concordent pas.',
    });

    expect(reserve.nature, NatureReserve.aVerifier);
    expect(reserve.message, contains('concordent'));
  });

  test('une réserve transmise en texte brut reste lisible', () {
    // Les versions antérieures envoyaient une simple liste de chaînes. Un
    // poste de travail dont le backend n'a pas encore été relancé sert encore
    // ce format : ses réserves doivent arriver, faute de quoi la déclaration
    // se transmettrait sans elles.
    final reserve = ReserveFodep.depuisJson(
      'EP36 : aucune immobilisation hors exploitation.',
    );

    expect(reserve.nature, NatureReserve.aVerifier);
    expect(reserve.message, startsWith('EP36'));
  });

  test('une réserve vide ne fait pas échouer la lecture', () {
    expect(ReserveFodep.depuisJson(null).message, isEmpty);
    expect(
      ReserveFodep.depuisJson(<String, dynamic>{'nature': 'convention'}).message,
      isEmpty,
    );
  });
}
