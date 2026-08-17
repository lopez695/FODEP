import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../rapports/models/report_models.dart';

/// Imprime le FODEP en PDF, état par état.
///
/// Le document reproduit le classeur : ses lignes, ses colonnes à leur largeur,
/// ses cellules fusionnées, ses intitulés en gras, ses montants cadrés à droite.
/// Rien d'autre — ni page de garde, ni bandeaux, ni encadrés d'explication : ce
/// qui ne figure pas dans le formulaire n'a pas à figurer dans son impression.
///
/// Un état par page, comme à l'impression du classeur. Le contenu vient du
/// backend, qui l'extrait du fichier qu'il vient d'écrire : le PDF n'est jamais
/// un second calcul.
const _filet = PdfColor.fromInt(0xFF9CA3AF);
const _texteEteint = PdfColor.fromInt(0xFF6B7280);

/// Corps de texte du formulaire imprimé. Les états les plus larges portent
/// quatorze colonnes : au-delà de cette taille, ils ne tiennent plus la page.
const double _corps = 6.5;

Future<Uint8List> construireFodepPdf({
  required ContenuFodep contenu,
  DateTime? genereLe,
}) async {
  final theme = await _theme();
  final document = pw.Document(
    title: contenu.nomFichier,
    subject: 'Formulaire de déclaration prudentielle (FODEP)',
    theme: theme,
  );

  for (final etat in contenu.etats) {
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 22),
        // Le générateur s'arrête à 20 pages par défaut, et lève. Un seul état
        // peut en demander davantage — l'EP30 porte plus de cent lignes.
        maxPages: 200,
        footer: (contexte) => _pied(etat.nom, contexte),
        build: (contexte) => _lignes(etat),
      ),
    );
  }

  // Un classeur sans aucune ligne ne doit pas produire un fichier illisible.
  if (contenu.etats.isEmpty) {
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (contexte) => pw.Center(
          child: pw.Text(
            'Aucun état renseigné.',
            style: const pw.TextStyle(fontSize: 10, color: _texteEteint),
          ),
        ),
      ),
    );
  }

  return Uint8List.fromList(await document.save());
}

/// Nom de l'état et pagination, comme l'en-tête d'impression d'un classeur.
pw.Widget _pied(String etat, pw.Context contexte) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(etat,
              style: const pw.TextStyle(fontSize: 7, color: _texteEteint)),
          pw.Text(
            '${contexte.pageNumber} / ${contexte.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: _texteEteint),
          ),
        ],
      ),
    );

/// Les lignes de l'état, chacune enfant direct de la page : c'est ainsi que le
/// générateur peut couper entre deux lignes plutôt qu'au milieu d'une.
List<pw.Widget> _lignes(EtatFodep etat) {
  final poids = _poids(etat.largeurs);
  return [
    for (final ligne in etat.lignes) _ligne(ligne, poids),
  ];
}

/// Poids relatifs des colonnes, tirés de leurs largeurs dans le classeur.
///
/// `pw.Expanded` ne prend qu'un entier : les largeurs d'Excel sont donc mises à
/// l'échelle. Sans elles, toutes les colonnes seraient égales et l'intitulé d'un
/// poste deviendrait aussi étroit que la colonne d'un code DISPRU.
List<int> _poids(List<double> largeurs) => [
      for (final largeur in largeurs)
        (largeur * 10).round().clamp(10, 1000).toInt(),
    ];

pw.Widget _ligne(LigneFodep ligne, List<int> poids) {
  // Une cellule fusionnée sur toute la largeur, seule porteuse de texte : c'est
  // un titre d'état ou un intitulé de section. Le formulaire ne les encadre pas.
  final porteuses = ligne.cellules.where((c) => c.texte.isNotEmpty);
  final titre = porteuses.length == 1 &&
      ligne.cellules.any((c) => c.texte.isNotEmpty && c.colonnes >= 3);

  if (titre) {
    final cellule = porteuses.first;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text(
        cellule.texte,
        style: pw.TextStyle(
          fontSize: _corps,
          fontWeight: cellule.gras ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // Un tableau d'une seule ligne, plutôt qu'une Row : c'est lui qui donne à
  // toutes ses cellules la hauteur de la plus haute, condition pour que les
  // filets s'alignent. Une Row en `stretch` force une hauteur infinie, et le
  // générateur PDF n'a pas d'IntrinsicHeight.
  //
  // Une largeur de colonne par cellule, et non par colonne du formulaire : une
  // cellule fusionnée sur trois colonnes en cumule les largeurs, comme dans le
  // classeur.
  final largeurs = <int, pw.TableColumnWidth>{};
  final cellules = <pw.Widget>[];
  var colonne = 0;
  for (final cellule in ligne.cellules) {
    final portee = cellule.colonnes < 1 ? 1 : cellule.colonnes;
    var flex = 0;
    for (var i = colonne; i < colonne + portee && i < poids.length; i++) {
      flex += poids[i];
    }
    if (flex == 0) flex = poids.isEmpty ? 10 : poids.first;
    colonne += portee;

    largeurs[cellules.length] = pw.FlexColumnWidth(flex.toDouble());
    cellules.add(
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.5),
        decoration: const pw.BoxDecoration(
          border: pw.Border.fromBorderSide(
            pw.BorderSide(color: _filet, width: 0.25),
          ),
        ),
        alignment:
            cellule.droite ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          cellule.texte,
          textAlign: cellule.droite ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: _corps,
            fontWeight: cellule.gras ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Les colonnes que la ligne n'atteint pas restent vides et sans filet : le
  // formulaire n'y trace rien non plus.
  var reste = 0;
  for (var i = colonne; i < poids.length; i++) {
    reste += poids[i];
  }
  if (reste > 0) {
    largeurs[cellules.length] = pw.FlexColumnWidth(reste.toDouble());
    cellules.add(pw.SizedBox());
  }

  return pw.Table(
    columnWidths: largeurs,
    children: [
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.full,
        children: cellules,
      ),
    ],
  );
}

/// Polices du document, chargées depuis les ressources de l'application.
///
/// Indispensable : la police intégrée du générateur PDF ne connaît que le
/// latin-1. Les intitulés du formulaire portent des apostrophes typographiques,
/// des tirets cadratins et des espaces fines insécables dans les montants —
/// autant de caractères qui ressortiraient en carrés sur un document destiné à
/// être visé.
///
/// Si le chargement échoue, le document se fait quand même avec la police
/// intégrée : un export dégradé vaut mieux qu'un export impossible.
Future<pw.ThemeData?> _theme() async {
  try {
    final normale = pw.Font.ttf(await rootBundle.load(_policeNormale));
    final gras = pw.Font.ttf(await rootBundle.load(_policeGrasse));
    return pw.ThemeData.withFont(base: normale, bold: gras);
  } catch (_) {
    return null;
  }
}

const _policeNormale = 'assets/fonts/Aptos.ttf';
const _policeGrasse = 'assets/fonts/Aptos-Bold.ttf';
