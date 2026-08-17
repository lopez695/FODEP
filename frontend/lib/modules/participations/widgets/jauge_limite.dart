import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../models/participation_models.dart';
import 'tableau_maison.dart';

// Palette des états de limite. Elle est nommée par l'état, pas par la teinte :
// le vert d'une limite respectée et l'ambre d'une limite qui s'en approche
// doivent rester lisibles côte à côte, et se distinguer de l'erreur.
const Color limiteRespectee = Color(0xFF0F766E);
const Color limiteProche = Color(0xFFB45309);
const Color limiteDepassee = Color(0xFFB91C1C);
const Color limiteInconnue = Color(0xFF64748B);

/// Fond de la jauge : la piste non consommée.
const Color _pisteJauge = Color(0xFFE9EEF7);

/// Gris des mentions qui accompagnent un chiffre sans le porter.
const Color texteSecondaireLimites = Color(0xFF64748B);

// Ambre des points de vigilance. Une donnée absente n'est pas un dépassement :
// elle rend la conformité trompeuse sans la démentir, et se distingue donc du
// rouge que porte une limite réellement dépassée.
const Color vigilanceFond = Color(0xFFFFFBEB);
const Color vigilanceBordure = Color(0xFFFDE68A);
const Color vigilanceTexte = Color(0xFF92400E);

const Color _texteSecondaire = texteSecondaireLimites;

/// Où en est une limite. Porte son mot, son icône et sa couleur.
///
/// L'état est écrit en clair et doublé d'une icône : une couleur seule ne dit
/// rien à qui ne la distingue pas, et le lecteur d'un état réglementaire a
/// besoin du mot autant que de la teinte.
enum EtatLimite {
  respectee('Respectée', Icons.check_circle_outline, limiteRespectee),
  procheDuPlafond('Proche du plafond', Icons.trending_up, limiteProche),
  depassee('Dépassée', Icons.error_outline, limiteDepassee),
  nonMesurable('Non mesurable', Icons.help_outline, limiteInconnue);

  const EtatLimite(this.libelle, this.icone, this.couleur);

  final String libelle;
  final IconData icone;
  final Color couleur;

  /// Sous le plafond mais à moins de 20 % de marge : la limite se rapproche, et
  /// c'est le moment de le savoir, pas après.
  static const double seuilDeVigilance = 0.8;

  static EtatLimite de(LimitePrudentielle limite) {
    if (!limite.mesurable) return EtatLimite.nonMesurable;
    if (!limite.respectee) return EtatLimite.depassee;
    if (limite.remplissage >= seuilDeVigilance) return EtatLimite.procheDuPlafond;
    return EtatLimite.respectee;
  }
}

/// Une limite prudentielle : ce qu'elle plafonne, où elle en est, sa marge.
///
/// La ligne se lit de gauche à droite comme une phrase : ce qui est limité, ce
/// qui est comparé à quoi, puis le niveau atteint et la part du plafond déjà
/// consommée. Le code de la norme est relégué dans une colonne de référence :
/// il sert à retrouver la ligne dans le FODEP, il ne dit pas ce qu'elle mesure.
///
/// La jauge est remplie à la part du plafond consommée, pas à la part du
/// dénominateur : c'est le plafond qui décide, et une limite consommée à 90 %
/// doit se voir comme telle même quand le ratio n'est que de 22,5 %.
class JaugeLimite extends StatelessWidget {
  const JaugeLimite({super.key, required this.limite});

  final LimitePrudentielle limite;

  /// Ce qui est comparé à quoi. Écrit en division plutôt qu'en phrase : le
  /// lecteur doit pouvoir refaire le calcul, pas deviner l'assiette.
  String get _calculEnClair =>
      '${limite.numerateurLibelle} ÷ ${limite.denominateurLibelle}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final etat = EtatLimite.de(limite);
    final marge = limite.mesurable
        ? limite.limite * limite.denominateur - limite.numerateur
        : 0.0;

    return Tooltip(
      message: [
        limite.libelle,
        '${limite.numerateurLibelle} : ${AppFormatters.millions(limite.numerateur)}',
        '${limite.denominateurLibelle} : '
            '${limite.mesurable ? AppFormatters.millions(limite.denominateur) : "non renseigné"}',
        if (limite.mesurable && limite.respectee)
          'Marge restante : ${AppFormatters.millions(marge)}',
        if (limite.mesurable && !limite.respectee)
          'Excédent à résorber : ${AppFormatters.millions(limite.excedent)}',
        'Norme ${limite.code}, déclarée à l\'état ${limite.etat}',
      ].join('\n'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Reference(code: limite.code, etat: limite.etat),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          limite.libelle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tableauTexteFort,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _Niveau(limite: limite, etat: etat),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          limite.concerne == null
                              ? _calculEnClair
                              : '${limite.concerne} · $_calculEnClair',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11.5,
                            color: _texteSecondaire,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Etiquette(etat: etat),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: limite.mesurable ? limite.remplissage : 0.0,
                            minHeight: 6,
                            backgroundColor: _pisteJauge,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(etat.couleur),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 128,
                        child: Text(
                          limite.mesurable
                              ? '${(limite.remplissage * 100).toStringAsFixed(0)} % du plafond'
                              : 'dénominateur absent',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: _texteSecondaire,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colonne de référence : le code de la norme et l'état qui la porte.
///
/// Discrète à dessein. Elle sert à retrouver la ligne dans le classeur FODEP,
/// pas à identifier la limite pour le lecteur.
class _Reference extends StatelessWidget {
  const _Reference({required this.code, required this.etat});

  final String code;
  final String etat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 46,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 1),
          Text(
            code,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _texteSecondaire,
              letterSpacing: 0.2,
            ),
          ),
          Text(
            etat,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: _texteSecondaire.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Niveau observé et plafond, dans cet ordre : le premier est l'information,
/// le second le repère qui la rend lisible.
class _Niveau extends StatelessWidget {
  const _Niveau({required this.limite, required this.etat});

  final LimitePrudentielle limite;
  final EtatLimite etat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!limite.mesurable) {
      return Text(
        'non mesurable',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: etat.couleur,
        ),
      );
    }

    // Taille minimale : la ligne qui accueille ce bloc ne lui donne pas de
    // largeur, elle lui laisse celle qu'il demande.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${(limite.observe * 100).toStringAsFixed(1)} %',
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: etat.couleur,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'max ${(limite.limite * 100).toStringAsFixed(0)} %',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: _texteSecondaire,
          ),
        ),
      ],
    );
  }
}

/// L'état de la limite, en un mot et une icône.
class _Etiquette extends StatelessWidget {
  const _Etiquette({required this.etat});

  final EtatLimite etat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: etat.couleur.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(etat.icone, size: 12, color: etat.couleur),
          const SizedBox(width: 5),
          Text(
            etat.libelle,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: etat.couleur,
            ),
          ),
        ],
      ),
    );
  }
}
