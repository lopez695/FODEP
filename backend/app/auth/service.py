"""Regles metier de l'authentification."""

from __future__ import annotations

from dataclasses import dataclass

from app.auth.models import ROLES, UserProfile
from app.auth.repository import auth_repository
from app.auth.security import (
    InvalidTokenError,
    TYPE_RENOUVELLEMENT,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)


class AuthenticationError(RuntimeError):
    """Identifiants refuses ou session invalide."""


@dataclass(slots=True)
class SessionOuverte:
    """Resultat d'une connexion ou d'un renouvellement."""

    access_token: str
    expires_in: int
    refresh_token: str
    refresh_expire_le: object
    profil: UserProfile


def _profil(compte: dict) -> UserProfile:
    return UserProfile(
        identifiant=compte["identifiant"],
        role=compte["role"],
        nom_complet=compte["nom_complet"],
        derniere_connexion=compte["derniere_connexion"],
    )


def _ouvrir_session(compte: dict) -> SessionOuverte:
    access_token, expires_in = create_access_token(
        identifiant=compte["identifiant"],
        utilisateur_id=compte["id"],
        role=compte["role"],
    )
    refresh_token, session_id, expire_le = create_refresh_token(
        identifiant=compte["identifiant"],
        utilisateur_id=compte["id"],
        role=compte["role"],
    )
    auth_repository.open_session(
        session_id=session_id,
        utilisateur_id=compte["id"],
        jeton_hash=hash_refresh_token(refresh_token),
        expire_le=expire_le,
    )
    return SessionOuverte(
        access_token=access_token,
        expires_in=expires_in,
        refresh_token=refresh_token,
        refresh_expire_le=expire_le,
        profil=_profil(compte),
    )


def authentifier(identifiant: str, mot_de_passe: str) -> SessionOuverte:
    """Verifie les identifiants et ouvre une session."""

    compte = auth_repository.get_user(identifiant)
    # Meme message et meme chemin d'execution que le compte existe ou non :
    # une reponse differenciee permettrait d'enumerer les comptes valides.
    if compte is None or not verify_password(mot_de_passe, compte["mot_de_passe_hash"]):
        raise AuthenticationError("Identifiant ou mot de passe incorrect.")
    if not compte["actif"]:
        raise AuthenticationError("Ce compte est desactive.")
    if compte["role"] not in ROLES:
        raise AuthenticationError("Role inconnu : compte inutilisable.")

    auth_repository.touch_last_login(utilisateur_id=compte["id"])
    return _ouvrir_session(compte)


def renouveler(refresh_token: str) -> SessionOuverte:
    """Echange un jeton de renouvellement contre un nouveau couple de jetons.

    Le jeton presente est revoque dans la foulee (rotation) : reutiliser un
    ancien jeton ne donne donc rien, meme s'il n'a pas encore expire.
    """

    try:
        payload = decode_token(refresh_token, expected_type=TYPE_RENOUVELLEMENT)
    except InvalidTokenError as exc:
        raise AuthenticationError(str(exc)) from exc

    session_id = str(payload.get("jti") or "")
    session = auth_repository.get_active_session(
        session_id=session_id,
        jeton_hash=hash_refresh_token(refresh_token),
    )
    if session is None:
        raise AuthenticationError("Session inconnue ou revoquee.")

    compte = auth_repository.get_user(str(payload.get("sub") or ""))
    if compte is None or not compte["actif"]:
        raise AuthenticationError("Compte introuvable ou desactive.")

    auth_repository.revoke_session(session_id=session_id)
    return _ouvrir_session(compte)


def fermer_session(refresh_token: str | None) -> None:
    """Revoque la session portee par le cookie, si elle est encore valide."""

    if not refresh_token:
        return
    try:
        payload = decode_token(refresh_token, expected_type=TYPE_RENOUVELLEMENT)
    except InvalidTokenError:
        return
    session_id = str(payload.get("jti") or "")
    if session_id:
        auth_repository.revoke_session(session_id=session_id)


def creer_compte(
    *,
    identifiant: str,
    mot_de_passe: str,
    role: str,
    nom_complet: str | None = None,
) -> None:
    """Cree un compte applicatif."""

    identifiant = identifiant.strip()
    if not identifiant:
        raise ValueError("L'identifiant est obligatoire.")
    if role not in ROLES:
        raise ValueError(f"Role inconnu : {role}. Attendu : {' ou '.join(ROLES)}.")
    if len(mot_de_passe) < 12:
        raise ValueError(
            "Le mot de passe doit faire au moins 12 caracteres : ce compte "
            "ouvre l'acces a des donnees prudentielles."
        )
    if auth_repository.get_user(identifiant) is not None:
        raise ValueError(f"Le compte « {identifiant} » existe deja.")

    auth_repository.create_user(
        identifiant=identifiant,
        mot_de_passe_hash=hash_password(mot_de_passe),
        role=role,
        nom_complet=nom_complet,
    )


def changer_mot_de_passe(*, identifiant: str, mot_de_passe: str) -> None:
    """Remplace le mot de passe et coupe les sessions ouvertes."""

    if len(mot_de_passe) < 12:
        raise ValueError("Le mot de passe doit faire au moins 12 caracteres.")
    compte = auth_repository.get_user(identifiant)
    if compte is None:
        raise ValueError(f"Compte introuvable : {identifiant}.")

    auth_repository.update_password(
        identifiant=identifiant,
        mot_de_passe_hash=hash_password(mot_de_passe),
    )
    # Un mot de passe change parce qu'il a fuite : laisser vivre les sessions
    # ouvertes viderait la manoeuvre de son sens.
    auth_repository.revoke_user_sessions(utilisateur_id=compte["id"])


def changer_activation(*, identifiant: str, actif: bool) -> None:
    compte = auth_repository.get_user(identifiant)
    if compte is None:
        raise ValueError(f"Compte introuvable : {identifiant}.")
    auth_repository.set_active(identifiant=identifiant, actif=actif)
    if not actif:
        auth_repository.revoke_user_sessions(utilisateur_id=compte["id"])
