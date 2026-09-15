"""Les limites prudentielles dont l'exces se retranche des fonds propres.

Six normes du dispositif se mesurent en rapportant un encours aux fonds
propres. Les etats EP35 a EP38 du FODEP les mesurent ; l'EP03 en tire quatre
lignes de deduction — PA149, IM006, IM010 et PR004. Franchir une limite n'est
donc pas seulement un constat porte sur l'EP01 : c'est un montant qui sort des
fonds propres de base, et avec lui les trois ratios de solvabilite.

Le denominateur est celui de l'EXERCICE PRECEDENT. Les quatre etats le disent
en note de pied — « *** de l'exercice precedent » — et ce n'est pas un detail
de presentation : mesurer sur les fonds propres de l'annee en cours rendrait la
deduction circulaire, puisqu'elle abaisse le CET1, ce qui releve le ratio, ce
qui augmente l'excedent. Rapporte a un millesime clos, l'exces est un nombre
fixe, et la deduction se pose en une passe.

Le calcul vit ici, hors du FODEP : la declaration et le tableau de bord doivent
annoncer le meme CET1, et deux implementations d'une meme soustraction
finissent toujours par diverger.
"""

from __future__ import annotations

from dataclasses import dataclass

# Les plafonds, tels que le formulaire les imprime au-dessus de ses colonnes.
#: EP35, colonne d : souscription rapportee au capital de l'emetteur.
PLAFOND_PARTICIPATION_CAPITAL_EMETTEUR = 0.25
#: EP35, colonne e : montant libere rapporte aux fonds propres de base T1.
PLAFOND_PARTICIPATION_T1 = 0.15
#: EP35, colonne f : total des participations rapporte aux fonds propres effectifs.
PLAFOND_PARTICIPATIONS_FPE = 0.60
#: EP36 : immobilisations hors exploitation rapportees aux fonds propres de base.
PLAFOND_IMMOBILISATIONS_HORS_EXPLOITATION = 0.15
#: EP37 : immobilisations et participations rapportees aux fonds propres effectifs.
PLAFOND_IMMOBILISATIONS_ET_PARTICIPATIONS = 1.00
#: EP38 : concours aux parties liees rapportes aux fonds propres effectifs.
PLAFOND_PARTIES_LIEES = 0.20


@dataclass(frozen=True)
class ExcedentDetaille:
    """Un excedent, et le detail que l'etat qui le mesure doit afficher.

    L'EP35 ne porte pas seulement le montant a deduire : il imprime, entite par
    entite, l'exces sur le capital de l'emetteur (g), l'exces sur les fonds
    propres de base (h) et le plus grand des deux (i), puis l'exces global (j).
    Les rendre avec le total evite que l'etat et la deduction soient calcules
    deux fois.
    """

    #: Exces individuels, dans l'ordre des entites recues : (g, h, i).
    par_entite: tuple[tuple[float, float, float], ...]
    #: j : exces sur la limite globale.
    exces_global: float
    #: k = Max(total des i ; j) — le montant qui sort des fonds propres.
    a_deduire: float


@dataclass(frozen=True)
class ExcedentsDeLimites:
    """Ce que les quatre limites retranchent des fonds propres de base.

    `mesures` dit si le denominateur etait disponible. Faute de fonds propres
    de l'exercice precedent, les excedents valent zero — mais c'est une absence
    de mesure, pas un respect constate, et l'appelant doit pouvoir le dire.
    """

    #: PA149 — participations dans des entites commerciales (EP35).
    participations: float = 0.0
    #: IM006 — immobilisations hors exploitation (EP36).
    immobilisations: float = 0.0
    #: IM010 — total des immobilisations et participations (EP37).
    immobilisations_participations: float = 0.0
    #: PR004 — concours aux actionnaires, dirigeants et personnel (EP38).
    parties_liees: float = 0.0
    #: Exercice servant de denominateur, ou None si aucun n'a ete trouve.
    exercice_precedent: int | None = None

    @property
    def mesures(self) -> bool:
        return self.exercice_precedent is not None

    @property
    def total(self) -> float:
        """Ce qui se retranche du CET1, toutes limites confondues.

        Les quatre lignes s'additionnent : le formulaire leur donne quatre
        lignes distinctes en EP03, chacune negative, et leur somme s'impute sur
        les fonds propres de base.
        """

        return (
            self.participations
            + self.immobilisations
            + self.immobilisations_participations
            + self.parties_liees
        )

    def par_code_dispru(self) -> dict[str, float]:
        """Les quatre montants, sous le code que l'EP03 leur donne."""

        return {
            "PA149": self.participations,
            "IM006": self.immobilisations,
            "IM010": self.immobilisations_participations,
            "PR004": self.parties_liees,
        }


def _exces(encours: float, plafond: float, denominateur: float) -> float:
    """Ce qui depasse le plafond, ou zero si la limite n'est pas mesurable.

    Un denominateur nul ne signifie pas que la limite est respectee : il
    signifie qu'elle n'a pas de sens. Rendre zero y est le seul choix honnete,
    et c'est `ExcedentsDeLimites.mesures` qui porte la nuance.
    """

    if denominateur <= 0:
        return 0.0
    return max(0.0, encours - plafond * denominateur)


def excedent_participations(
    entites: list[tuple[float, float, float]],
    fonds_propres_t1: float,
    fonds_propres_effectifs: float,
) -> ExcedentDetaille:
    """L'exces des participations dans des entites commerciales (EP35, PA149).

    `entites` porte, pour chaque participation, son capital d'emetteur, son
    montant brut souscrit et son montant net libere. Le formulaire imprime la
    formule en tete de chaque colonne :

        g = Max[0 ; a x (d - 25%)]  soit  Max[0 ; brut - 25% du capital]
        h = Max[0 ; c - 15% x FPB T1]
        i = max(g ; h)
        j = Max[0 ; total des c - 60% x FPE]
        k = Max(total des i ; j)

    Les deux limites individuelles ne se cumulent pas — c'est la plus
    contraignante qui vaut, non leur somme — et la limite globale ne s'ajoute
    pas davantage : k retient le plus grand, pas le total.
    """

    par_entite: list[tuple[float, float, float]] = []
    total_net = 0.0
    for capital, brut, net in entites:
        total_net += net
        g = _exces(brut, PLAFOND_PARTICIPATION_CAPITAL_EMETTEUR, capital)
        h = _exces(net, PLAFOND_PARTICIPATION_T1, fonds_propres_t1)
        par_entite.append((g, h, max(g, h)))

    exces_global = _exces(
        total_net, PLAFOND_PARTICIPATIONS_FPE, fonds_propres_effectifs
    )
    total_individuels = sum(exces for _, _, exces in par_entite)
    return ExcedentDetaille(
        par_entite=tuple(par_entite),
        exces_global=exces_global,
        a_deduire=max(total_individuels, exces_global),
    )


def excedent_immobilisations(
    immobilisations_hors_exploitation: float,
    participations_immobilieres: float,
    fonds_propres_t1: float,
) -> float:
    """L'exces des immobilisations hors exploitation (EP36, IM006)."""

    return _exces(
        immobilisations_hors_exploitation + participations_immobilieres,
        PLAFOND_IMMOBILISATIONS_HORS_EXPLOITATION,
        fonds_propres_t1,
    )


def excedent_immobilisations_participations(
    immobilisations_totales: float,
    participations_totales: float,
    fonds_propres_effectifs: float,
) -> float:
    """L'exces du total immobilisations et participations (EP37, IM010)."""

    return _exces(
        immobilisations_totales + participations_totales,
        PLAFOND_IMMOBILISATIONS_ET_PARTICIPATIONS,
        fonds_propres_effectifs,
    )


def excedent_parties_liees(
    concours_totaux: float, fonds_propres_effectifs: float
) -> float:
    """L'exces des concours aux parties liees (EP38, PR004)."""

    return _exces(concours_totaux, PLAFOND_PARTIES_LIEES, fonds_propres_effectifs)
