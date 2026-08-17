#!/usr/bin/env python3
"""Script to fix all unescaped single quote strings in vue_ensemble_screen.dart."""

import sys

file_path = r"C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\lib\modules\vue_ensemble\screens\vue_ensemble_screen.dart"

print(f"Reading {file_path}...")
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
except Exception as e:
    print(f"Error reading file: {e}")
    sys.exit(1)

replacements = {
    # Line 364
    "        explanation:\n            'Mesure l'étendue géographique du portefeuille à partir des pays renseignés sur les expositions importées.',":
    '        explanation:\n            "Mesure l\'étendue géographique du portefeuille à partir des pays renseignés sur les expositions importées.",',

    # Line 366
    "        analysis:\n            '$countryCount pays distinct(s) sont représentés. Cette lecture complète l'analyse de concentration géographique.',":
    '        analysis:\n            "$countryCount pays distinct(s) sont représentés. Cette lecture complète l\'analyse de concentration géographique.",',

    # Line 375
    "        explanation:\n            'Identifie la notation qui concentre le plus d'exposition brute dans le portefeuille.',":
    '        explanation:\n            "Identifie la notation qui concentre le plus d\'exposition brute dans le portefeuille.",',

    # Line 377
    "        analysis:\n            'Le bucket $dominantRating porte ${AppFormatters.percent(dominantRatingShare)} de l'exposition totale, soit ${_money(dominantRatingExposure, displayCurrency)}.',":
    '        analysis:\n            "Le bucket $dominantRating porte ${AppFormatters.percent(dominantRatingShare)} de l\'exposition totale, soit ${_money(dominantRatingExposure, displayCurrency)}.",',

    # Line 386
    "        explanation:\n            'Mesure la part de l'exposition totale portée par les cinq premières contreparties.',":
    '        explanation:\n            "Mesure la part de l\'exposition totale portée par les cinq premières contreparties.",',

    # Line 390
    "        analysis:\n            'Les cinq premières contreparties représentent ${AppFormatters.percent(topFiveShare)} de l'exposition totale, soit ${_money(topFiveExposure, displayCurrency)}.',":
    '        analysis:\n            "Les cinq premières contreparties représentent ${AppFormatters.percent(topFiveShare)} de l\'exposition totale, soit ${_money(topFiveExposure, displayCurrency)}.",',

    # Line 399
    "        explanation:\n            'Indique la part de l'exposition brute portée par des expositions disposant d'un dispositif CRM ou d'une garantie renseignée.',":
    '        explanation:\n            "Indique la part de l\'exposition brute portée par des expositions disposant d\'un dispositif CRM ou d\'une garantie renseignée.",',

    # Line 403
    "        analysis:\n            '${AppFormatters.percent(crmShare)} de l'exposition brute est associée à un CRM renseigné, soit ${_money(crmExposure, displayCurrency)}.',":
    '        analysis:\n            "${AppFormatters.percent(crmShare)} de l\'exposition brute est associée à un CRM renseigné, soit ${_money(crmExposure, displayCurrency)}.",',

    # Line 430
    "              ? 'Contrôler l'utilisation de limite, les collatéraux éligibles et l'exposition nette sur $topExposureLabel.'":
    '              ? "Contrôler l\'utilisation de limite, les collatéraux éligibles et l\'exposition nette sur $topExposureLabel."',

    # Line 438
    "              ? 'Mesurer l'effet d'un allègement RWA ou d'un renforcement des fonds propres sur le coussin prudentiel.'":
    '              ? "Mesurer l\'effet d\'un allègement RWA ou d\'un renforcement des fonds propres sur le coussin prudentiel."',

    # Line 439
    "              : 'Protéger le coussin prudentiel avant toute croissance d'engagements.',":
    '              : "Protéger le coussin prudentiel avant toute croissance d\'engagements.",',

    # Line 449
    "          ? 'Mettre sous revue la limite single-name de $topExposureLabel, recalibrer les garanties éligibles et simuler une réduction progressive de l'exposition nette.'":
    '          ? "Mettre sous revue la limite single-name de $topExposureLabel, recalibrer les garanties éligibles et simuler une réduction progressive de l\'exposition nette."',

    # Line 602
    "            caption: 'Date d'analyse',":
    '            caption: "Date d\'analyse",',

    # Line 2923
    "              'identifier les concentrations excessives susceptibles d'augmenter la pression prudentielle.\\n\\n',":
    '              "identifier les concentrations excessives susceptibles d\'augmenter la pression prudentielle.\\n\\n",',

    # Line 2952
    "              'met en évidence le segment principal du portefeuille ainsi que son poids relatif dans l'exposition globale.\\n\\n',":
    '              "met en évidence le segment principal du portefeuille ainsi que son poids relatif dans l\'exposition globale.\\n\\n",',

    # Line 2963
    "              'les graphiques permettent d'observer rapidement les concentrations critiques, les déséquilibres du portefeuille et les zones nécessitant une surveillance renforcée.\\n\\n',":
    '              "les graphiques permettent d\'observer rapidement les concentrations critiques, les déséquilibres du portefeuille et les zones nécessitant une surveillance renforcée.\\n\\n",',

    # Line 2974
    "              'la part dominante, le niveau d'exposition et la structure des concentrations facilitent le pilotage prudentiel et l'analyse du risque de crédit.'":
    '              "la part dominante, le niveau d\'exposition et la structure des concentrations facilitent le pilotage prudentiel et l\'analyse du risque de crédit."',

    # Line 4597
    "          text: 'Lecture mensuelle de l'exposition\\n\\n',":
    '          text: "Lecture mensuelle de l\'exposition\\n\\n",',
}

# Normalize newlines in replacement map to match file content (CRLF or LF)
is_crlf = "\r\n" in content

for old, new in replacements.items():
    if not is_crlf:
        old_normalized = old.replace("\r\n", "\n")
        new_normalized = new.replace("\r\n", "\n")
    else:
        # If the file uses CRLF, make sure replacement keys/values use CRLF too
        old_normalized = old.replace("\r\n", "\n").replace("\n", "\r\n")
        new_normalized = new.replace("\r\n", "\n").replace("\n", "\r\n")
    
    if old_normalized in content:
        content = content.replace(old_normalized, new_normalized)
        print(f"Replaced string successfully.")
    else:
        # Fallback to search-and-replace without newline normalization if simple search fails
        old_lf = old.replace("\r\n", "\n")
        new_lf = new.replace("\r\n", "\n")
        if old_lf in content:
            content = content.replace(old_lf, new_lf)
            print(f"Replaced string successfully (LF fallback).")
        else:
            print(f"Warning: String not found: {old[:60]}...")

try:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Write complete.")
except Exception as e:
    print(f"Error writing: {e}")
