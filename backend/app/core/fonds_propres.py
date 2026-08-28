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
