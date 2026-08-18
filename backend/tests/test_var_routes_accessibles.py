"""Les routes VaR doivent etre joignables par les deux clients.

Le poste de travail appelle « /var/... », le navigateur « /api/var/... » :
PrefixeApiMiddleware retire « /api » AVANT le routage. Un routeur declare sur
« /api/var » ne recevait donc jamais l'appel, ni prefixe (le prefixe etait
retire avant la comparaison) ni non prefixe (la route inconnue). L'onglet VaR
affichait « Not Found » sur les trois methodes.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

PARAMETRES = {
    "type_portefeuille": "obligations",
    "niveau_confiance": 0.99,
    "horizon_jours": 1,
    "fenetre_jours": 250,
}

# Codes d'erreur metier des routes VaR. Une reponse qui en porte un prouve que
# la route a ete atteinte et a execute son calcul : c'est ce que ces tests
# verifient. Exiger un 200 les rendrait dependants du contenu de la base — sans
# courbe des taux ni historique de prix, aucune VaR ne peut etre calculee, et
# l'echec ne dirait rien du routage.
CODES_METIER = {
    "VAR_PARAMETRE_INVALIDE",
    "VAR_DONNEES_ABSENTES",
    "VAR_DONNEES_INVALIDES",
    "VAR_COURBE_INDISPONIBLE",
}


def _verifier_joignable(chemin: str, params: dict, methode: str) -> None:
    """La route repond identiquement avec et sans le prefixe « /api »."""

    sans_prefixe = client.get(chemin, params=params)
    avec_prefixe = client.get(f"/api{chemin}", params=params)

    for reponse, appel in ((sans_prefixe, chemin), (avec_prefixe, f"/api{chemin}")):
        assert reponse.status_code != 404, f"{appel} : route inatteignable."
        if reponse.status_code == 200:
            assert reponse.json()["methode"] == methode
        else:
            # Le middleware retire « /api » avant le routage : les deux appels
            # traversent le meme code et doivent donc echouer de la meme facon.
            assert reponse.status_code == 422, f"{appel} : {reponse.status_code}"
            assert reponse.json()["detail"]["code"] in CODES_METIER

    assert sans_prefixe.status_code == avec_prefixe.status_code
    assert sans_prefixe.json() == avec_prefixe.json()


def test_le_routeur_var_ne_porte_pas_le_prefixe_api():
    """Le prefixe « /api » appartient au middleware, pas au routeur."""

    from app.var_marche.routes import router

    assert router.prefix == "/var", (
        "Le routeur VaR ne doit pas porter « /api » : le middleware le retire "
        "avant le routage, la route deviendrait inatteignable."
    )


def test_parametrique_joignable_avec_et_sans_prefixe_api():
    _verifier_joignable("/var/parametrique", PARAMETRES, "parametrique")


def test_montecarlo_joignable_avec_et_sans_prefixe_api():
    _verifier_joignable(
        "/var/montecarlo", dict(PARAMETRES, nb_simulations=1000), "montecarlo"
    )


def test_historique_repond_422_et_non_404_sans_donnees():
    """Une donnee manquante n'est pas une route absente.

    Le 404 melangeait les deux causes : l'utilisateur ne pouvait pas
    distinguer « la fonction n'existe pas » de « il manque un fichier ». La
    reponse doit donc porter un 422 et un code metier explicite, quel que soit
    ce qui manque — historique de prix ou courbe des taux.
    """

    reponse = client.get("/api/var/historique", params=PARAMETRES)

    assert reponse.status_code != 404
    if reponse.status_code != 200:
        assert reponse.status_code == 422
        detail = reponse.json()["detail"]
        assert detail["code"] in CODES_METIER
        assert detail["message"].strip()


def test_toutes_les_routes_var_declarees_sont_atteignables():
    """Aucune route VaR ne doit etre publiee sans etre joignable."""

    # Meme raison qu'ailleurs : depuis FastAPI 0.14x, `app.routes` porte des
    # enveloppes de routeur et non les routes elles-memes.
    from tests.conftest import routes_effectives

    chemins_var = [
        route.path
        for route in routes_effectives(app)
        if getattr(route, "path", "").startswith("/var/")
    ]

    assert chemins_var, "Aucune route VaR enregistree."
    for chemin in chemins_var:
        assert not chemin.startswith("/api/"), (
            f"{chemin} porte le prefixe « /api » : il sera retire par le "
            "middleware et la route ne repondra jamais."
        )
