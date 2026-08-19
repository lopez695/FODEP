import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../rapports/models/report_models.dart';

/// Imprime le FODEP en PDF, état par état.
///
/// Le document est le classeur imprimé, pas une mise en page inventée : mêmes
/// lignes, mêmes colonnes à leur largeur, mêmes fusions, mêmes intitulés en
/// gras — et, désormais, la forme que le formulaire porte réellement. Le fond
/// ambre de ses cases à renseigner, ses filets là où il en trace et nulle part
/// ailleurs, ses en-têtes centrés, ses titres à leur taille. La version
/// précédente ramenait tout à une grille grise uniforme en corps 6,5 : la
/// déclaration s'y lisait, mais on n'y reconnaissait aucune page du formulaire.
///
/// L'orientation et les lignes à répéter en haut de chaque page sont celles que
/// le classeur règle lui-même : dix-neuf de ses états sont en portrait, et
/// l'EP30 rappelle son en-tête sur chacune de ses pages.
///
/// Le contenu vient du backend, qui l'extrait du fichier qu'il vient d'écrire :
/// le PDF n'est jamais un second calcul.

/// Filet du formulaire. Le classeur ne trace que des traits fins.
const _filet = pw.BorderSide(color: PdfColor.fromInt(0xFF3F3F46), width: 0.35);
const _texteEteint = PdfColor.fromInt(0xFF6B7280);

/// Une unité de largeur d'Excel — la largeur d'un chiffre — vaut environ ce
/// nombre de points.
const double _pointsParCaractere = 5.25;

/// Marges gauche et droite cumulées.
const double _margesHorizontales = 40;

/// Taille retenue quand le classeur n'en déclare pas.
const double _tailleParDefaut = 10;

/// En deçà, le texte n'est plus lisible : l'état le plus large s'y arrête.
const double _tailleMinimale = 4.5;

/// Réduction en dessous de laquelle on préfère une feuille plus grande.
///
/// Le corps du formulaire est en 10 : à 0,42 il tombe à 4,2 points, la limite
/// de ce qui se lit encore. Les états qui n'y tiennent pas s'impriment sur une
/// feuille plus grande plutôt qu'en caractères illisibles — c'est aussi ce
/// qu'on ferait du classeur.
const double _reductionPlancher = 0.42;

/// Formats disponibles, du plus courant au plus large.
const _a3Paysage = PdfPageFormat(1190.55, 841.89);
const _a2Paysage = PdfPageFormat(1683.78, 1190.55);

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
    final format = _format(etat);
    final mise = _Mise.pour(etat, format);
    final entetes = etat.entetes;
    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 22),
        // Le générateur s'arrête à 20 pages par défaut, et lève. Un seul état
        // peut en demander davantage — l'EP30 porte plus de cent lignes.
        maxPages: 200,
        // Réimprimé en haut de chaque page, comme le classeur le demande : une
        // deuxième page qui ne rappelle ni l'état ni ses colonnes ne se lit
        // pas.
        header: entetes.isEmpty
            ? null
            : (contexte) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    for (final ligne in entetes) _ligne(ligne, mise),
                    pw.SizedBox(height: 4),
                  ],
                ),
        footer: (contexte) => _pied(etat.nom, contexte),
        build: (contexte) => [
          for (final ligne in etat.corps) _ligne(ligne, mise),
        ],
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

/// Nom de l'état et pagination, comme le pied d'impression d'un classeur.
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

/// Largeur naturelle de l'état, en points, telle que le classeur la règle.
double _largeurNaturelle(EtatFodep etat) => etat.largeurs
    .fold<double>(0, (somme, largeur) => somme + largeur * _pointsParCaractere);

/// Feuille sur laquelle imprimer l'état.
///
/// L'orientation vient du classeur. Le format aussi, tant que l'état y tient
/// sans devenir illisible : cinq états du FODEP sont trop larges pour une A4 —
/// l'EP07 porte cinquante-quatre colonnes — et les y forcer donnait un corps
/// de deux points et demi. Ils passent alors sur une feuille plus grande.
PdfPageFormat _format(EtatFodep etat) {
  final naturelle = _largeurNaturelle(etat);
  final formats = [
    etat.paysage ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
    _a3Paysage,
    _a2Paysage,
  ];
  for (final format in formats) {
    if (naturelle <= 0 ||
        (format.width - _margesHorizontales) / naturelle >= _reductionPlancher) {
      return format;
    }
  }
  return formats.last;
}

/// Mise en page d'un état : largeurs de colonnes et réduction d'ensemble.
///
/// Le classeur donne à ses colonnes une largeur en caractères ; l'état le plus
/// large dépasse la page. Excel le réduit alors pour l'y faire tenir, et il
/// réduit tout ensemble — colonnes ET texte. C'est ce rapport conservé qui
/// évite qu'un intitulé se coupe au milieu d'un mot dans une colonne rétrécie
/// sous lui : « Code DISPRU » se lisait « Code DISPR / U ».
///
/// Un état qui tient déjà dans la page n'est pas étiré : ses colonnes gardent
/// leur largeur et son texte sa taille, comme à l'impression du classeur.
class _Mise {
  const _Mise(this.colonnes, this.facteur);

  factory _Mise.pour(EtatFodep etat, PdfPageFormat format) {
    final colonnes = [
      for (final largeur in etat.largeurs) largeur * _pointsParCaractere,
    ];
    final naturelle = colonnes.fold<double>(0, (somme, l) => somme + l);
    final disponible = format.width - _margesHorizontales;
    final facteur =
        naturelle <= disponible ? 1.0 : disponible / naturelle;
    return _Mise([for (final l in colonnes) l * facteur], facteur);
  }

  /// Largeur de chaque colonne, en points, réduction comprise.
  final List<double> colonnes;

  /// Réduction appliquée pour tenir la page, de 0,5 à 1.
  final double facteur;

  double taille(CelluleFodep cellule) =>
      ((cellule.taille ?? _tailleParDefaut) * facteur)
          .clamp(_tailleMinimale, 24.0);
}

pw.TextStyle _style(CelluleFodep cellule, _Mise mise) => pw.TextStyle(
      fontSize: mise.taille(cellule),
      fontWeight: cellule.gras ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

pw.TextAlign _cadrage(CelluleFodep cellule) {
  if (cellule.droite) return pw.TextAlign.right;
  return cellule.centre ? pw.TextAlign.center : pw.TextAlign.left;
}

pw.Alignment _alignement(CelluleFodep cellule) {
  if (cellule.droite) return pw.Alignment.centerRight;
  return cellule.centre ? pw.Alignment.center : pw.Alignment.centerLeft;
}

PdfColor? _couleur(String? rvb) {
  if (rvb == null || rvb.length != 6) return null;
  try {
    return PdfColor.fromHex(rvb);
  } catch (_) {
    // Une couleur illisible n'a pas à faire échouer une déclaration.
    return null;
  }
}

/// Le fond et les filets de la cellule, tels que le classeur les porte.
pw.BoxDecoration _decor(CelluleFodep cellule) {
  final cotes = cellule.bordures;
  return pw.BoxDecoration(
    color: _couleur(cellule.fond),
    border: cotes.isEmpty
        ? null
        : pw.Border(
            left: cotes.contains('l') ? _filet : pw.BorderSide.none,
            right: cotes.contains('r') ? _filet : pw.BorderSide.none,
            top: cotes.contains('t') ? _filet : pw.BorderSide.none,
            bottom: cotes.contains('b') ? _filet : pw.BorderSide.none,
          ),
  );
}

pw.Widget _ligne(LigneFodep ligne, _Mise mise) {
  // Une ligne sans aucun filet, portant un seul texte : c'est un titre d'état
  // ou un intitulé de section, pas une ligne de tableau. Le formulaire ne les
  // encadre pas, et Excel les laisse déborder sur les colonnes vides à leur
  // droite. Les faire passer par la grille les comprimerait dans leur seule
  // colonne — la page de garde y logeait un titre de vingt-deux points dans
  // une colonne large de deux caractères, que le générateur n'arrivait plus à
  // paginer.
  final porteuses = ligne.cellules.where((c) => c.texte.isNotEmpty);
  final titre = porteuses.length == 1 &&
      ligne.cellules.every((c) => c.bordures.isEmpty);

  final hauteur = (ligne.hauteur ?? 0) * mise.facteur;

  if (titre) {
    final cellule = porteuses.first;
    return pw.Container(
      width: double.infinity,
      constraints: pw.BoxConstraints(minHeight: hauteur),
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      alignment: _alignement(cellule),
      child: pw.Text(
        cellule.texte,
        textAlign: _cadrage(cellule),
        style: _style(cellule, mise),
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
  for (var index = 0; index < ligne.cellules.length; index++) {
    final cellule = ligne.cellules[index];
    var portee = cellule.colonnes < 1 ? 1 : cellule.colonnes;

    // Un texte plus long que sa colonne déborde sur les cases vides à sa
    // droite : c'est ce que fait Excel, et c'est ainsi que l'attestation est
    // écrite — « ÉTABLISSEMENT : » tient dans une colonne large de deux
    // caractères, suivie de cases libres. Sans cette règle, le libellé se
    // repliait lettre par lettre. Une case qui porte un texte, un fond ou un
    // filet arrête le débordement : elle a quelque chose à montrer.
    if (cellule.texte.isNotEmpty) {
      while (index + 1 < ligne.cellules.length) {
        final suivante = ligne.cellules[index + 1];
        if (suivante.texte.isNotEmpty ||
            suivante.fond != null ||
            suivante.bordures.isNotEmpty) {
          break;
        }
        portee += suivante.colonnes < 1 ? 1 : suivante.colonnes;
        index++;
      }
    }

    var largeur = 0.0;
    for (var i = colonne;
        i < colonne + portee && i < mise.colonnes.length;
        i++) {
      largeur += mise.colonnes[i];
    }
    if (largeur == 0) {
      largeur = mise.colonnes.isEmpty ? 40 : mise.colonnes.first;
    }
    colonne += portee;

    largeurs[cellules.length] = pw.FixedColumnWidth(largeur);
    cellules.add(
      pw.Container(
        // La hauteur du classeur est un minimum, pas un carcan : un intitule
        // qui demande deux lignes les prend, comme dans le formulaire.
        constraints: pw.BoxConstraints(minHeight: hauteur),
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
        decoration: _decor(cellule),
        alignment: _alignement(cellule),
        child: pw.Text(
          cellule.texte,
          textAlign: _cadrage(cellule),
          style: _style(cellule, mise),
        ),
      ),
    );
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
