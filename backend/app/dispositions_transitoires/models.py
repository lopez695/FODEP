"""Modeles des dispositions transitoires sur les fonds propres (EP04).

Le vocabulaire est celui du formulaire, jusqu'aux lettres de ses formules :
l'EP04 imprime « (f)=c+d+e », « (g)=fxa », « i=min(g,h) », et les champs
portent ici les noms des postes correspondants. Nommer les choses autrement
obligerait a traduire a l'export, c'est-a-dire a se tromper a deux endroits.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class DispositionsTransitoiresBase(BaseModel):
    """Les quatorze montants que l'EP04 demande, et rien d'autre.

    Le capital social libere (FPI01) n'y figure pas : l'EP03 le declare deja, et
    l'export le reporte. Le taux de retrait non plus : la BCEAO l'imprime sur le
    formulaire, ou l'export le relit.
    """

    # ─── Bloc A : elements de CET1 non admissibles ──────────────────────────
    #: (c) DT002 — part du capital social non admissible au 1er janvier 2018.
    part_capital_non_admissible: float = Field(default=0.0, ge=0)
    #: (d) DT003 — provisions reglementees non admissibles.
    provisions_reglementees: float = Field(default=0.0, ge=0)
    #: (e) DT004 — fonds affectes non admissibles.
    fonds_affectes: float = Field(default=0.0, ge=0)
    #: (h) DT007 — montant reel encore en circulation a la date de declaration.
    cet1_en_circulation: float = Field(default=0.0, ge=0)

    #: FPI25 — reclasse en fonds propres de base additionnels.
    cet1_eligible_at1: float = Field(default=0.0, ge=0)
    #: FPI33 — reclasse en fonds propres complementaires, autres instruments.
    cet1_eligible_t2_autres: float = Field(default=0.0, ge=0)
    #: FPI35 — reclasse en fonds propres complementaires, provisions reglementees.
    cet1_eligible_t2_provisions: float = Field(default=0.0, ge=0)
    #: FPI36 — reclasse en fonds propres complementaires, fonds affectes.
    cet1_eligible_t2_fonds_affectes: float = Field(default=0.0, ge=0)
    #: DT009 — exclu des fonds propres.
    cet1_exclu: float = Field(default=0.0, ge=0)

    # ─── Bloc B : elements de T2 non admissibles ────────────────────────────
    #: (j) DT010 — dettes subordonnees en circulation au 1er janvier 2018.
    dettes_subordonnees_2018: float = Field(default=0.0, ge=0)
    #: (k) DT011 — la part non admissible de ces dettes.
    part_dettes_non_admissible: float = Field(default=0.0, ge=0)
    #: (l) DT012 — ecarts de reevaluation.
    ecarts_reevaluation: float = Field(default=0.0, ge=0)
    #: (m) DT013 — autres elements de T2 non admissibles.
    autres_t2_non_admissibles: float = Field(default=0.0, ge=0)
    #: (p) DT016 — montant reel encore en circulation.
    t2_en_circulation: float = Field(default=0.0, ge=0)

    commentaire: str | None = None


class DispositionsTransitoiresUpdate(DispositionsTransitoiresBase):
    """Saisie d'un exercice.

    L'exercice est OBLIGATOIRE, pour la meme raison que sur les fonds propres :
    sans lui, une interface restee sur une version anterieure ecraserait
    silencieusement l'exercice courant avec les chiffres d'un autre.
    """

    exercice: int = Field(..., ge=2000, le=2100)


class DispositionsTransitoiresView(DispositionsTransitoiresBase):
    exercice: int
    cree_le: str
    modifie_le: str


class LigneEp04(BaseModel):
    """Une ligne de l'EP04, saisie, reportee ou calculee.

    L'ecran affiche l'etat tel qu'il partira, formule comprise : une saisie ne
    se verifie qu'en voyant ce qu'elle produit deux lignes plus bas.
    """

    code: str
    libelle: str
    #: La formule que le formulaire imprime en regard, quand il en imprime une.
    formule: str
    montant: float
    #: Comment la ligne est obtenue : « saisie », « reporte » (d'un autre etat)
    #: ou « calcule ».
    origine: str
    bloc: str


class SyntheseEp04(BaseModel):
    """L'EP04 tel que la declaration le portera."""

    exercice: int | None
    #: Le taux de retrait (a), releve sur le formulaire.
    taux_de_retrait: float
    lignes: list[LigneEp04]
    #: Les quatre montants qui retombent dans l'EP03.
    report_ep03: dict[str, float]
    renseigne: bool
    alertes: list[str]
