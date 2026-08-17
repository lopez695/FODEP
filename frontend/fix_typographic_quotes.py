#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Corrige les guillemets typographiques dans concentration_screen.dart"""

import sys

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Compter les changements
    count_single_left = content.count('‘')  # '
    count_single_right = content.count('’')  # '
    count_double_left = content.count('“')  # "
    count_double_right = content.count('”')  # "

    print(f"Guillemets typographiques trouvés:")
    print(f"  ' (U+2018): {count_single_left}")
    print(f"  ' (U+2019): {count_single_right}")
    print(f"  " (U+201C): {count_double_left}")
    print(f"  " (U+201D): {count_double_right}")

    # Remplacer
    content = content.replace('‘', "'")  # ' → '
    content = content.replace('’', "'")  # ' → '
    content = content.replace('“', '"')  # " → "
    content = content.replace('”', '"')  # " → "

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    total_fixed = count_single_left + count_single_right + count_double_left + count_double_right
    print(f"\nTotal de {total_fixed} guillemets typographiques corrigés!")

if __name__ == '__main__':
    filepath = 'lib/modules/concentration/screens/concentration_screen.dart'
    fix_file(filepath)
