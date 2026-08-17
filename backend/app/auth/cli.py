"""Commande d'administration des comptes.

Usage :
    python -m app.auth.cli creer --identifiant superieur --role consultation
    python -m app.auth.cli lister
    python -m app.auth.cli mot-de-passe --identifiant superieur
    python -m app.auth.cli desactiver --identifiant superieur

Le mot de passe n'est jamais passe en argument : il serait conserve dans
l'historique du shell et visible dans la liste des processus. Il est demande
de maniere masquee, ou lu dans la variable d'environnement RWA_NEW_PASSWORD
pour un provisionnement automatise.
"""

from __future__ import annotations

import argparse
import getpass
import os
import sys

from app.auth.models import ROLES
from app.auth.repository import auth_repository
from app.auth.service import changer_activation, changer_mot_de_passe, creer_compte
from database.connection import database_manager


def _lire_mot_de_passe() -> str:
    depuis_environnement = os.environ.get("RWA_NEW_PASSWORD")
    if depuis_environnement:
        return depuis_environnement

    premier = getpass.getpass("Mot de passe (12 caracteres minimum) : ")
    second = getpass.getpass("Confirmation : ")
    if premier != second:
        raise ValueError("Les deux saisies different.")
    return premier


def _creer(args: argparse.Namespace) -> int:
    creer_compte(
        identifiant=args.identifiant,
        mot_de_passe=_lire_mot_de_passe(),
        role=args.role,
        nom_complet=args.nom,
    )
    print(f"Compte « {args.identifiant} » cree avec le role {args.role}.")
    return 0


def _lister(_: argparse.Namespace) -> int:
    comptes = auth_repository.list_users()
    if not comptes:
        print("Aucun compte enregistre.")
        return 0
    print(f"{'IDENTIFIANT':<24} {'ROLE':<14} {'ETAT':<10} DERNIERE CONNEXION")
    for compte in comptes:
        etat = "actif" if compte["actif"] else "desactive"
        derniere = compte["derniere_connexion"] or "-"
        print(f"{compte['identifiant']:<24} {compte['role']:<14} {etat:<10} {derniere}")
    return 0


def _mot_de_passe(args: argparse.Namespace) -> int:
    changer_mot_de_passe(
        identifiant=args.identifiant,
        mot_de_passe=_lire_mot_de_passe(),
    )
    print(
        f"Mot de passe de « {args.identifiant} » remplace. "
        "Les sessions ouvertes ont ete revoquees."
    )
    return 0


def _activation(args: argparse.Namespace, actif: bool) -> int:
    changer_activation(identifiant=args.identifiant, actif=actif)
    etat = "reactive" if actif else "desactive"
    print(f"Compte « {args.identifiant} » {etat}.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m app.auth.cli",
        description="Administration des comptes de l'outil.",
    )
    sous_commandes = parser.add_subparsers(dest="commande", required=True)

    creer = sous_commandes.add_parser("creer", help="Cree un compte.")
    creer.add_argument("--identifiant", required=True)
    creer.add_argument("--role", required=True, choices=list(ROLES))
    creer.add_argument("--nom", default=None, help="Nom complet affiche.")
    creer.set_defaults(handler=_creer)

    lister = sous_commandes.add_parser("lister", help="Liste les comptes.")
    lister.set_defaults(handler=_lister)

    motdepasse = sous_commandes.add_parser(
        "mot-de-passe",
        help="Remplace le mot de passe d'un compte.",
    )
    motdepasse.add_argument("--identifiant", required=True)
    motdepasse.set_defaults(handler=_mot_de_passe)

    desactiver = sous_commandes.add_parser("desactiver", help="Desactive un compte.")
    desactiver.add_argument("--identifiant", required=True)
    desactiver.set_defaults(handler=lambda args: _activation(args, actif=False))

    reactiver = sous_commandes.add_parser("reactiver", help="Reactive un compte.")
    reactiver.add_argument("--identifiant", required=True)
    reactiver.set_defaults(handler=lambda args: _activation(args, actif=True))

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    # La table des comptes est creee par les migrations : la commande doit
    # pouvoir s'executer sur une base neuve, avant tout demarrage de l'API.
    database_manager.initialize()
    try:
        return int(args.handler(args))
    except ValueError as exc:
        print(f"Erreur : {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
