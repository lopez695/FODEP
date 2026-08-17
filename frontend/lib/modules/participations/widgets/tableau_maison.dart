/// Grille commune des tableaux de l'onglet Portefeuille.
///
/// Les expositions NPL, les groupes de clients liés et les limites sur les
/// participations se lisent sur le même écran. Leur donner trois allures
/// obligerait le lecteur à réapprendre la grille à chaque bloc : ces
/// primitives tiennent la règle en un seul endroit.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

const Color tableauEntete = Color(0xFF001F4E);
const Color tableauBordure = Color(0xFFDCE4F2);
const Color tableauLigneAlternee = Color(0xFFF8FAFC);
const Color tableauTexteFort = Color(0xFF1E293B);

/// Largeur de la colonne de tête, celle du rang ou du code.
const double tableauLargeurRang = 34;

/// Contenu d'une cellule, avec le retrait propre à la colonne de tête.
Widget _contenu({required Widget enfant, required bool colonneDeTete}) {
  return Container(
    padding: colonneDeTete
        ? const EdgeInsets.only(left: 12, top: 10, bottom: 10)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    alignment: Alignment.centerLeft,
    child: enfant,
  );
}

/// Une cellule et son filet, à poser directement dans la ligne.
///
/// La fonction rend une liste plutôt qu'un widget : un `Expanded` doit être
/// l'enfant direct de la `Row` qui le mesure. L'envelopper dans une `Row`
/// intermédiaire lui donnerait une largeur infinie à répartir, ce que Flutter
/// refuse — la mise en page échouerait au premier rendu.
List<Widget> celluleTableau({
  required Widget enfant,
  int? flex,
  double? largeur,
}) {
  final cellule = _contenu(
    enfant: enfant,
    colonneDeTete: largeur == tableauLargeurRang,
  );
  return [
    if (largeur != null)
      SizedBox(width: largeur, child: cellule)
    else
      Expanded(flex: flex ?? 1, child: cellule),
    Container(width: 0.5, color: tableauBordure),
  ];
}

/// Description d'une colonne : son intitulé et sa largeur.
typedef ColonneTableau = ({String libelle, int? flex, double? largeur});

/// Bouton de barre de titre des pages du portefeuille.
///
/// Toujours une icône *et* son libellé : les barres de titre de l'application
/// n'utilisent pas d'icônes muettes, une flèche seule obligeant à survoler pour
/// savoir ce qu'elle fait.
///
/// Une pastille teintée plutôt qu'un cadre : dans une barre de titre déjà
/// claire, un contour dur découpe un rectangle qui pèse plus que l'action qu'il
/// porte. Le fond léger suffit à dire que c'est cliquable, et l'effet de survol
/// de Material fait le reste.
///
/// Sauf pour l'action qui écrit. Retour, recalcul et navigation ne changent rien
/// aux données ; la saisie, si. Les afficher toutes du même poids obligeait à
/// lire les trois libellés pour trouver la seule qui compte : `principal`
/// remplit la pastille, seule note saturée d'une barre pâle, et l'œil y va sans
/// lire.
///
/// Le remplissage suit la règle du dialogue de saisie, qui est la référence du
/// module : la couleur d'accent vient du thème — `FilledButton` sans couleur
/// forcée — et le bleu marine reste réservé aux titres et au texte. Une action
/// et un intitulé de la même teinte se confondraient.
class BoutonEnTete extends StatelessWidget {
  const BoutonEnTete({
    super.key,
    required this.icone,
    required this.libelle,
    required this.onPressed,
    this.principal = false,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback onPressed;

  /// Une seule action principale par barre : deux se disputeraient l'attention
  /// et n'en obtiendraient aucune.
  final bool principal;

  static const _forme = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  static const _marges = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  static const _texte = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const _hauteur = Size(0.0, 36.0);

  @override
  Widget build(BuildContext context) {
    final icone18 = Icon(icone, size: 18);
    final texte = Text(libelle);

    if (principal) {
      // Ni backgroundColor ni foregroundColor : le thème fournit son accent et
      // le contraste qui va avec, comme pour « Ajouter une participation » dans
      // le dialogue de saisie. Figer la teinte ici la ferait dériver du reste
      // du module au premier changement de thème.
      return FilledButton.icon(
        onPressed: onPressed,
        icon: icone18,
        label: texte,
        style: FilledButton.styleFrom(
          padding: _marges,
          minimumSize: _hauteur,
          textStyle: _texte,
          shape: _forme,
          elevation: 0,
        ),
      );
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: icone18,
      label: texte,
      style: TextButton.styleFrom(
        foregroundColor: tableauEntete,
        backgroundColor: tableauEntete.withValues(alpha: 0.05),
        padding: _marges,
        minimumSize: _hauteur,
        textStyle: _texte,
        shape: _forme,
      ),
    );
  }
}

/// Action secondaire d'un en-tête de carte.
///
/// Un contour, pas un fond teinté ni un libellé nu. Posée à côté du bouton plein
/// qui crée quelque chose, une action de consultation doit se donner pour
/// cliquable sans lui disputer la priorité : le cadre le dit, le remplissage
/// resterait à sa voisine.
///
/// Sans icône : le libellé se suffit, et deux boutons dont un seul porte une
/// icône ne s'alignent pas sur la même base optique.
///
/// Le rayon vient du thème, comme celui des boutons pleins, pour que la paire
/// reste alignée si le thème change son arrondi.
class BoutonSecondaire extends StatelessWidget {
  const BoutonSecondaire({
    super.key,
    required this.libelle,
    required this.onPressed,
  });

  final String libelle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        textStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(libelle),
    );
  }
}

/// Bandeau d'en-tête, bleu marine et texte blanc.
Widget enteteTableau(BuildContext context, List<ColonneTableau> colonnes) {
  return Container(
    color: tableauEntete,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final colonne in colonnes)
            ...celluleTableau(
              flex: colonne.flex,
              largeur: colonne.largeur,
              enfant: Text(
                colonne.libelle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Cadre du tableau : la bordure extérieure et le filet sous l'en-tête.
Widget cadreTableau({
  required BuildContext context,
  required List<ColonneTableau> colonnes,
  required List<Widget> lignes,
}) {
  return Container(
    decoration: BoxDecoration(border: Border.all(color: tableauBordure)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        enteteTableau(context, colonnes),
        Container(height: 0.5, color: tableauBordure),
        ...lignes,
      ],
    ),
  );
}
