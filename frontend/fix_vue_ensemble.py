#!/usr/bin/env python3
"""Script to fix compilation errors in vue_ensemble_screen.dart."""

import sys
import re

file_path = r"C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\lib\modules\vue_ensemble\screens\vue_ensemble_screen.dart"

print(f"Reading {file_path}...")
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
except Exception as e:
    print(f"Error reading file: {e}")
    sys.exit(1)

# 1. Fix the unescaped single quote strings
replacements_dict = {
    # Line 421
    "'La contrepartie dominante ($topExposureLabel) représente ${AppFormatters.percent(topExposureShare)} de l'exposition brute. Le ratio de solvabilité ressort à ${AppFormatters.percent(solvencyRatio)} ; la VaR absorbe ${AppFormatters.percent(varShare)} du RWA total.'":
    '"La contrepartie dominante ($topExposureLabel) représente ${AppFormatters.percent(topExposureShare)} de l\'exposition brute. Le ratio de solvabilité ressort à ${AppFormatters.percent(solvencyRatio)} ; la VaR absorbe ${AppFormatters.percent(varShare)} du RWA total."',

    # Line 4519
    "subtitle: 'Suivi mensuel du niveau d'exposition du portefeuille',":
    'subtitle: "Suivi mensuel du niveau d\'exposition du portefeuille",',

    # Line 4613
    "'suivre le niveau d'exposition totale du portefeuille mois par mois afin d'identifier les phases de croissance ou de réduction du stock de risque.\\n\\n'":
    '"suivre le niveau d\'exposition totale du portefeuille mois par mois afin d\'identifier les phases de croissance ou de réduction du stock de risque.\\n\\n"',

    # Line 4635
    "'chaque mois est représenté par un seul bâton pour faciliter la comparaison directe des niveaux d'exposition.\\n\\n'":
    '"chaque mois est représenté par un seul bâton pour faciliter la comparaison directe des niveaux d\'exposition.\\n\\n"',

    # Line 4646
    "'les indicateurs du bas résument l'exposition actuelle, la moyenne de période, le pic observé et l'évolution globale.'":
    '"les indicateurs du bas résument l\'exposition actuelle, la moyenne de période, le pic observé et l\'évolution globale."',
}

for old, new in replacements_dict.items():
    content = content.replace(old, new)

# 2. Define color replacements with word boundaries
replacements = [
    ('_primary', 'AppColors.accent'),
    ('_violet', 'AppColors.prudentialSolvency'),
    ('_warning', 'AppColors.warning'),
    ('_success', 'AppColors.success'),
    ('_border', 'AppTheme.border'),
    ('_surfaceSoft', 'AppColors.surfaceLight'),
    ('_textPrimary', 'AppTheme.text'),
    ('_textSecondary', 'AppTheme.muted'),
    ('_chartIndigo', 'AppColors.concentrationPrimary'),
    ('_cyan', 'AppColors.marketNeutral'),
]

total_replacements = 0
for old, new in replacements:
    pattern = r'\b' + re.escape(old) + r'\b'
    content, count = re.subn(pattern, new, content)
    if count > 0:
        print(f"  Replaced {old} -> {new} ({count} occurrences)")
        total_replacements += count

# Write back
try:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"\nSuccessfully refactored vue_ensemble_screen.dart")
except Exception as e:
    print(f"Error writing file: {e}")
    sys.exit(1)
