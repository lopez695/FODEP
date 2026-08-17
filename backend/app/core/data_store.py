"""Ancien jeu de données en mémoire, désormais mort.

Ce module servait de bootstrap avant l'introduction de SQLite. Il n'est plus
importé nulle part dans le backend (toutes les données transitent par
database/repositories/ et database/orm_models/). Conservé vide pour
compatibilité si un import résiduel existait ; à supprimer définitivement
lors d'un prochain nettoyage de fichiers (le fichier ne peut pas être
supprimé automatiquement depuis cette session).
"""
