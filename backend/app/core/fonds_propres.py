"""Comment lire les fonds propres en vigueur.

La table `fonds_propres` porte desormais un exercice par ligne. Avant, elle
n'en portait qu'une, et cinq endroits du code la lisaient par
`ORDER BY date_analyse DESC LIMIT 1` -- ce qui revenait au meme tant qu'il n'y
avait rien a departager.

Des que l'historique existe, cette formule choisit la mauvaise ligne :
`date_analyse` est l'horodatage de SAISIE, pas le millesime. Un exercice
anterieur saisi aujourd'hui y passe devant l'exercice declare, et la
declaration part sur les fonds propres de l'annee precedente. C'est arrive :
l'EP03 a porte un CET1 de 54 Md la ou l'application en affichait 87.

La requete vit donc ici, en un seul exemplaire. Cinq copies d'une meme lecture
finissent toujours par diverger.
"""

from __future__ import annotations

#: L'exercice le plus recent fait foi ; `date_analyse` ne sert qu'a departager
#: deux lignes du meme millesime, ce que l'index unique interdit par ailleurs.
REQUETE_FONDS_PROPRES_COURANTS = (
    "SELECT * FROM fonds_propres ORDER BY exercice DESC, date_analyse DESC LIMIT 1"
)

#: Le millesime clos qui precede immediatement celui qu'on declare.
#:
#: Quatre etats du FODEP -- EP35, EP36, EP37 et EP38 -- rapportent leurs
#: limites aux fonds propres « de l'exercice precedent », et le disent en note
#: de pied. Le parametre est l'exercice DECLARE, pas l'annee courante : une
#: declaration reprise deux ans plus tard doit retrouver le meme denominateur
#: qu'a l'epoque, sans quoi les pourcentages declares changeraient tout seuls.
#:
#: « L'exercice immediatement inferieur » et non « l'exercice moins un » : un
#: millesime manquant ne doit pas rendre la limite non mesurable alors que
#: l'etablissement a saisi l'annee d'avant.
REQUETE_FONDS_PROPRES_EXERCICE_PRECEDENT = (
    "SELECT * FROM fonds_propres WHERE exercice IS NOT NULL AND exercice < ? "
    "ORDER BY exercice DESC LIMIT 1"
)
