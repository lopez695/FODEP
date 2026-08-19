"""Aides partagees par les tests, et isolation de la base.

La suite s'executait sur `backend/data/rwa_data.db` -- la base VERSIONNEE.
Chaque `pytest` la modifiait : le depot portait une modification apres chaque
execution, et l'etat d'un test dependait de ce qui avait tourne avant lui.

Rediriger le dossier de donnees vers un dossier temporaire suffit a tout
isoler : la base y est recopiee depuis la graine (`ensure_seed_data_file`),
comme les exports, les sauvegardes et les journaux. Le correctif tient dans le
`conftest` parce que pytest l'importe AVANT les modules de test : au moment ou
`database.connection` calcule `DATABASE_PATH`, le chemin est deja detourne.
Le faire plus tard n'aurait aucun effet, la constante etant fixee a l'import.

Le mode d'execution, lui, n'est pas touche : passer par `RWA_PACKAGED` aurait
aussi change la resolution du classeur Excel source, donc ce que les tests
verifient.

`routes_effectives` existe parce que la forme de `app.routes` depend de la
version de FastAPI installee :

- jusqu'a 0.115, `include_router` recopie les routes a plat dans `app.routes`, et
  chacune porte son `.path` et ses `.methods` ;
- a partir de 0.14x, elle y depose une enveloppe `_IncludedRouter` qui n'a ni
  l'un ni les autres, et qui garde le routeur d'origine dans `original_router`.

Deux tests parcourent ces routes, dont celui qui verifie qu'aucune route mutante
n'echappe a l'authentification. Sur la version la plus recente, ils ne voyaient
plus rien : le controle de securite ne s'executait plus, alors que c'est celle
qui tourne dans le venv du projet. Un releve vide n'est pas un releve conforme.
"""

from __future__ import annotations

import atexit
from pathlib import Path
import shutil
import tempfile

from app.core import runtime_paths

_DONNEES_DE_TEST = Path(tempfile.mkdtemp(prefix="rwa-tests-"))
runtime_paths.app_data_root = lambda: _DONNEES_DE_TEST


@atexit.register
def _effacer_les_donnees_de_test() -> None:
    # SQLite peut encore tenir un fichier ouvert sous Windows : un dossier qui
    # survit dans le repertoire temporaire est sans consequence, l'echec de la
    # suite pour cette raison ne le serait pas.
    shutil.rmtree(_DONNEES_DE_TEST, ignore_errors=True)


def routes_effectives(app) -> list:
    """Toutes les routes de l'application, a plat, quelle que soit la version.

    Les enveloppes de routeur sont depliees ; seules les routes portant un
    chemin sont retenues.
    """

    a_visiter = list(app.routes)
    routes: list = []
    while a_visiter:
        route = a_visiter.pop()
        routeur = getattr(route, "original_router", None)
        if routeur is not None:
            a_visiter.extend(getattr(routeur, "routes", []))
            continue
        if getattr(route, "path", None) is not None:
            routes.append(route)
    return routes
