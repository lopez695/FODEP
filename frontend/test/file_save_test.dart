// Le nom du fichier produit par un export.
//
// Sur poste de travail, l'extension manquante au chemin choisi rendrait le
// classeur illisible par Excel. Sur le web, ce nom est la seule identite du
// fichier telecharge : le selecteur n'y demande rien et renvoie un chemin
// vide. La regle est la meme des deux cotes, et c'est celle-ci.
import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/shared/utils/file_save.dart';

void main() {
  test('l extension est ajoutee quand elle manque', () {
    expect(
      ensureRequiredFileExtension('FODEP_31122025', '.xlsx'),
      'FODEP_31122025.xlsx',
    );
  });

  test('une extension deja presente n est pas doublee', () {
    expect(
      ensureRequiredFileExtension('rapport_global.pdf', '.pdf'),
      'rapport_global.pdf',
    );
  });

  test('la casse de l extension existante est respectee', () {
    // Windows rend « .XLSX » aussi bien que « .xlsx » : ajouter la seconde
    // produirait « FODEP.XLSX.xlsx ».
    expect(
      ensureRequiredFileExtension('FODEP.XLSX', '.xlsx'),
      'FODEP.XLSX',
    );
  });

  test('le point manquant a l extension demandee est ajoute', () {
    expect(
      ensureRequiredFileExtension('export_expositions', 'xlsx'),
      'export_expositions.xlsx',
    );
  });

  test('une extension vide est refusee', () {
    expect(
      () => ensureRequiredFileExtension('FODEP', '   '),
      throwsArgumentError,
    );
  });
}
