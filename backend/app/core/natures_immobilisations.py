"""Natures d'actifs portant les immobilisations.

Ces deux libelles sont ceux du referentiel d'import des autres actifs. Ils
servent a l'export FODEP, pour les etats EP36 et EP37, et au suivi des
participations, dont deux limites prudentielles additionnent immobilisations
et participations. Les tenir en un seul endroit evite que les deux lectures
divergent : deux ecrans qui compteraient les memes immobilisations
differemment ne seraient credibles ni l'un ni l'autre.
"""

from __future__ import annotations

NATURE_IMMO_EXPLOITATION = "Immobilisations corporelles"
NATURE_IMMO_HORS_EXPLOITATION = "Immobilisations hors exploitation"

# Les incorporelles ne rejoignent ni l'EP36 ni l'EP37 : elles se retranchent
# des fonds propres de base au lieu d'etre ponderees, et c'est le poste pour
# memoire de l'EP3M qui les recense (ligne IM011).
NATURE_IMMO_INCORPORELLE = "Immobilisations incorporelles"
