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
/// Il s'ouvre sur la page de garde de la BCEAO, qui est une feuille du classeur
/// comme les autres : son bandeau bleu, les bandes de couleur qui le traversent
/// et le logo de la Banque Centrale. Une déclaration qui ne commence pas par
/// elle ne se reconnaît pas comme un FODEP.
///
/// Le contenu vient du backend, qui l'extrait du fichier qu'il vient d'écrire :
/// le PDF n'est jamais un second calcul.

/// Filet du formulaire. Le classeur ne trace que des traits fins.
const _filet = pw.BorderSide(color: PdfColor.fromInt(0xFF3F3F46), width: 0.35);
const _texteEteint = PdfColor.fromInt(0xFF6B7280);

/// Largeur d'une colonne en points, depuis l'unité d'Excel.
///
/// Excel compte les largeurs en chiffres, et sa conversion en pixels n'est pas
/// une simple proportion : une colonne mesure `largeur × 7 + 5` pixels, les
/// cinq pixels étant la marge que la cellule garde de chaque côté de son texte.
/// Les ignorer ne se voyait pas sur une colonne de trente chiffres, mais les
/// bandes de la page de garde en mesurent moins d'un : sans eux, elles se
/// resserraient jusqu'à se toucher.
///
/// Les pixels d'Excel valent 96 par pouce, les points du PDF 72.
double _points(double largeur) => (largeur * 7 + 5) * 0.75;

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
    .fold<double>(0, (somme, largeur) => somme + _points(largeur));

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
      for (final largeur in etat.largeurs) _points(largeur),
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

pw.TextStyle _style(CelluleFodep cellule, _Mise mise, double largeur) =>
    pw.TextStyle(
      fontSize: _tailleTenantLeMotLePlusLong(cellule, mise, largeur),
      fontWeight: cellule.gras ? pw.FontWeight.bold : pw.FontWeight.normal,
      // Sans elle, la feuille des états à renseigner sort en colonnes de
      // coches et de croix noires, où rien ne distingue au premier coup d'œil
      // ce qui est exigé de ce qui ne l'est pas.
      color: _couleur(cellule.couleur),
    );

/// Largeur moyenne d'un caractere, en part de la taille de police.
///
/// Mesuree sur la police du document. Elle n'a pas a etre exacte : elle sert a
/// savoir si un mot passe, pas a composer la ligne.
const double _largeurMoyenneDuCaractere = 0.55;

/// Taille de police retenue pour que le mot le plus long tienne dans sa case.
///
/// Le classeur mesure ses colonnes en caracteres de sa propre police ; celle du
/// PDF est plus large. Une colonne juste dans Excel devient donc trop etroite
/// ici, et le generateur coupe alors le mot n'importe ou : l'en-tete « N° Etat
/// prudentiel » se lisait « prudentie / l ». Reduire la cellule de ce qu'il
/// faut vaut mieux qu'un mot brise -- c'est d'ailleurs ce que fait Excel quand
/// il ajuste une impression a la page.
///
/// La reduction ne descend jamais sous la taille minimale du document, et ne
/// s'applique qu'a la cellule concernee : une colonne etroite ne rapetisse pas
/// tout l'etat.
double _tailleTenantLeMotLePlusLong(
  CelluleFodep cellule,
  _Mise mise,
  double largeur,
) {
  final taille = mise.taille(cellule);
  if (largeur <= 0 || cellule.texte.isEmpty) return taille;

  var plusLong = 0;
  for (final mot in cellule.texte.split(RegExp(r'\s+'))) {
    if (mot.length > plusLong) plusLong = mot.length;
  }
  if (plusLong == 0) return taille;

  // La cellule garde deux points de marge de chaque cote.
  final disponible = largeur - 4;
  if (disponible <= 0) return taille;

  final tenable = disponible / (plusLong * _largeurMoyenneDuCaractere);
  return tenable >= taille ? taille : tenable.clamp(_tailleMinimale, taille);
}

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

/// Hauteur retenue pour une image dont le classeur ne règle pas ses lignes.
const double _hauteurImageParDefaut = 60;

/// Ce que la cellule montre : son texte, ou l'image qui y est ancrée.
///
/// Le logo de la BCEAO tient la moitié de la page de garde. Il est ancré sur
/// une plage de cellules ; c'est la hauteur de cette plage qui le dimensionne,
/// comme dans le classeur, et non sa définition en pixels — sans quoi une image
/// de mille cent pixels de large sortirait de la feuille.
/// Les icônes du classeur, tracées et non écrites.
///
/// Excel ne pose pas un caractère : il dessine un symbole plein, épais, vert
/// ou rouge. Aucune police du document n'en porte l'équivalent — ni Aptos ni
/// IBM Plex Sans n'ont la coche grasse U+2714 — et agrandir la coche maigre
/// U+2713 ne la remplit pas : elle reste un trait de plume à côté du symbole
/// du classeur. Deux traits suffisent à la reproduire, et le trait a la
/// largeur qu'on veut.
pw.Widget _icone(String nature, PdfColor couleur, double taille) {
  final cote = taille * 1.15;
  final epaisseur = cote * 0.17;

  return pw.CustomPaint(
    size: PdfPoint(cote, cote),
    painter: (canvas, size) {
      canvas
        ..setStrokeColor(couleur)
        ..setLineWidth(epaisseur)
        ..setLineCap(PdfLineCap.round)
        ..setLineJoin(PdfLineJoin.round);

      final l = size.x;
      final h = size.y;
      if (nature == 'valide') {
        // Une coche : la descente courte, puis la longue montée.
        canvas
          ..moveTo(l * 0.16, h * 0.52)
          ..lineTo(l * 0.40, h * 0.24)
          ..lineTo(l * 0.86, h * 0.76);
      } else {
        // Une croix, ou le point d'exclamation du jeu à trois symboles, tracé
        // comme une barre verticale : dans les deux cas, deux segments.
        final aigu = nature == 'alerte';
        canvas
          ..moveTo(aigu ? l * 0.5 : l * 0.22, aigu ? h * 0.86 : h * 0.22)
          ..lineTo(aigu ? l * 0.5 : l * 0.78, aigu ? h * 0.34 : h * 0.78)
          ..moveTo(aigu ? l * 0.5 : l * 0.22, aigu ? h * 0.16 : h * 0.78)
          ..lineTo(aigu ? l * 0.5 : l * 0.78, aigu ? h * 0.14 : h * 0.22);
      }
      canvas.strokePath();
    },
  );
}

pw.Widget _contenuDeCellule(
  CelluleFodep cellule,
  _Mise mise,
  double hauteur, {
  double largeur = 0,
}) {
  final nature = cellule.icone;
  final teinte = _couleur(cellule.couleur);
  if (nature != null && teinte != null) {
    return _icone(nature, teinte, mise.taille(cellule));
  }

  final image = cellule.image;
  if (image == null) {
    return pw.Text(
      cellule.texte,
      textAlign: _cadrage(cellule),
      style: _style(cellule, mise, largeur),
    );
  }
  return pw.SizedBox(
    height: hauteur > 0 ? hauteur : _hauteurImageParDefaut,
    child: pw.Image(pw.MemoryImage(image), fit: pw.BoxFit.contain),
  );
}

/// Place du titre dans la largeur de l'état, en points.
///
/// Un titre déborde vers la droite, mais il commence où le classeur l'a écrit :
/// celui de la page de garde est en troisième colonne, après un tiers de la
/// feuille, et le coller à la marge le déplaçait de trois centimètres.
///
/// Le décalage est abandonné s'il ne laisse pas de quoi écrire — dix fois la
/// taille du texte, soit une dizaine de caractères par ligne. C'est la
/// situation qui faisait paginer sans fin : un intitulé plus long que la place
/// qui lui reste se replie lettre par lettre, et le générateur produit des
/// pages jusqu'à lever.
double _decalage(LigneFodep ligne, _Mise mise) {
  var colonne = 0;
  var decalage = 0.0;
  for (final cellule in ligne.cellules) {
    if (cellule.texte.isNotEmpty) break;
    for (var i = colonne;
        i < colonne + (cellule.colonnes < 1 ? 1 : cellule.colonnes) &&
            i < mise.colonnes.length;
        i++) {
      decalage += mise.colonnes[i];
    }
    colonne += cellule.colonnes < 1 ? 1 : cellule.colonnes;
  }

  final totale = mise.colonnes.fold<double>(0, (somme, l) => somme + l);
  final requise = 10 * mise.taille(ligne.cellules.firstWhere(
        (cellule) => cellule.texte.isNotEmpty,
        orElse: () => const CelluleFodep(),
      ));
  return totale - decalage >= requise ? decalage : 0;
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
      ligne.cellules.every((c) => c.bordures.isEmpty && c.image == null);

  final hauteur = (ligne.hauteur ?? 0) * mise.facteur;

  if (titre) {
    final cellule = porteuses.first;
    return pw.Container(
      width: double.infinity,
      constraints: pw.BoxConstraints(minHeight: hauteur),
      padding: pw.EdgeInsets.only(left: _decalage(ligne, mise), top: 2, bottom: 2),
      alignment: _alignement(cellule),
      child: pw.Text(
        cellule.texte,
        textAlign: _cadrage(cellule),
        // Un titre court sur toute la largeur de la page : aucune colonne ne
        // le contraint, sa taille reste celle du classeur.
        style: _style(cellule, mise, 0),
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
            suivante.bordures.isNotEmpty ||
            suivante.image != null) {
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
        child: _contenuDeCellule(cellule, mise, hauteur, largeur: largeur),
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
