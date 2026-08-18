"""Aides partagees par les tests.

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
