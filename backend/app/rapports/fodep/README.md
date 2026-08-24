# Export FODEP

Le FODEP est le **Formulaire de Déclaration Prudentielle** des établissements
de crédit de l'UMOA : un classeur de 44 feuilles défini par la BCEAO, transmis
tel quel à sa plate-forme de reporting.

L'application ne reconstruit pas ce classeur. Elle part du formulaire officiel
livré ici (`modele_fodep.xlsx`) et n'écrit que les cellules de saisie : la mise
en page, les libellés, les codes DISPRU et les coefficients réglementaires font
foi et ne sont jamais retouchés.

## Organisation

| Fichier           | Rôle |
| ----------------- | ---- |
| `disposition.py`  | Relit la structure des états dans le modèle (blocs, pondérations, codes DISPRU) plutôt que de la coder en dur. |
| `agregation.py`   | Traduit les expositions de l'application dans les catégories et pondérations du formulaire. |
| `service.py`      | Renseigne chaque état et produit le classeur. |
| `modele_fodep.xlsx` | Le formulaire officiel, vierge. |

## Régénérer le modèle

Quand la BCEAO publie une nouvelle version du formulaire :

```bash
python scripts/preparer_modele_fodep.py "chemin/vers/FODEP.xlsx"
```

Le script retire les données déclarées du FODEP fourni en s'appuyant sur le
verrouillage des cellules posé par la BCEAO — seules les cases à renseigner
sont déverrouillées — et écrit le résultat dans `modele_fodep.xlsx`.

Un FODEP réel contient les encours et les noms de clients d'un établissement :
le test `test_le_modele_ne_contient_aucune_donnee_declaree` vérifie que rien
n'en subsiste dans le modèle livré.

Le code relisant la disposition dans le modèle, un décalage de lignes ou une
pondération ajoutée par la BCEAO est absorbé sans modification du code. Un
changement de structure plus profond (une colonne déplacée, un état renommé)
fait en revanche échouer les tests d'export, qui contrôlent les invariants du
formulaire : bouclage de la colonne « Garanties », cohérence des totaux, APR
égal à l'exposition multipliée par sa pondération.

## Périmètre de la déclaration

Il n'est pas codé en dur. La feuille « Liste des états prudentiels à
renseigner » coche chaque état pour les trois bases de déclaration ;
`lire_etats_requis` en déduit le périmètre de la base retenue
(`BASE_DE_DECLARATION`, aujourd'hui *individuelle*). Les états EP05, EP5M,
EP06 et EP07 en sortent donc d'eux-mêmes : le formulaire ne les exige que sur
base sous-consolidée ou consolidée.

Chaque état requis est ensuite soit alimenté, soit déclaré à zéro s'il est
entièrement numérique, soit signalé à l'utilisateur. Un état exigé ne peut pas
rester vide sans que l'export le dise — c'est ce que vérifie
`test_les_etats_requis_sont_declares_ou_signales`.

## Ce que l'export ne couvre pas encore

Ces réserves voyagent dans l'en-tête `X-Fodep-Anomalies` de la réponse et
s'affichent dans une fenêtre de l'écran Reporting global :

- **EP04, EP11, EP28** — dispositions transitoires, risque de contrepartie sur
  dérivés, produits de base. L'application n'a aucune source pour ces postes et
  n'en aura pas tant qu'elle ne suivra pas ces instruments : ils se **saisissent
  à la main** sur l'écran des saisies FODEP (`ETATS_A_SAISIR` dans
  `saisies.py`), et retombent à zéro si on les laisse vides ;
- **EP3M** — poste mémoire des déductions de fonds propres, alimenté par les
  participations et les immobilisations incorporelles, donc à zéro tant que
  celles-ci ne sont pas déclarées. L'export nomme les états qui partent ainsi à
  zéro, parce qu'un zéro transmis affirme que l'établissement n'en détient
  aucun ;
- **détail des fonds propres** — l'application collecte douze agrégats là où
  l'EP03 porte une quarantaine de lignes. Les totaux sont justes, mais les
  déductions sont massées sur FPI21 et FPI27, et celles du Tier 2 retranchées
  du total sans ligne détaillée ;
- **excédents de limites** — l'EP03 porte une ligne de déduction par limite
  prudentielle (PA149, IM006, IM010, PR004). Les états qui *mesurent* ces
  limites sont renseignés, mais leur excédent n'est pas reporté sur les fonds
  propres : au premier dépassement le CET1 déclaré serait surestimé, ce que
  l'export signale au lieu de le laisser passer ;
- **fonds propres de l'exercice précédent** — les EP36, EP37 et EP38 rapportent
  leurs limites aux fonds propres de l'exercice précédent. L'application n'en
  conserve qu'un instantané : le dénominateur est celui de l'exercice déclaré ;
- **numéro Centrale des risques** — porté quand la fiche de la contrepartie le
  renseigne ; l'export compte les lignes qui en manquent ;
- **engagements de financement** — l'application décrit un engagement hors
  bilan par son niveau de risque, sans distinguer sa nature : tout le hors
  bilan est donc déclaré dans le bloc « Autres engagements hors bilan » ;
- **créances en souffrance et à risque élevé** — le FODEP les maintient dans
  leur catégorie d'origine, que l'application ne conserve pas ; elles sont
  rattachées à l'immobilier résidentiel lorsque le drapeau correspondant est
  posé, aux entreprises sinon.

## Les cases que le déclarant renseigne lui-même

`saisies.py` en tient le catalogue, et `appliquer_saisies` les écrit dans le
classeur **avant** tout balayage : une case saisie n'est jamais recouverte par
un zéro automatique, et une case laissée vide y retombe.

L'attestation ADPE est relevée champ par champ — c'est une lettre posée sur un
quadrillage, la règle générale des cases ouvertes y désignerait des centaines de
cellules sans objet. Les trois états prudentiels, eux, ne sont pas énumérés :
leurs cases sont relues dans le modèle, désignées par le verrouillage que la
BCEAO y a posé, avec leur code DISPRU, leur poste et leur en-tête de colonne.
Une case ajoutée par une nouvelle version du formulaire apparaît donc à l'écran
sans toucher au code.

Ces cases sont écrites **telles quelles**, sans conversion : elles se saisissent
dans l'unité du formulaire — le million de FCFA (§ 2.3) — là où les montants que
l'application calcule sont ramenés au million par `_ecrire_montant`. L'écran le
rappelle sur chaque état.

Deux catégories de cases ouvertes ne sont pas proposées à la saisie, parce que
l'export les calcule : les colonnes dont le formulaire imprime la formule en
tête — l'EP11 annonce « d=b x c » et « e= a + d » — et les lignes de total.
`COLONNES_CALCULEES` et `LIGNES_DE_TOTAL` les désignent, `_remplir_ep11` les
produit après l'application des saisies. C'est trente-neuf cases de moins à
remplir sur l'EP11, et autant d'occasions de se tromper. L'export vérifie au
passage que la ventilation par catégorie de contrepartie retrouve bien
l'exposition de la ligne.

## Les états qui déclarent une liste

L'EP29, l'EP30, l'EP32, l'EP34, l'EP35 et l'EP39 (`ETATS_EN_LISTE`) offrent des
dizaines de lignes pour le nombre d'entrées que l'établissement a réellement.
Le complément à zéro ne touche que les lignes déjà entamées : une ligne à
laquelle rien n'a été écrit reste vierge, montants compris. La règle générale —
aucune case de saisie laissée vide (notice, § 3.3) — vaut pour les lignes
déclarées, pas pour celles dont l'établissement n'a pas l'usage ; les remplir
toutes faisait partir la déclaration avec des dizaines de contreparties sans
nom déclarant zéro.

L'EP31 et l'EP38 n'en sont pas : leur grille compte exactement le nombre de
lignes qu'ils déclarent, sans ligne de réserve à garnir.

Deux colonnes de ces états sont codées, et non libellées : « Groupe ou
individuel » de l'EP29 vaut « 1 » ou « 2 » (§ 11.1), « Catégorie de lien » de
l'EP30 vaut « a » ou « b » (§ 11.2). L'application n'agrégeant pas les groupes
de clients liés dans l'EP29, la portée y est toujours « 1 » — ce que l'export
signale.

Le **numéro d'identification Centrale des risques** est porté par les trois
états qui identifient une contrepartie : l'EP30 le lit sur le groupe, l'EP29 et
l'EP32 sur la contrepartie (`contreparties.numero_centrale_risques`). Les
lignes dont la fiche ne porte pas ce numéro laissent la colonne vide, et
l'export les compte en réserve.

Conséquence à connaître sur l'**EP01** : sa colonne « Situation de
l'établissement » est calculée par le formulaire, et un niveau observé nul y
devient « CONFORME ». Les six normes adossées aux états EP34 à EP38
(participations, immobilisations, prêts aux actionnaires) sont donc annoncées
conformes sans avoir été mesurées. L'export le signale explicitement.

Le franchissement de ces six normes est signalé de son côté : le formulaire le
constate sur l'EP01, mais l'excédent devrait aussi se déduire des fonds propres
en EP03, ce que l'export ne fait pas encore. Il refuse en revanche de laisser
passer le dépassement en silence — voir
`test_un_depassement_de_limite_est_signale_comme_non_deduit`.

## Cohérence avec le reste de l'application

`test_le_fodep_declare_les_memes_chiffres_que_l_application` compare les APR et
les fonds propres du formulaire à ceux du tableau de bord. Les trois écarts
historiques — provisions non déduites de l'EAD, multiplicateur d'APR
opérationnel divergent, effet d'atténuation non plafonné — sont corrigés dans
le moteur de calcul, pas contournés dans l'export.
