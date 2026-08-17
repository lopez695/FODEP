#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Script pour corriger les guillemets typographiques dans les fichiers Dart."""

import sys

def fix_quotes(filepath):
    """Remplace les guillemets typographiques par des guillemets standards."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_length = len(content)

    # Remplacer les guillemets typographiques simples
    content = content.replace('‘', "'")  # '
    content = content.replace('’', "'")  # '

    # Remplacer les guillemets typographiques doubles
    content = content.replace('“', '"')  # "
    content = content.replace('”', '"')  # "

    # Guillemets français
    content = content.replace('«', '"')  # «
    content = content.replace('»', '"')  # »

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    changes = original_length != len(content)
    print(f"Fichier corrigé: {filepath}")
    print(f"Changements: {'Oui' if changes else 'Non'}")
    return changes

if __name__ == '__main__':
    filepath = sys.argv[1] if len(sys.argv) > 1 else 'lib/modules/concentration/screens/concentration_screen.dart'
    fix_quotes(filepath)
