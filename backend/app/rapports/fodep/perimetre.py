"""Perimetre de la declaration : quels etats l'application alimente.

Ces trois constantes decrivent le partage du travail entre l'application et le
declarant. Elles sont isolees ici parce que deux modules en dependent : le
service qui construit le classeur, et le catalogue des saisies manuelles, qui
doit savoir exactement quels etats restent a la charge de l'utilisateur. Les
laisser dans le service creerait un cycle d'imports.
"""

from __future__ import annotations

# Base de declaration retenue par l'application. Les etats a renseigner en
# decoulent, et sont lus dans le formulaire (voir `lire_etats_requis`) plutot
# qu'enumeres ici : c'est la feuille « Liste des etats prudentiels a
# renseigner » qui fait foi.
BASE_DE_DECLARATION = "individuelle"

# Etats alimentes a partir des donnees de l'application.
ETATS_ALIMENTES: frozenset[str] = frozenset(
    {
        "EP01", "EP02", "EP03", "EP08", "EP09", "EP10",
        "EP12", "EP13", "EP14", "EP15", "EP16", "EP17", "EP18", "EP19",
        "EP20", "EP21", "EP22", "EP29", "EP30", "EP31", "EP32", "EP33",
        "EP34", "EP35", "EP36", "EP37", "EP38", "EP39",
    }
)

# Premiere colonne a mettre a zero lorsqu'un etat alimente laisse des cases
# vides. La valeur par defaut, la colonne C, convient aux etats entierement
# numeriques ; l'EP30 fait exception, ses colonnes C a G portant le numero
# Centrale des risques, la nature du lien, le nom, le pays et le secteur.
# Y ecrire des zeros donnerait une contrepartie nommee « 0 ».
PREMIERE_COLONNE_NUMERIQUE: dict[str, int] = {"EP30": 8}

# Etats qui declarent une liste : les grands risques, les clients des groupes
# lies, les cinquante plus gros engagements, les participations, les parties
# liees. Leur grille compte des dizaines de lignes pour le nombre d'entrees que
# l'etablissement a reellement, et une ligne vierge n'est pas une contrepartie
# qui ne doit rien -- c'est une ligne dont il n'a pas l'usage.
#
# Le balayage a zero les remplissait toutes : l'EP29 et l'EP32 partaient avec
# des contreparties dont le nom, le pays et le secteur valaient « 0 », l'EP30
# -- protege du zero par PREMIERE_COLONNE_NUMERIQUE mais pas du balayage -- avec
# des lignes portant des montants nuls sans aucune identification en face, et
# l'EP34, l'EP35 et l'EP39 avec respectivement 98, 22 et 49 lignes garnies sans
# denomination. Sur ces etats, le complement ne touche que les lignes entamees.
#
# L'EP31 et l'EP38 n'y figurent pas : leur grille compte exactement le nombre de
# lignes qu'ils declarent (les vingt plus grandes expositions, les categories de
# beneficiaires), sans ligne de reserve a garnir.
ETATS_EN_LISTE: frozenset[str] = frozenset(
    {"EP29", "EP30", "EP32", "EP34", "EP35", "EP39"}
)

# Etats sans source de donnees dans l'application. Ils sont declares a zero
# faute de mieux, sauf pour les cellules que le declarant a saisies a la main
# (voir `saisies.py`) : une saisie prime toujours sur le zero automatique.
#
#   EP3M         poste pour memoire de l'EP03 (impots differes, participations)
#   EP04         dispositions transitoires
#   EP11         expositions au risque de contrepartie (derives)
#   EP23, EP24   approche standard du risque operationnel, non retenue
#   EP28         produits de base : l'etablissement n'en detient aucun
#   EP25 a EP27  taux, actions et change : renseignes des que le module Risque
#                de Marche transmet ses positions, mis a zero sinon. Le
#                balayage n'ecrase jamais une valeur deja ecrite.
ETATS_DECLARES_A_ZERO: frozenset[str] = frozenset(
    {
        "EP3M", "EP04", "EP11", "EP23", "EP24",
        "EP25", "EP26", "EP27", "EP28",
    }
)
