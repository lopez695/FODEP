"""Primitives cryptographiques : empreintes de mots de passe et jetons."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import secrets
import uuid

import bcrypt
import jwt

from app.core.config import settings

TYPE_ACCES = "acces"
TYPE_RENOUVELLEMENT = "renouvellement"

_MAX_PASSWORD_BYTES = 72


class AuthConfigurationError(RuntimeError):
    """Configuration d'authentification inutilisable."""


class InvalidTokenError(RuntimeError):
    """Jeton absent, expire, altere ou de mauvais type."""


def resolve_secret() -> str:
    """Retourne le secret de signature, ou refuse de continuer."""

    secret = settings.jwt_secret.strip()
    if not secret:
        raise AuthConfigurationError(
            "RWA_JWT_SECRET est vide : impossible de signer des jetons. "
            "Definissez un secret d'au moins 32 caracteres dans "
            "l'environnement avant de demarrer l'API."
        )
    if len(secret) < 32:
        raise AuthConfigurationError(
            "RWA_JWT_SECRET est trop court (moins de 32 caracteres) : un "
            "secret devinable rend les jetons forgeables."
        )
    return secret


def hash_password(password: str) -> str:
    """Calcule l'empreinte bcrypt d'un mot de passe."""

    encoded = password.encode("utf-8")
    if len(encoded) > _MAX_PASSWORD_BYTES:
        raise ValueError(
            "Le mot de passe depasse 72 octets, limite de bcrypt : "
            "au-dela, les caracteres supplementaires seraient ignores."
        )
    return bcrypt.hashpw(encoded, bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    """Compare un mot de passe a son empreinte, en temps constant."""

    encoded = password.encode("utf-8")
    if len(encoded) > _MAX_PASSWORD_BYTES:
        return False
    try:
        return bcrypt.checkpw(encoded, password_hash.encode("utf-8"))
    except ValueError:
        # Empreinte illisible (donnee corrompue) : on refuse, on n'ouvre pas.
        return False


def hash_refresh_token(token: str) -> str:
    """Empreinte du jeton de renouvellement conservee en base.

    Le jeton lui-meme n'est jamais stocke : une copie de la base ne suffit
    donc pas a rejouer une session ouverte.
    """

    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def create_access_token(*, identifiant: str, utilisateur_id: int, role: str) -> tuple[str, int]:
    """Cree un jeton d'acces court. Retourne le jeton et sa duree en secondes."""

    duree = timedelta(minutes=settings.access_token_minutes)
    emis_le = _now()
    payload = {
        "sub": identifiant,
        "uid": utilisateur_id,
        "role": role,
        "typ": TYPE_ACCES,
        "iat": emis_le,
        "exp": emis_le + duree,
    }
    token = jwt.encode(payload, resolve_secret(), algorithm=settings.jwt_algorithm)
    return token, int(duree.total_seconds())


def create_refresh_token(
    *,
    identifiant: str,
    utilisateur_id: int,
    role: str,
) -> tuple[str, str, datetime]:
    """Cree un jeton de renouvellement. Retourne le jeton, son identifiant et son expiration."""

    session_id = str(uuid.uuid4())
    duree = timedelta(hours=settings.refresh_token_hours)
    emis_le = _now()
    expire_le = emis_le + duree
    payload = {
        "sub": identifiant,
        "uid": utilisateur_id,
        "role": role,
        "typ": TYPE_RENOUVELLEMENT,
        "jti": session_id,
        # Un alea propre a chaque emission : deux rotations successives dans la
        # meme seconde produisent malgre tout deux jetons distincts.
        "nonce": secrets.token_urlsafe(8),
        "iat": emis_le,
        "exp": expire_le,
    }
    token = jwt.encode(payload, resolve_secret(), algorithm=settings.jwt_algorithm)
    return token, session_id, expire_le


def decode_token(token: str, *, expected_type: str) -> dict:
    """Valide un jeton et retourne sa charge utile.

    Un jeton de renouvellement presente comme jeton d'acces (ou l'inverse) est
    refuse : sans cette verification, le cookie de session vaudrait acces.
    """

    try:
        payload = jwt.decode(
            token,
            resolve_secret(),
            algorithms=[settings.jwt_algorithm],
        )
    except jwt.ExpiredSignatureError as exc:
        raise InvalidTokenError("Jeton expire.") from exc
    except jwt.InvalidTokenError as exc:
        raise InvalidTokenError("Jeton invalide.") from exc

    if payload.get("typ") != expected_type:
        raise InvalidTokenError("Type de jeton inattendu.")
    return payload
