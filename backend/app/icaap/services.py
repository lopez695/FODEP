"""Le socle Pilier 1 du PIEAFP.

Point de depart obligatoire du processus : le dispositif (Titre XI) pose que
les fonds propres internes s'AJOUTENT aux exigences minimales, jamais ne s'y
substituent. Cet ecran montre donc ce que le Pilier 1 exige deja, avant tout
add-on interne.

Les chiffres ne sont pas recalcules ici : ils viennent de `socle_pilier1()`,
la meme lecture que celle du tableau de bord. Une seconde implantation du
ratio de solvabilite finirait par en diverger, et deux ecrans qui se
contredisent ne sont credibles ni l'un ni l'autre.
"""

from __future__ import annotations

from datetime import date, datetime

from app.core.bceao_calculations import (
    CONSERVATION_BUFFER,
    MIN_CET1_RATIO,
    MIN_LEVERAGE_RATIO,
    MIN_SOLVENCY_RATIO,
    MIN_TIER1_RATIO,
)
from app.core.calculations import calculate_capital
from app.dashboard.services import socle_pilier1
from app.icaap.models import (
    BROUILLON,
    CapitalReglementaire,
    CycleIcaap,
    ExigenceGlobale,
    ExigenceRisque,
    NiveauRatio,
    StatutCycleUpdate,
)
from database.connection import database_manager

RESPECTEE = "respectee"
SOUS_COUSSIN = "sous_coussin"
DEPASSEE = "depassee"

# Ce que le PIEAFP doit examiner en plus de la formule standard, risque par
# risque. Repris du dispositif (Titre XI, chapitre 1, evaluation des risques) :
# ce sont les angles que la ponderation reglementaire ne capte pas, et que
# l'etablissement doit couvrir de lui-meme.
_ANGLES_PILIER2 = {
    "credit": (
        "Concentration (contrepartie, secteur, zone, sûretés), risque résiduel "
        "des techniques d'atténuation, historique de pertes du segment."
    ),
    "marche": (
        "Positions hors Pilier 1, concentration et illiquidité en scénario de "
        "turbulence, taux d'intérêt du portefeuille bancaire."
    ),
    "operationnel": (
        "Appétence au risque opérationnel, transfert externe (assurance, "
        "externalisation), risques des canaux digitaux."
    ),
}


def _maintenant() -> str:
    return datetime.now().isoformat(timespec="seconds")


def cycle_courant(exercice: int) -> CycleIcaap:
    """Le cycle PIEAFP de l'exercice, cree au premier acces.

    Creer la ligne a la lecture plutot que d'attendre une saisie evite un ecran
    qui n'aurait rien a montrer tant que personne n'a clique : le cycle existe
    des lors que l'exercice existe. L'etablissement ne le cree pas, il le
    conduit.
    """

    with database_manager.transaction() as connection:
        connection.execute(
            """
            INSERT OR IGNORE INTO icaap_exercices
                (exercice, statut, cree_le, modifie_le)
            VALUES (?, ?, ?, ?)
            """,
            (exercice, BROUILLON, _maintenant(), _maintenant()),
        )
        ligne = connection.execute(
            "SELECT * FROM icaap_exercices WHERE exercice = ?", (exercice,)
        ).fetchone()

    return CycleIcaap(
        exercice=ligne["exercice"],
        statut=ligne["statut"],
        date_validation=ligne["date_validation"],
        organe=ligne["organe"] or "",
        version=ligne["version"],
        commentaire=ligne["commentaire"] or "",
    )


def changer_statut(exercice: int, demande: StatutCycleUpdate) -> CycleIcaap:
    """Fait avancer le cycle d'une etape.

    La version s'incremente au retour en brouillon apres une validation : le
    PIEAFP se revise, et une revision qui porterait le meme numero que la piece
    deja transmise ne serait pas opposable.
    """

    courant = cycle_courant(exercice)
    version = courant.version
    if courant.statut != BROUILLON and demande.statut == BROUILLON:
        version += 1

    date_validation = demande.date_validation
    if demande.statut != BROUILLON and not date_validation:
        date_validation = date.today().isoformat()
    if demande.statut == BROUILLON:
        date_validation = None

    with database_manager.transaction() as connection:
        connection.execute(
            """
            UPDATE icaap_exercices
               SET statut = ?, date_validation = ?, organe = ?,
                   commentaire = ?, version = ?, modifie_le = ?
             WHERE exercice = ?
            """,
            (
                demande.statut,
                date_validation,
                demande.organe,
                demande.commentaire,
                version,
                _maintenant(),
                exercice,
            ),
        )

    return cycle_courant(exercice)


def _niveau(
    code: str,
    libelle: str,
    observe: float,
    minimum: float,
    assiette: float,
    *,
    coussin: float = CONSERVATION_BUFFER,
) -> NiveauRatio:
    """Un ratio confronte a son minimum, puis a ce minimum majore du coussin."""

    minimum_pct = minimum * 100.0
    avec_coussin_pct = (minimum + coussin) * 100.0

    if observe < minimum_pct:
        situation = DEPASSEE
    elif observe < avec_coussin_pct:
        situation = SOUS_COUSSIN
    else:
        situation = RESPECTEE

    return NiveauRatio(
        code=code,
        libelle=libelle,
        observe=round(observe, 3),
        minimum=round(minimum_pct, 3),
        exigence_avec_coussin=round(avec_coussin_pct, 3),
        ecart_minimum=round(observe - minimum_pct, 3),
        ecart_avec_coussin=round(observe - avec_coussin_pct, 3),
        situation=situation,
        fonds_propres_requis=round(assiette * (minimum + coussin), 2),
    )


def capital_reglementaire() -> CapitalReglementaire:
    """Le socle Pilier 1 de l'exercice en cours de declaration."""

    socle = socle_pilier1()
    apr_total = socle.rwa_total
    apr_marche = float(socle.rm_calc.get("rwa_marche", 0.0))

    exercice = socle.fp_data.get("exercice") or date.today().year
    cycle = cycle_courant(int(exercice))

    lignes = [
        ("credit", "Risque de crédit", socle.rwa_credit),
        ("marche", "Risque de marché", apr_marche),
        ("operationnel", "Risque opérationnel", socle.rwa_operationnel),
    ]
    exigences = [
        ExigenceRisque(
            code=code,
            libelle=libelle,
            apr=round(apr, 2),
            exigence=calculate_capital(apr),
            part=round(apr / apr_total * 100.0, 2) if apr_total > 0 else 0.0,
            angle_pilier2=_ANGLES_PILIER2[code],
        )
        for code, libelle, apr in lignes
    ]

    ratios = [
        _niveau(
            "cet1",
            "Fonds propres de base durs (CET1)",
            socle.ratios["cet1"]["value"],
            MIN_CET1_RATIO,
            apr_total,
        ),
        _niveau(
            "tier1",
            "Fonds propres de base (T1)",
            socle.ratios["tier1"]["value"],
            MIN_TIER1_RATIO,
            apr_total,
        ),
        _niveau(
            "solvabilite",
            "Ratio de solvabilité total",
            socle.ratios["solvency"]["value"],
            MIN_SOLVENCY_RATIO,
            apr_total,
        ),
        # Le coussin de conservation ne majore pas le levier : son assiette
        # n'est pas les actifs ponderes mais l'exposition de l'EP33. Le seuil
        # avec coussin y vaut donc le minimum.
        _niveau(
            "levier",
            "Ratio de levier",
            socle.ratios["leverage"]["value"],
            MIN_LEVERAGE_RATIO,
            socle.exposition_levier,
            coussin=0.0,
        ),
    ]

    exigence_avec_coussin = MIN_SOLVENCY_RATIO + CONSERVATION_BUFFER
    fonds_propres_requis = apr_total * exigence_avec_coussin
    disponibles = float(socle.fp_calc["total_capital"])

    exigence_globale = ExigenceGlobale(
        apr_total=round(apr_total, 2),
        minimum_solvabilite=round(MIN_SOLVENCY_RATIO * 100.0, 3),
        coussin_conservation=round(CONSERVATION_BUFFER * 100.0, 3),
        exigence_globale=round(exigence_avec_coussin * 100.0, 3),
        fonds_propres_requis=round(fonds_propres_requis, 2),
        fonds_propres_disponibles=round(disponibles, 2),
        marge=round(disponibles - fonds_propres_requis, 2),
    )

    return CapitalReglementaire(
        cycle=cycle,
        fonds_propres=socle.fp_detail,
        exigences=exigences,
        apr_total=round(apr_total, 2),
        exigence_totale=calculate_capital(apr_total),
        ratios=ratios,
        exigence_globale=exigence_globale,
        assiette_levier=round(socle.exposition_levier, 2),
        avertissements=_avertissements(socle, apr_marche),
    )


def _avertissements(socle, apr_marche: float) -> list[str]:
    """Ce qui empeche de conclure sur le socle.

    Le dispositif fait de l'integrite des donnees un point de controle du
    PIEAFP (composante « controle interne ») : une brique absente doit se voir,
    faute de quoi le socle affiche un zero aussi credible qu'un encours mesure.
    """

    messages: list[str] = []

    if not socle.fp_data:
        messages.append(
            "Aucun exercice de fonds propres saisi : les ratios se calculent "
            "sur un capital nul. Renseignez les fonds propres réglementaires."
        )
    elif socle.fp_data.get("exercice") is None:
        messages.append(
            "Les fonds propres en vigueur ne portent pas d'exercice : le cycle "
            "PIEAFP est rattaché à l'année en cours par défaut."
        )

    if socle.rwa_credit <= 0:
        messages.append(
            "Aucune exposition de crédit : l'APR crédit est nul. Importez le "
            "portefeuille avant d'exploiter ce socle."
        )
    if apr_marche <= 0:
        messages.append(
            "Risque de marché non renseigné : l'exigence correspondante est "
            "absente de l'assiette du ratio de solvabilité."
        )
    if socle.rwa_operationnel <= 0:
        messages.append(
            "Risque opérationnel non calculé : renseignez le PNB des trois "
            "derniers exercices dans le module Risque Opérationnel."
        )

    return messages
