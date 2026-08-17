"""Export du Formulaire de Déclaration Prudentielle (FODEP) de la BCEAO."""

from app.rapports.fodep.service import construire_fodep, nom_fichier_fodep

__all__ = ["construire_fodep", "nom_fichier_fodep"]
