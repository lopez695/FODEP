"""Agrégation des données de l'application au format des états FODEP.

Ce module ne connaît pas le classeur : il produit, à partir des expositions,
les chiffres que `service.py` reportera dans les cellules du formulaire.

Deux conventions du FODEP structurent tout le module :

* **Unité** — la BCEAO exige des montants en millions de francs CFA, arrondis
  au million le plus proche (notice, § 2.3). L'application stocke des francs :
  la conversion est faite une seule fois, au moment de l'écriture.
* **Atténuation du risque de crédit (ARC)** — le FODEP ne connaît pas la
  notion de pondération mixte. Une exposition partiellement garantie est
  déclarée en totalité sur la ligne de pondération du *débiteur initial*
  (colonne « Avant ARC »), puis la part couverte est transférée sur la ligne
  de pondération du *garant* via la colonne « Garanties », dont la somme est
  nulle par construction (notice, § 8.6.1). Les sûretés financières traitées
  en approche globale passent, elles, par les colonnes « Ajustement lié à la
  valeur de l'exposition » et « (-) Valeur ajustée de la sûreté ».
"""

from __future__ import annotations

from app.core.natures_immobilisations import NATURE_IMMO_INCORPORELLE

from collections import defaultdict
from dataclasses import dataclass, field
from typing import Any

from app.core.calculations import convert_currency_amount
from database.services.rwa_calculation_service import (
    coerce_off_balance_risk_level,
    lookup_off_balance_fcec,
)


DEVISE_DECLARATION = "XOF"
TOLERANCE = 1e-9

# Codes de catégorie prudentielle de l'application (voir CATEGORY_OPTIONS dans
# database/services/rwa_calculation_service.py) et état FODEP correspondant.
ETAT_PAR_CATEGORIE: dict[str, str] = {
    "a": "EP12",  # Souverains
    "b": "EP13",  # Organismes publics hors administration centrale
    "c": "EP14",  # Banques multilatérales de développement
    "d": "EP15",  # Institutions financières
    "e": "EP16",  # Entreprises
    "f": "EP17",  # Clientèle de détail
    "g": "EP18",  # Prêts garantis par l'immobilier résidentiel
    "h": "EP19",  # Prêts garantis par l'immobilier commercial
    "k": "EP20",  # Autres actifs
}
CATEGORIE_AUTRES_ACTIFS = "k"

# Les créances en souffrance (i) et à risque élevé (j) ne forment pas un état
# à part : le FODEP les « maintient dans la catégorie d'expositions à laquelle
# elles se rapportent » (notice, § 8.3 et § 8.6). L'application ne conserve pas
# cette catégorie d'origine ; le seul indice disponible est le drapeau
# « immobilier résidentiel en défaut ». À défaut, la ligne rejoint les
# entreprises, catégorie de repli du moteur de calcul lui-même.
CATEGORIE_DEFAUT_IMMOBILIER_RESIDENTIEL = "g"
CATEGORIE_DEFAUT_PAR_DEFAUT = "e"
CATEGORIES_DECLASSEES = ("i", "j")

# Codes DISPRU des lignes des états EP09 et EP10, par catégorie. Les catégories
# éclatées en sous-postes (PME / autres) sont déclarées sur le sous-poste
# « autres » : l'application ne distingue pas les PME au sens du § 135.
LIGNES_EP09: dict[str, str] = {
    "a": "RC001",
    "b": "RC002",
    "c": "RC003",
    "d": "RC004",
    "e": "RC007",
    "f": "RC010",
    "g": "RC011",
    "h": "RC014",
    "k": "RC015",
}
LIGNES_EP09_AGREGEES: dict[str, tuple[str, ...]] = {
    "RC005": ("RC006", "RC007"),
    "RC008": ("RC009", "RC010"),
    "RC012": ("RC013", "RC014"),
}
LIGNE_TOTAL_EP09 = "RC016"
LIGNES_TOTALISEES_EP09 = (
    "RC001",
    "RC002",
    "RC003",
    "RC004",
    "RC005",
    "RC008",
    "RC011",
    "RC012",
    "RC015",
)

# L'application ne distingue pas les engagements de financement des autres
# engagements hors bilan : une seule nature d'engagement est saisie, décrite
# par son niveau de risque (donc son FCEC). Tout le hors bilan est donc
# déclaré dans le bloc « Autres engagements hors bilan », défini par le FODEP
# comme l'ensemble des engagements hors dérivés et hors engagements de
# financement.
LIGNES_EP10: dict[str, str] = {
    "a": "RC033",
    "b": "RC034",
    "c": "RC035",
    "d": "RC036",
    "e": "RC039",
    "f": "RC042",
    "g": "RC043",
    "h": "RC046",
    "k": "RC047",
}
LIGNES_EP10_AGREGEES: dict[str, tuple[str, ...]] = {
    "RC037": ("RC038", "RC039"),
    "RC040": ("RC041", "RC042"),
    "RC044": ("RC045", "RC046"),
}
LIGNE_TOTAL_EP10 = "RC048"
LIGNES_TOTALISEES_EP10 = (
    "RC033",
    "RC034",
    "RC035",
    "RC036",
    "RC037",
    "RC040",
    "RC043",
    "RC044",
    "RC047",
)

# Facteurs de conversion en équivalent-crédit reconnus par l'EP10. Ce sont
# exactement les cinq paliers du barème CCF de l'application.
FCEC_FODEP: tuple[float, ...] = (0.1, 0.2, 0.5, 0.75, 1.0)

# Natures d'« autres actifs » de l'application et ligne EP20 correspondante.
LIGNES_EP20_PAR_NATURE: dict[str, str] = {
    "Encaisse": "RC262",
    "Valeurs assimilées à l’encaisse, y compris l’or": "RC263",
    "Valeurs à l’encaissement avec crédit immédiat": "RC264",
    "Participations non significatives non déduites des fonds propres": "PA166",
    "Immobilisations corporelles": "RC265",
    # L'EP36 ne vise que les immobilisations hors exploitation, et l'EP37 les
    # distingue de celles d'exploitation. L'EP20, lui, les pondère à
    # l'identique : les deux natures partagent donc sa ligne RC265. Déclarer
    # cette nature à l'import est le seul moyen de renseigner l'EP36 — sans
    # elle, sa limite prudentielle reste non mesurée.
    "Immobilisations hors exploitation": "RC265",
    "Autres actifs divers": "RC266",
    "Engagements en actions non déduits": "RC271",
    "Expositions sur entreprises financières non soumises à une réglementation "
    "équivalente UMOA": "RC272",
    "Autres éléments d’actifs non définis": "RC275",
    "Participations significatives et impôts différés actifs non déduits": "PA176",
    "Expositions sur établissements non conformes aux ratios de solvabilité": "RC274",
}
LIGNE_EP20_PAR_DEFAUT = "RC275"

# Natures retranchées des fonds propres, et donc absentes des actifs pondérés.
#
# Les immobilisations incorporelles se déduisent du CET1 : les pondérer en plus
# les compterait deux fois, une fois en moins des fonds propres et une fois en
# plus du dénominateur du ratio. Elles n'ont pas de ligne à l'EP20 ; leur place
# est le poste pour mémoire de l'EP3M, qui recense justement les déductions.
NATURES_DEDUITES_DES_FONDS_PROPRES: frozenset[str] = frozenset(
    {NATURE_IMMO_INCORPORELLE}
)

# Les états EP12 à EP19 plafonnent leurs pondérations à 150 %. Une exposition
# pondérée au-delà relève, dans le FODEP, des « autres actifs » : c'est là que
# figurent les lignes à 250 % (participations significatives non déduites,
# impôts différés, établissements ne respectant pas les ratios de solvabilité).
# La grille de l'EP20 sert alors de destination, chaque pondération ayant sa
# ligne d'accueil.
LIGNES_EP20_PAR_PONDERATION: dict[float, str] = {
    0.0: "RC262",
    0.2: "RC264",
    1.0: "RC275",
    1.5: "RC273",
    2.5: "RC274",
}
PALIERS_EP20: tuple[float, ...] = tuple(sorted(LIGNES_EP20_PAR_PONDERATION))


def flottant(valeur: Any, defaut: float = 0.0) -> float:
    """Convertit une valeur de la base en flottant, sans lever d'exception."""

    if valeur is None:
        return defaut
    try:
        return float(valeur)
    except (TypeError, ValueError):
        return defaut


def repartir_sur_paliers(
    ponderation: float, paliers: tuple[float, ...]
) -> dict[float, float] | None:
    """Exprime une pondération comme combinaison des paliers d'un état.

    Les états du FODEP n'offrent qu'une grille fermée de pondérations. Une
    pondération absente de la grille — un garant pondéré à 75 % venant couvrir
    une exposition souveraine, dont l'état ne propose que 0, 20, 50, 100 et
    150 % — est exprimée comme un barycentre des deux paliers qui l'encadrent.
    L'exposition déclarée et l'actif pondéré qui en découle sont alors tous
    deux exacts, là où un simple arrondi au palier voisin fausserait l'APR.

    Retourne les quotes-parts par palier, ou None si la pondération dépasse le
    palier le plus élevé de l'état : aucune combinaison ne peut alors la
    reproduire.
    """

    for palier in paliers:
        if abs(palier - ponderation) < TOLERANCE:
            return {palier: 1.0}

    inferieurs = [palier for palier in paliers if palier < ponderation]
    superieurs = [palier for palier in paliers if palier > ponderation]
    if not superieurs:
        return None
    if not inferieurs:
        # La grille commence à 0 % sur tous les états : ce cas ne peut
        # survenir que sur une pondération négative, donc aberrante.
        return None

    bas = max(inferieurs)
    haut = min(superieurs)
    part_haute = (ponderation - bas) / (haut - bas)
    return {bas: 1.0 - part_haute, haut: part_haute}


@dataclass
class VentilationPonderee:
    """Colonnes « avant ARC » et ajustements d'un bloc d'état de crédit."""

    avant_arc: dict[float, float] = field(default_factory=lambda: defaultdict(float))
    garanties: dict[float, float] = field(default_factory=lambda: defaultdict(float))
    ajustement_exposition: dict[float, float] = field(
        default_factory=lambda: defaultdict(float)
    )
    surete_ajustee: dict[float, float] = field(
        default_factory=lambda: defaultdict(float)
    )

    def colonnes(self) -> tuple[dict[float, float], ...]:
        return (
            self.avant_arc,
            self.garanties,
            self.ajustement_exposition,
            self.surete_ajustee,
        )

    def ponderations(self) -> set[float]:
        ponderations: set[float] = set()
        for colonne in self.colonnes():
            ponderations |= set(colonne)
        return ponderations

    def apres_arc(self, ponderation: float) -> float:
        return sum(colonne.get(ponderation, 0.0) for colonne in self.colonnes())


@dataclass
class BlocCategorie:
    """Montants d'une catégorie sur un type d'exposition (bilan ou hors bilan)."""

    brut: float = 0.0
    souffrance: float = 0.0
    risque_eleve: float = 0.0
    provisions: float = 0.0
    deduit_fonds_propres: float = 0.0
    brut_par_fcec: dict[float, float] = field(
        default_factory=lambda: defaultdict(float)
    )
    brut_apres_fcec: float = 0.0
    ventilation: VentilationPonderee = field(default_factory=VentilationPonderee)
    hors_bilan: bool = False

    @property
    def net(self) -> float:
        """Exposition nette de provisions et d'éléments déduits des fonds propres."""

        base = self.brut_apres_fcec if self.hors_bilan else self.brut
        return base - self.provisions - self.deduit_fonds_propres


@dataclass
class SyntheseCredit:
    """Résultat de l'agrégation du risque de crédit."""

    bilan: dict[str, BlocCategorie] = field(default_factory=dict)
    hors_bilan: dict[str, BlocCategorie] = field(default_factory=dict)
    autres_actifs_par_ligne: dict[str, float] = field(
        default_factory=lambda: defaultdict(float)
    )
    anomalies: list[str] = field(default_factory=list)

    def bloc_bilan(self, categorie: str) -> BlocCategorie:
        return self.bilan.setdefault(categorie, BlocCategorie())

    def bloc_hors_bilan(self, categorie: str) -> BlocCategorie:
        return self.hors_bilan.setdefault(
            categorie, BlocCategorie(hors_bilan=True)
        )

    def declarer_sur_autres_actifs(self, montant: float, ponderation: float) -> None:
        """Déclare un montant sur l'EP20, à la pondération indiquée."""

        if not montant:
            return
        quotes_parts = repartir_sur_paliers(ponderation, PALIERS_EP20)
        if quotes_parts is None:
            self.anomalies.append(
                f"Pondération de {ponderation:.0%} sans ligne d'accueil dans le "
                f"FODEP : {montant:,.0f} FCFA non déclarés."
            )
            return
        for palier, quote_part in quotes_parts.items():
            self.autres_actifs_par_ligne[
                LIGNES_EP20_PAR_PONDERATION[palier]
            ] += montant * quote_part


def categorie_fodep(exposition: dict[str, Any]) -> str:
    """Catégorie FODEP d'une exposition, défaut et risque élevé reclassés."""

    code = str(exposition.get("prudential_type") or "e").strip().lower()
    if code in CATEGORIES_DECLASSEES:
        if exposition.get("defaulted_exposure_residential_mortgage_in_default"):
            return CATEGORIE_DEFAUT_IMMOBILIER_RESIDENTIEL
        return CATEGORIE_DEFAUT_PAR_DEFAUT
    if code in ETAT_PAR_CATEGORIE:
        return code
    return CATEGORIE_DEFAUT_PAR_DEFAUT


def substitution_retenue(
    ponderation_debiteur: float, ponderation_garant: float
) -> bool:
    """Indique si la garantie allège réellement l'exigence de fonds propres.

    Une technique d'atténuation ne peut pas alourdir l'exigence : quand le
    garant est pondéré plus lourdement que le débiteur, la protection n'est
    pas invoquée et l'exposition reste sur la ligne du débiteur. Le moteur de
    calcul applique la même règle (plafond `min(rwa_substitué, ead × rw_débiteur)`
    dans `rwa_calculation_service`) ; s'en écarter ferait déclarer un APR
    supérieur à celui que l'application affiche.
    """

    return ponderation_garant < ponderation_debiteur - TOLERANCE


def palier_fcec(niveau_de_risque: str | None) -> float:
    """Facteur de conversion en équivalent-crédit d'un engagement hors bilan.

    Le barème est celui du moteur de calcul : le déduire du rapport entre
    montants déclarés donnerait un palier faux dès qu'une sûreté financière
    réduit l'exposition, la valeur enregistrée étant alors postérieure à
    l'atténuation.
    """

    return lookup_off_balance_fcec(coerce_off_balance_risk_level(niveau_de_risque))


def agreger_risque_credit(
    expositions: list[dict[str, Any]],
    paliers_par_categorie: dict[str, tuple[float, ...]],
) -> SyntheseCredit:
    """Ventile les expositions dans les états EP09, EP10 et EP12 à EP20."""

    synthese = SyntheseCredit()

    for exposition in expositions:
        devise = str(exposition.get("currency") or DEVISE_DECLARATION)

        def en_xof(valeur: Any) -> float:
            return convert_currency_amount(
                flottant(valeur),
                from_currency=devise,
                to_currency=DEVISE_DECLARATION,
            )

        categorie = categorie_fodep(exposition)
        code_prudentiel = str(exposition.get("prudential_type") or "e").strip().lower()
        ponderation_debiteur = flottant(exposition.get("original_rw"))

        brut_bilan = en_xof(
            exposition.get("on_balance_exposure_amount")
            if exposition.get("on_balance_exposure_amount") is not None
            else exposition.get("gross_amount")
        )
        brut_hors_bilan = en_xof(exposition.get("off_balance_exposure_amount"))
        # Équivalent-crédit reconstruit depuis le barème, et non lu dans
        # `ead_hb_ccf_amount` : ce champ porte l'EAD hors bilan *après* prise
        # en compte d'une sûreté financière. L'utiliser en colonne « avant
        # ARC », puis y appliquer l'ajustement d'ARC, décomptait deux fois la
        # même sûreté sur le volet hors bilan.
        fcec = palier_fcec(exposition.get("off_balance_risk_level"))
        apres_fcec = brut_hors_bilan * fcec
        provisions = en_xof(exposition.get("provisions_amount"))

        # Les provisions portent sur la créance figurant au bilan : les
        # imputer aussi au hors bilan reviendrait à déduire deux fois un même
        # abattement lorsqu'une ligne porte les deux volets.
        bloc_bilan = synthese.bloc_bilan(categorie)
        bloc_bilan.brut += brut_bilan
        bloc_bilan.provisions += provisions
        if code_prudentiel == "i":
            bloc_bilan.souffrance += brut_bilan
        elif code_prudentiel == "j":
            bloc_bilan.risque_eleve += brut_bilan

        net_bilan = max(brut_bilan - provisions, 0.0)
        net_hors_bilan = apres_fcec

        if brut_hors_bilan > 0:
            bloc_hb = synthese.bloc_hors_bilan(categorie)
            bloc_hb.brut += brut_hors_bilan
            bloc_hb.brut_apres_fcec += apres_fcec
            bloc_hb.brut_par_fcec[fcec] += brut_hors_bilan
            if code_prudentiel == "i":
                bloc_hb.souffrance += brut_hors_bilan
            elif code_prudentiel == "j":
                bloc_hb.risque_eleve += brut_hors_bilan

        # L'EP20 ne connaît ni pondérations libres ni colonnes d'ARC : chaque
        # nature d'actif y porte sa propre pondération réglementaire.
        if categorie == CATEGORIE_AUTRES_ACTIFS:
            nature = str(exposition.get("other_asset_type") or "")
            # Ce qui est déduit des fonds propres ne se pondère pas : l'EP3M le
            # recense, l'EP20 l'ignore.
            if nature in NATURES_DEDUITES_DES_FONDS_PROPRES:
                continue
            ligne = LIGNES_EP20_PAR_NATURE.get(nature, LIGNE_EP20_PAR_DEFAUT)
            synthese.autres_actifs_par_ligne[ligne] += net_bilan + net_hors_bilan
            continue

        details_crm = exposition.get("crm_details") or {}
        mode_crm = str(details_crm.get("mode") or "Aucune")
        total_net = net_bilan + net_hors_bilan
        valeur_ajustee_exposition = en_xof(details_crm.get("eva"))
        # « L'effet d'ARC est plafonné au montant de l'exposition nette »
        # (notice, § 8.6.2) : une sûreté qui vaut plus que la créance qu'elle
        # garantit l'annule, elle ne crée pas d'exposition négative. Sans ce
        # plafond, sept lignes intégralement collatéralisées déclaraient un
        # actif pondéré négatif, qui venait en déduction de l'APR total.
        valeur_ajustee_surete = min(
            en_xof(details_crm.get("cva")), valeur_ajustee_exposition
        )
        couverture = min(
            max(flottant(exposition.get("crm_coverage_percent")), 0.0), 1.0
        )
        ponderation_garant = flottant(exposition.get("guarantor_rw"))

        # Une pondération de débiteur au-delà du plafond de son état (250 %,
        # là où les états EP12 à EP19 s'arrêtent à 150 %) n'a pas de ligne
        # d'accueil : le FODEP loge ces expositions parmi les autres actifs.
        # Le basculement est décidé ici, exposition par exposition, pour que
        # sa contrepartie d'ARC parte avec elle — la déplacer après agrégation
        # laisserait la part garantie orpheline sur la ligne du garant, et la
        # colonne « Garanties » ne serait plus à somme nulle.
        paliers = paliers_par_categorie.get(categorie, ())
        if paliers and repartir_sur_paliers(ponderation_debiteur, paliers) is None:
            _declarer_hors_grille(
                synthese,
                total_net=total_net,
                ponderation_debiteur=ponderation_debiteur,
                mode_crm=mode_crm,
                couverture=couverture,
                ponderation_garant=ponderation_garant,
                valeur_ajustee_exposition=valeur_ajustee_exposition,
                valeur_ajustee_surete=valeur_ajustee_surete,
            )
            continue

        for net, ventilation in (
            (net_bilan, synthese.bloc_bilan(categorie).ventilation),
            (net_hors_bilan, synthese.bloc_hors_bilan(categorie).ventilation),
        ):
            if net <= 0:
                continue
            ventilation.avant_arc[ponderation_debiteur] += net

            if mode_crm == "CRM non financee" and substitution_retenue(
                ponderation_debiteur, ponderation_garant
            ):
                part_couverte = net * couverture
                if part_couverte > 0:
                    ventilation.garanties[ponderation_debiteur] -= part_couverte
                    ventilation.garanties[ponderation_garant] += part_couverte
            elif mode_crm == "CRM financee":
                # Approche globale : l'exposition est majorée de sa décote He
                # puis diminuée de la valeur ajustée de la sûreté, de sorte que
                # l'exposition après ARC vaut exactement l'EAD retenue par le
                # moteur de calcul (VAE - VAS). La ligne peut porter du bilan
                # et du hors bilan ; l'ajustement suit le prorata de chaque
                # volet.
                quote_part = net / total_net if total_net > 0 else 0.0
                ventilation.ajustement_exposition[ponderation_debiteur] += (
                    valeur_ajustee_exposition * quote_part - net
                )
                ventilation.surete_ajustee[ponderation_debiteur] -= (
                    valeur_ajustee_surete * quote_part
                )

    return synthese


def _declarer_hors_grille(
    synthese: SyntheseCredit,
    *,
    total_net: float,
    ponderation_debiteur: float,
    mode_crm: str,
    couverture: float,
    ponderation_garant: float,
    valeur_ajustee_exposition: float,
    valeur_ajustee_surete: float,
) -> None:
    """Déclare sur l'EP20 une exposition sortant de la grille de son état.

    L'effet des techniques d'ARC est conservé : la part garantie est déclarée
    à la pondération du garant, la part restante à celle du débiteur, et une
    sûreté financière réduit l'exposition avant pondération. L'exposition
    déclarée comme l'actif pondéré qui en découle restent donc exacts.
    """

    if total_net <= 0:
        return
    if (
        mode_crm == "CRM non financee"
        and couverture > 0
        and substitution_retenue(ponderation_debiteur, ponderation_garant)
    ):
        part_couverte = total_net * couverture
        synthese.declarer_sur_autres_actifs(part_couverte, ponderation_garant)
        synthese.declarer_sur_autres_actifs(
            total_net - part_couverte, ponderation_debiteur
        )
        return
    if mode_crm == "CRM financee":
        total_net = max(valeur_ajustee_exposition - valeur_ajustee_surete, 0.0)
    synthese.declarer_sur_autres_actifs(total_net, ponderation_debiteur)


def aligner_sur_les_paliers(
    synthese: SyntheseCredit,
    paliers_par_categorie: dict[str, tuple[float, ...]],
) -> None:
    """Réexprime les pondérations agrégées sur la grille de chaque état.

    Seules les pondérations de garant peuvent encore sortir de la grille à ce
    stade : celles des débiteurs ont déjà été traitées exposition par
    exposition, au moment de l'agrégation. Une pondération encadrée par la
    grille est répartie sur les deux paliers qui l'entourent, ce qui préserve
    à la fois l'exposition déclarée et l'actif pondéré.
    """

    for blocs in (synthese.bilan, synthese.hors_bilan):
        for categorie, bloc in blocs.items():
            paliers = paliers_par_categorie.get(categorie)
            if not paliers:
                continue
            ventilation = bloc.ventilation
            for ponderation in sorted(ventilation.ponderations()):
                quotes_parts = repartir_sur_paliers(ponderation, paliers)
                if quotes_parts is not None and set(quotes_parts) == {ponderation}:
                    continue
                if quotes_parts is None:
                    # Au-delà du palier le plus élevé, aucune combinaison ne
                    # reproduit la pondération : le montant est ramené sur ce
                    # palier plutôt que d'être retiré de l'état, ce qui
                    # romprait la somme nulle de la colonne « Garanties ».
                    quotes_parts = {max(paliers): 1.0}
                    synthese.anomalies.append(
                        f"Catégorie « {categorie} » : une pondération de "
                        f"{ponderation:.0%} dépasse le plafond de l'état et a "
                        f"été ramenée à {max(paliers):.0%}."
                    )

                colonnes = ventilation.colonnes()
                montants = [colonne.pop(ponderation, 0.0) for colonne in colonnes]
                for colonne, montant in zip(colonnes, montants):
                    if not montant:
                        continue
                    for palier, quote_part in quotes_parts.items():
                        colonne[palier] += montant * quote_part
