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

- **EP28** — produits de base. Il a une source : le module Risque de Marché le
  renseigne dès que des positions sur produits de base lui sont transmises. Il
  est à zéro parce que l'établissement n'en détient aucune, ce que l'export
  énonce comme un constat et non comme une lacune. Son catalogue de saisie
  manuelle subsiste dans `saisies.py` mais n'est pas exposé : `ETATS_A_SAISIR`
  est vide, et l'écran ne propose que l'attestation ;
- **EP3M** — poste mémoire des déductions de fonds propres, alimenté par les
  participations et les immobilisations incorporelles, donc à zéro tant que
  celles-ci ne sont pas déclarées. L'export nomme les états qui partent ainsi à
  zéro, parce qu'un zéro transmis affirme que l'établissement n'en détient
  aucun ;
- **détail des fonds propres** — l'application collecte douze agrégats là où
  l'EP03 porte une quarantaine de lignes. Les totaux sont justes, mais les
  déductions sont massées sur FPI21 et FPI27, et celles du Tier 2 retranchées
  du total sans ligne détaillée ;
- **numéro Centrale des risques** — porté quand la fiche de la contrepartie le
  renseigne ; l'export compte les lignes qui en manquent ;
- **engagements de financement** — l'application décrit un engagement hors
  bilan par son niveau de risque, sans distinguer sa nature : tout le hors
  bilan est donc déclaré dans le bloc « Autres engagements hors bilan » ;
- **créances en souffrance et à risque élevé** — le FODEP les maintient dans
  leur catégorie d'origine, que l'application ne conserve pas ; elles sont
  rattachées à l'immobilier résidentiel lorsque le drapeau correspondant est
  posé, aux entreprises sinon.

## L'EP04 et les dispositions transitoires

Bâle III a rendu inadmissibles certains éléments de fonds propres au
1er janvier 2018 et les retire par paliers : un taux, appliqué au stock de
l'époque, dit combien on peut encore en compter. L'EP04 porte ce calcul.

L'état n'avait pas de source. Trois clés de l'EP03 — `fpi07_transitoire`,
`fpi25_transitoire`, `fpi33_transitoire` — étaient lues sur la table
`fonds_propres`, qui ne les a jamais portées : elles valaient zéro à chaque
export, sans que rien ne le dise. L'EP04 partait à zéro avec elles.

Le module `app.dispositions_transitoires` tient les **quatorze montants** que
l'état demande, un enregistrement par exercice — le stock de référence est celui
de 2018, mais ce qui reste en circulation change chaque année. Le reste, l'export
le calcule : les sept lignes dont le formulaire imprime la formule en tête
(« f = c+d+e », « g = f x a », « i = min(g,h) », et leurs jumelles en T2).

Deux choses ne se saisissent pas, et c'est délibéré.

Le **capital social libéré** (FPI01) est reporté de l'EP03, où il est déjà
déclaré. Le redemander exposerait à deux réponses différentes à la même
question.

Le **taux de retrait** (DT001) est relu sur le formulaire. Sa cellule y est
verrouillée : ce n'est ni au déclarant ni à l'application de le choisir. Il
s'abaisse d'un exercice à l'autre, et c'est la nouvelle version du formulaire
qui le dira — exactement comme les pondérations de l'EP11.

Quatre lignes retombent dans l'EP03 : **FPI07** en CET1, **FPI25** en AT1,
**FPI33** et **FPI34** en T2. L'EP03 vient donc après l'EP04, comme il vient
après les états de limites.

Deux lignes n'y retombent pas, bien que l'EP04 les détaille : **FPI35**
(provisions réglementées) et **FPI36** (fonds affectés). L'EP03 les déclare de
son côté, à partir des provisions générales que l'application enregistre. Les
reporter aussi ferait porter deux valeurs à un même code DISPRU, et la
plate-forme lirait une déclaration qui se contredit. L'export le signale au lieu
de trancher à la place du déclarant.

L'écran vit sur la page des fonds propres, là où le montant se déclare : la
saisie à gauche, l'état produit à droite, formules comprises. Une valeur ne se
vérifie qu'en voyant ce qu'elle produit deux lignes plus bas.

## L'EP11 et le registre des dérivés

L'EP11 déclare le risque de contrepartie porté par les dérivés : swaps de taux,
change à terme, contrats sur titres de propriété ou sur produits de base. Il
n'avait pas de source. Il fut d'abord saisi cellule par cellule sur l'écran des
saisies FODEP, puis plus du tout — la saisie manuelle a été retirée de l'écran
et l'état partait à zéro sans qu'on puisse le corriger, le formulaire affirmant
ainsi que l'établissement ne détient aucun dérivé.

Le module `app.derives` remplace la saisie de cellules par la saisie de
**contrats**. Un contrat porte ce que l'état réclame et rien de plus : sa
nature, sa contrepartie, son notionnel, son coût de remplacement, son échéance.
Quinze lignes se déduisent de deux dimensions — cinq natures de sous-jacent,
trois tranches de durée — et les cinq colonnes de ventilation sont les cinq
catégories d'expositions du formulaire, les mêmes lettres que pour les états
EP12 à EP16.

La **contrepartie se choisit dans le portefeuille**, par son identifiant
(`EXP-2026-…`) — migration 046. Son nom et sa catégorie ne se saisissent pas :
ils se lisent sur la fiche, et la colonne de l'EP11 se déduit de la catégorie
prudentielle par `resolve_category`, la fonction même du moteur de calcul. Un
dérivé et un prêt sur le même tiers ne peuvent donc plus tomber dans deux
catégories différentes, ni la même banque apparaître sous trois graphies. Un
identifiant inconnu est refusé : un dérivé se rattache à un tiers que
l'application connaît, ou ne s'enregistre pas.

Les catégories sans colonne sur l'EP11 — clientèle de détail, immobilier,
créances en souffrance, autres actifs — se rangent sous « Entreprises », le
repli du formulaire, et l'écran comme l'export le signalent. Le nom et la
colonne sont aussi recopiés sur le contrat à l'enregistrement : tant que la
fiche existe, c'est elle qui fait foi ; si elle disparaît, le contrat reste
lisible.

**L'exposition ne s'arrête pas à l'EP11.** Elle entre dans les actifs
pondérés par le bloc « risque de contrepartie » des EP12 à EP16 — les cinq
états qui l'offrent, un par colonne de ventilation — et dans l'exposition du
ratio de levier (EP33, ligne RL005). La pondération appliquée est celle de la
contrepartie qui a signé, lue par `lookup_prudential_risk_weight`, la fonction
même qui pondère ses prêts : un dérivé et un crédit sur le même tiers ne
peuvent pas être pondérés différemment. Une pondération que l'état n'imprime
pas — il n'en propose que cinq ou six — monte à la ligne supérieure plutôt que
de disparaître.

La durée résiduelle y est mesurée à la date d'arrêté, comme sur l'EP11 : celle
que le registre affiche a été calculée le jour de la lecture, et un contrat à
quatorze mois changerait de ligne d'un état à l'autre.

Trois choix méritent d'être connus.

La **durée est résiduelle**, mesurée à la date d'arrêté. Le registre garde
l'échéance et non une tranche : un contrat à sept ans conclu il y a trois ans se
déclare sur « > 1 an jusqu'à 5 ans », et une tranche stockée aurait gelé la
déclaration au jour de la saisie. Un contrat échu ne disparaît pas — il tombe
dans la première tranche, où le notionnel des instruments de taux est pondéré à
zéro.

La **pondération vient du formulaire**, pas du code. C'est la BCEAO qui la fixe,
bloc par bloc et tranche par tranche ; `_ponderation_imprimee` la relit dans la
colonne (c), où elle est écrite tantôt « 1,5 % » et tantôt 0,015. La recopier
dans le code en ferait une seconde source à corriger à chaque version du
formulaire.

La **ventilation ne peut plus se contredire**. Quand ces colonnes se
saisissaient à la main, l'export devait vérifier qu'elles retrouvaient
l'exposition de la ligne et le signaler quand ce n'était pas le cas. Elles se
déduisent désormais des contrats : chaque contrepartie reçoit sa part du coût de
remplacement et sa part du notionnel pondéré, et la somme retombe par
construction. Le contrôle est devenu un invariant, et le test qui le tenait
énonce l'invariant plutôt que l'alerte.

Un registre vide déclare toujours zéro — mais c'est alors un zéro constaté, que
l'export énonce comme tel.

## L'EP21 se confronte au compte de résultat

Le produit brut de l'approche indicateur de base se saisit exercice par
exercice, dans un registre à part. Les états financiers du module Risque
Opérationnel portent par ailleurs un produit net bancaire — c'est d'eux que
l'écran CRR3 tire son propre comparatif « indicateur de base »
(`ofr_bia = pnb_moyen x alpha`).

Rien ne rapprochait les deux. Un registre resté à des montants d'essai
déclarait un APR opérationnel de 3 millions quand le compte de résultat portait
84 milliards de PNB — trois millièmes de pour cent de l'APR total, sans qu'une
seule ligne de l'export ne le signale. L'EP21 compare désormais les deux
exercice par exercice et nomme l'écart dès qu'il dépasse 10 %, marge laissée
aux retraitements que l'article 301 prévoit et qu'il n'appartient pas à l'export
de trancher.

## Une contrepartie est un identifiant, pas un nom

Les états EP29 à EP32 et l'EP38 agrègent les expositions par contrepartie.
Cette agrégation se faisait par **nom** : sur le portefeuille de référence, 162
noms sont portés par plusieurs contreparties distinctes, et deux clients
homonymes devenaient un seul risque. La division des risques s'en trouvait
déclarée à 27,4 % là où le plus gros risque réel en vaut 18,2 %, et l'EP38
comptait deux fois les concours d'une partie liée homonyme d'une autre — 29,8
Md déclarés pour 19,6 Md réels, avec la déduction de fonds propres
correspondante.

La clé est désormais l'identifiant (`counterparty_id`, exposé par le dépôt des
expositions), le nom restant dans l'agrégat puisque c'est lui que le formulaire
imprime. Le numéro Centrale des risques se lit de même par identifiant : deux
homonymes gardent chacun le leur.

## L'EP39 déclare des montants, pas des croix

L'état ne recense pas toutes les parties liées : son titre fixe le seuil, 5 %
des fonds propres effectifs. L'export y portait une croix par bénéficiaire,
quel que soit son encours ; la colonne TOTAL partait donc à zéro, en
contradiction avec les encours de l'EP38 déclarés deux feuilles plus tôt.

Chaque ligne porte maintenant le montant du bénéficiaire dans la colonne de sa
catégorie, et la ligne TOTAL les additionne. Les fonds propres retenus sont
ceux de l'exercice précédent, comme pour la limite de l'EP38 : les deux états
se lisent ensemble, et un même encours ne peut pas être rapporté à deux
dénominateurs différents.

## Les limites prudentielles et les fonds propres

Six normes se mesurent en rapportant un encours aux fonds propres, et quatre
d'entre elles ont une ligne de déduction en EP03 : PA149 (participations dans
des entités commerciales), IM006 (immobilisations hors exploitation), IM010
(total des immobilisations et participations), PR004 (concours aux parties
liées). Franchir une limite n'est pas seulement un constat porté sur l'EP01 —
c'est un montant qui sort des fonds propres de base, et avec lui les trois
ratios de solvabilité.

Le dénominateur est celui de l'**exercice précédent**. Les états EP35 à EP38 le
disent en note de pied — « *** de l'exercice précédent » — et ce n'est pas une
convention de présentation : mesurer sur les fonds propres de l'année en cours
rendrait la déduction circulaire, puisqu'elle abaisse le CET1, ce qui relève le
ratio, ce qui augmente l'excédent. Rapporté à un millésime clos, l'excès est un
nombre fixe et la déduction se pose en une passe.

L'ordre de remplissage en découle : l'EP03 vient **après** les EP35 à EP38, et
non avant. Un CET1 calculé avant eux serait celui d'avant la déduction, et
l'EP02, l'EP29, l'EP33 et l'EP01 le reprendraient tel quel.

Le calcul vit dans `app.core.limites_prudentielles`, hors du FODEP : le tableau
de bord retranche le même montant, sans quoi l'écran et la déclaration
annonceraient deux CET1 différents — c'est ce que vérifie
`test_le_fodep_declare_les_memes_chiffres_que_l_application`. Son assiette,
elle, s'assemble ici, où vivent les lectures des participations, des
immobilisations et des concours aux parties liées ; `excedents_de_limites_courants`
la rend au tableau de bord plutôt que de le laisser relire les mêmes encours.

Sans exercice antérieur enregistré, les limites n'ont pas de dénominateur :
rien n'est déduit, les six normes de l'EP01 partent à « CONFORME » sans avoir
été mesurées, et l'export le dit.

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

L'inverse arrive aussi : plus de clients que de lignes. L'**EP30** offre une
centaine de lignes pour les membres des groupes de clients liés, et le tri de
lecture — par nom de groupe, puis par nom de client — écartait la queue de
l'alphabet. Sur le portefeuille de référence, cela revenait à ne déclarer qu'un
quart de l'exposition des groupes.

`_groupes_retenus_ep30` y substitue deux règles. Les groupes les plus exposés
passent devant, leurs clients aussi : ce qui manque est ce qui pèse le moins.
Et un groupe entre entier ou pas du tout — l'EP30 sert à vérifier que les
grands risques de l'EP29 additionnent les bons clients, et un groupe déclaré à
moitié y montre une somme qui ne retombe pas, ce qui se lit comme une erreur de
calcul plutôt que comme une omission. Un groupe qui ne tient pas dans les
lignes restantes est donc sauté au profit du suivant, plus petit.

L'ordre est le même que la grille suffise ou non : un état dont la disposition
basculerait le jour où un client de plus entre ne se comparerait pas d'un
arrêté à l'autre. Reste le cas où un seul groupe dépasse la grille entière —
aucune règle ne le sauve : il est tronqué de ses plus petits clients, et
l'export le signale à part.

Deux colonnes de ces états sont codées, et non libellées : « Groupe ou
individuel » de l'EP29 vaut « 1 » ou « 2 » (§ 11.1), « Catégorie de lien » de
l'EP30 vaut « a » ou « b » (§ 11.2). L'application n'agrégeant pas les groupes
de clients liés dans l'EP29, la portée y est toujours « 1 » — ce que l'export
signale.

Le **numéro d'identification Centrale des risques** est porté par les quatre
états qui identifient une contrepartie : l'EP30 le lit sur le groupe, l'EP29,
l'EP31 et l'EP32 sur la contrepartie (`contreparties.numero_centrale_risques`).
L'EP31 le laissait vide — ses vingt lignes partaient sans identifiant, alors
que le formulaire ouvre la colonne comme sur les autres. Les lignes dont la
fiche ne porte pas ce numéro laissent la colonne vide, et l'export les compte
en réserve.

Conséquence à connaître sur l'**EP01** : sa colonne « Situation de
l'établissement » est calculée par le formulaire, et un niveau observé nul y
devient « CONFORME ». Une norme que l'application ne peut pas mesurer — faute
de participations suivies, ou faute d'exercice antérieur — est donc annoncée
conforme sans l'avoir été. L'export le signale explicitement.

## Cohérence avec le reste de l'application

`test_le_fodep_declare_les_memes_chiffres_que_l_application` compare les APR et
les fonds propres du formulaire à ceux du tableau de bord. Les trois écarts
historiques — provisions non déduites de l'EAD, multiplicateur d'APR
opérationnel divergent, effet d'atténuation non plafonné — sont corrigés dans
le moteur de calcul, pas contournés dans l'export.
