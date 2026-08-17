"""Fondation SQLAlchemy (moteur, session) — pilote de la migration ORM.

Ce module coexiste volontairement avec `database.connection.DatabaseManager` :
- `DatabaseManager` reste seul responsable de la création et de la migration
  du schéma (schema.sql + database/migrations/*.sql), exécutées au démarrage
  de l'application (voir app/main.py).
- Les modèles déclaratifs SQLAlchemy définis sous `database/orm_models/`
  se contentent de MAPPER des tables déjà existantes ; ils n'appellent jamais
  `Base.metadata.create_all()`.

L'objectif est de migrer progressivement chaque repository du SQL brut vers
l'ORM, module par module, en commençant par le plus simple (référentiels)
avant d'étendre le pattern aux modules plus complexes (expositions, CRM,
risque opérationnel, etc.).
"""

from __future__ import annotations

from contextlib import contextmanager
from typing import Iterator

from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from database.connection import DATABASE_PATH

# Même fichier SQLite que DatabaseManager — une seule source de vérité pour
# le chemin de la base, quel que soit le point d'accès (SQL brut ou ORM).
engine = create_engine(
    f"sqlite:///{DATABASE_PATH}",
    connect_args={"check_same_thread": False, "timeout": 30},
    future=True,
)


@event.listens_for(engine, "connect")
def _set_sqlite_pragmas(dbapi_connection, connection_record) -> None:  # noqa: ANN001
    """Aligne les PRAGMAs SQLite de l'ORM sur ceux de DatabaseManager.connect()."""
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys = ON")
    cursor.execute("PRAGMA journal_mode = WAL")
    cursor.execute("PRAGMA synchronous = NORMAL")
    cursor.execute("PRAGMA busy_timeout = 30000")
    cursor.close()


class Base(DeclarativeBase):
    """Base déclarative commune à tous les modèles ORM du projet."""


SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False, future=True)


@contextmanager
def orm_session() -> Iterator[Session]:
    """Fournit une session SQLAlchemy qui commit puis se ferme, avec rollback en cas d'erreur.

    Équivalent ORM de `database_manager.transaction()` / `read_connection()` :
    à utiliser dans les repositories migrés, un appel = une session courte.
    """
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
