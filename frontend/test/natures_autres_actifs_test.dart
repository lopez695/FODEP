// Les natures d'autres actifs vivent en deux exemplaires : une liste Dart pour
// la saisie à l'écran, une liste Python pour valider la colonne
// « Type_autre_actif » de l'import. Les deux décrivent la même colonne, donc
// toute divergence se paie : une nature absente de la liste Dart est reclassée
// en « Autres éléments d'actifs non définis » dès qu'on modifie la ligne, ce qui
// vide l'EP36 et la norme RA009 sans rien signaler.
//
// Ce test lit la liste Python et vérifie qu'elle correspond. Il échouera à la
// prochaine nature ajoutée d'un seul côté.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:rwa_calculator/modules/expositions/models/exposition_models.dart';

String _sourceDuBackend() => File(
      '../backend/database/services/rwa_calculation_service.py',
    ).readAsStringSync();

/// Nom Python -> libellé, pour les constantes OTHER_ASSET_*_TYPE.
Map<String, String> _constantesDuBackend() {
  final constantes = <String, String>{};
  final motifConstante = RegExp(
    r'^(OTHER_ASSET_\w+_TYPE)\s*=\s*\(?\s*"([^"]+)"',
    multiLine: true,
  );
  for (final trouve in motifConstante.allMatches(_sourceDuBackend())) {
    constantes[trouve.group(1)!] = trouve.group(2)!;
  }
  return constantes;
}

/// Extrait les libellés de OTHER_ASSET_TYPE_OPTIONS du service Python, en
/// résolvant les constantes qu'il énumère.
List<String> _naturesDuBackend() {
  final source = _sourceDuBackend();
  final constantes = _constantesDuBackend();

  final bloc = RegExp(
    r'OTHER_ASSET_TYPE_OPTIONS[^=]*=\s*\(([^)]*)\)',
    dotAll: true,
  ).firstMatch(source);
  expect(bloc, isNotNull,
      reason: 'OTHER_ASSET_TYPE_OPTIONS introuvable dans le service Python.');

  // Découpage par lignes, pas par virgules : les commentaires du bloc en
  // contiennent, et une virgule de prose collerait le nom qui la suit au texte
  // — le libellé disparaîtrait de la comparaison sans faire échouer le test.
  final natures = <String>[];
  for (final brut in bloc!.group(1)!.split('\n')) {
    final ligne = brut.trim();
    if (ligne.isEmpty || ligne.startsWith('#')) continue;
    final nom = ligne.endsWith(',')
        ? ligne.substring(0, ligne.length - 1).trim()
        : ligne;
    if (constantes.containsKey(nom)) natures.add(constantes[nom]!);
  }
  return natures;
}

void main() {
  test('les natures d\'autres actifs sont les mêmes des deux côtés', () {
    final backend = _naturesDuBackend();

    // Le nombre sert de garde-fou : si l'extraction échouait, la comparaison
    // passerait sur une liste vide sans rien prouver.
    expect(backend.length, greaterThanOrEqualTo(13));
    expect(
      backend.toSet().difference(otherAssetTypeOptions.toSet()),
      isEmpty,
      reason: 'Natures que l\'import accepte mais que la saisie ne propose '
          'pas : elles seront reclassées dès qu\'une ligne est modifiée.',
    );
    // L'inverse se paie aussi : une nature proposée à l'écran mais inconnue de
    // l'import fait rejeter le fichier qui la contient.
    expect(
      otherAssetTypeOptions.toSet().difference(backend.toSet()),
      isEmpty,
      reason: 'Natures que la saisie propose mais que l\'import refuse.',
    );
  });

  test('les pondérations de l\'écran sont celles du backend', () {
    // Extraites de lookup_other_asset_risk_weight : l'écran et le calcul
    // transmis doivent donner le même APR, donc le même ratio de solvabilité.
    // Le test backend test_natures_autres_actifs.py confronte, lui, ces mêmes
    // poids aux coefficients de la colonne (b) de l'EP20 du modèle FODEP.
    final source = _sourceDuBackend();

    // Découpe par indexOf plutôt que par expression régulière : le fichier est
    // en CRLF, et un motif écrit en \n n'y accroche pas.
    final debut = source.indexOf('def lookup_other_asset_risk_weight');
    expect(debut, isNot(-1),
        reason: 'lookup_other_asset_risk_weight introuvable.');
    final suivant = source.indexOf('\ndef ', debut + 1);
    final corps = source.substring(debut, suivant == -1 ? null : suivant);

    // Chaque branche « if resolved ... : return X » du service Python, avec les
    // constantes qu'elle cite.
    final attendus = <String, double>{};
    final branches = RegExp(
      r'if resolved\s*(?:==|in)\s*\{?([^}:]+)\}?:\s*\n\s*return ([\d.]+)',
      dotAll: true,
    );
    for (final branche in branches.allMatches(corps)) {
      final poids = double.parse(branche.group(2)!);
      for (final nom in branche.group(1)!.split(',')) {
        final propre = nom.trim();
        if (propre.startsWith('OTHER_ASSET_')) attendus[propre] = poids;
      }
    }
    expect(attendus.length, greaterThanOrEqualTo(6));

    final libelles = _constantesDuBackend();
    for (final entree in attendus.entries) {
      final nature = libelles[entree.key];
      expect(nature, isNotNull, reason: 'Constante ${entree.key} non résolue.');
      expect(
        lookupOtherAssetRiskWeight(nature),
        entree.value,
        reason: '${entree.key} : le backend pondère à ${entree.value}.',
      );
    }

    // Le défaut des deux côtés est 100 % : une nature non citée doit y tomber.
    expect(lookupOtherAssetRiskWeight('Immobilisations corporelles'), 1.0);
  });

  test('la nature qui renseigne l\'EP36 est proposée à la saisie', () {
    // Sans elle, la limite RA009 ne porte que sur les participations
    // immobilières et se déclare « CONFORME » faute d'assiette.
    expect(
      otherAssetTypeOptions,
      contains(otherAssetNonOperatingFixedAssetsType),
    );
    // Et elle doit survivre à un aller-retour par l'écran.
    expect(
      coerceOtherAssetType('Immobilisations hors exploitation'),
      otherAssetNonOperatingFixedAssetsType,
    );
    // Pondérée comme les corporelles : 100 %, ce que l'EP20 attend sur RC265.
    expect(
      lookupOtherAssetRiskWeight(otherAssetNonOperatingFixedAssetsType),
      1.0,
    );
  });
}
