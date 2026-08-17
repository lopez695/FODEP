#!/usr/bin/env python3
"""Script to replace market risk color constants with AppColors and AppTheme."""

import re

# Read the file
file_path = r"C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\lib\modules\risque_marche\screens\risque_marche_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Define replacements (order matters - replace more specific names first)
replacements = [
    ('_marketPrimary', 'AppColors.accent'),
    ('_marketCyan', 'AppColors.marketNeutral'),
    ('_marketSuccess', 'AppColors.success'),
    ('_marketWarning', 'AppColors.warning'),
    ('_marketViolet', 'AppColors.prudentialSolvency'),
    ('_marketDanger', 'AppColors.danger'),
    ('_marketDashboardDeepBlue', 'AppColors.sidebar'),
    ('_marketTextFor', 'AppTheme.textFor'),
    ('_marketMutedFor', 'AppTheme.mutedFor'),
    ('_marketBorderFor', 'AppTheme.borderFor'),
    ('_marketSurfaceFor', 'AppTheme.surfaceFor'),
    ('_marketSurfaceSoftFor', 'AppTheme.surfaceSoftFor'),
    ('_marketText', 'AppTheme.text'),
    ('_marketMuted', 'AppTheme.muted'),
    ('_marketBorder', 'AppTheme.border'),
    ('_marketSurface', 'AppColors.surfaceLight'),
    ('_marketSurfaceSoft', 'AppColors.surfaceLight'),
]

# Apply replacements
count = 0
for old, new in replacements:
    occurrences = content.count(old)
    content = content.replace(old, new)
    count += occurrences
    if occurrences > 0:
        print(f"  {old} -> {new} ({occurrences} occurrences)")

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\nTotal: {count} replacements in {file_path}")
