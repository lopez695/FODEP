#!/usr/bin/env python3
"""Script to replace hardcoded market colors with AppColors constants, including deleting local declarations."""

import sys
import re

file_path = r"C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\lib\modules\risque_marche\screens\risque_marche_screen.dart"

print(f"Reading {file_path}...")
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
except Exception as e:
    print(f"Error reading file: {e}")
    sys.exit(1)

print(f"File size: {len(content)} characters")

# 1. Add app_colors.dart import if missing
import_colors = "import '../../../core/theme/app_colors.dart';"
import_theme = "import '../../../core/theme/app_theme.dart';"
if import_colors not in content:
    content = content.replace(import_theme, f"{import_colors}\n{import_theme}")
    print("Added app_colors.dart import.")

# 2. Remove the local declarations block
decl_pattern = (
    r"const Color _marketPrimary = Color\(0xFF2563EB\);\r?\n"
    r"const Color _marketCyan = Color\(0xFF06B6D4\);\r?\n"
    r"const Color _marketSuccess = Color\(0xFF10B981\);\r?\n"
    r"const Color _marketWarning = Color\(0xFFF59E0B\);\r?\n"
    r"const Color _marketViolet = Color\(0xFF7C3AED\);\r?\n"
    r"const Color _marketDanger = Color\(0xFFEF4444\);\r?\n"
    r"const Color _marketDashboardDeepBlue = Color\(0xFF234A84\);\r?\n"
    r"const Color _marketText = Color\(0xFF13203A\);\r?\n"
    r"const Color _marketMuted = Color\(0xFF64748B\);\r?\n"
    r"const Color _marketBorder = Color\(0xFFDDE7F5\);\r?\n"
    r"const Color _marketSurface = Color\(0xFFFFFFFF\);\r?\n"
    r"const Color _marketSurfaceSoft = Color\(0xFFF8FAFC\);\r?\n"
)

content, num_deleted = re.subn(decl_pattern, "", content)
if num_deleted > 0:
    print("Deleted local market color declarations block.")
else:
    # Try with normal LFs just in case
    decl_pattern_lf = decl_pattern.replace(r"\r?\n", "\n")
    content, num_deleted_lf = re.subn(decl_pattern_lf, "", content)
    if num_deleted_lf > 0:
        print("Deleted local market color declarations block (LF).")
    else:
        print("Warning: Local declarations block not found (might be already deleted).")

# 3. Define color replacements
replacements = [
    ('_marketPrimary', 'AppColors.accent'),
    ('_marketCyan', 'AppColors.marketNeutral'),
    ('_marketSuccess', 'AppColors.success'),
    ('_marketWarning', 'AppColors.warning'),
    ('_marketViolet', 'AppColors.prudentialSolvency'),
    ('_marketDanger', 'AppColors.danger'),
    ('_marketDashboardDeepBlue', 'AppColors.sidebar'),
    ('_marketText', 'AppTheme.text'),
    ('_marketMuted', 'AppTheme.muted'),
    ('_marketBorder', 'AppTheme.border'),
    ('_marketSurface', 'AppColors.surfaceLight'),
    ('_marketSurfaceSoft', 'AppColors.surfaceLight'),
]

# Apply replacements and count using regex word boundaries
total_replacements = 0
for old, new in replacements:
    pattern = r'\b' + re.escape(old) + r'\b'
    content, count = re.subn(pattern, new, content)
    if count > 0:
        print(f"  Replaced {old} -> {new} ({count} occurrences)")
        total_replacements += count
    else:
        print(f"  Warning: {old} not found")

# Write back
try:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"\nSuccessfully refactored color references in {file_path}")
except Exception as e:
    print(f"Error writing file: {e}")
    sys.exit(1)
