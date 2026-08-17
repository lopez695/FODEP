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

- **EP22 à EP24** — approche standard du risque opérationnel ;
- **EP25 à EP28** — détail du risque de marché : le module ne conserve qu'un
  APR global, reporté sur la ligne de total de l'EP08 ;
- **EP30, EP34, EP35** — groupes de clients liés et participations. Ces états
  portent des colonnes d'identification qu'aucun zéro ne remplace : ils
  restent à saisir à la main ;
- **EP36 à EP39** — limites sur immobilisations et prêts aux actionnaires ;
- **engagements de financement** — l'application décrit un engagement hors
  bilan par son niveau de risque, sans distinguer sa nature : tout le hors
  bilan est donc déclaré dans le bloc « Autres engagements hors bilan » ;
- **créances en souffrance et à risque élevé** — le FODEP les maintient dans
  leur catégorie d'origine, que l'application ne conserve pas ; elles sont
  rattachées à l'immobilier résidentiel lorsque le drapeau correspondant est
  posé, aux entreprises sinon.

Une colonne reste vide sur les états qui la portent (EP29, EP31, EP32) : le
**numéro d'identification Centrale des risques**, que l'application ne
conserve pas.

Conséquence à connaître sur l'**EP01** : sa colonne « Situation de
l'établissement » est calculée par le formulaire, et un niveau observé nul y
devient « CONFORME ». Les six normes adossées aux états EP34 à EP38
(participations, immobilisations, prêts aux actionnaires) sont donc annoncées
conformes sans avoir été mesurées. L'export le signale explicitement.

## Cohérence avec le reste de l'application

`test_le_fodep_declare_les_memes_chiffres_que_l_application` compare les APR et
les fonds propres du formulaire à ceux du tableau de bord. Les trois écarts
historiques — provisions non déduites de l'EAD, multiplicateur d'APR
opérationnel divergent, effet d'atténuation non plafonné — sont corrigés dans
le moteur de calcul, pas contournés dans l'export.
