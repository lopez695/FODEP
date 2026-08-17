# Audit des durations obligataires

Ce dossier contient la mise en place operationnelle du prompt d'audit Fixed Income.

## Objectif

Le script `fixed_income_duration_audit.py` lit le fichier `Base_GO_modifie (1).xlsx`, reconstruit les cash flows obligataires, recalcule les prix, YTM, durations, convexites, poids de portefeuille, stress tests et controles, puis produit:

- `Base_GO_CORRIGE_FINAL.xlsx`
- `rapport_methodologique_duration_obligataire.md`

## Installation des dependances

```powershell
python -m pip install -r scripts\fixed_income_duration_requirements.txt
```

## Execution standard

Placer le fichier `Base_GO_modifie (1).xlsx` a la racine du projet, puis lancer:

```powershell
python scripts\fixed_income_duration_audit.py `
  --input "Base_GO_modifie (1).xlsx" `
  --output "Base_GO_CORRIGE_FINAL.xlsx" `
  --report "rapport_methodologique_duration_obligataire.md" `
  --analysis-date 2026-05-31
```

## Verification rapide

```powershell
python scripts\fixed_income_duration_audit.py --self-test
```

Le moteur ne suppose pas silencieusement les conventions critiques. Si une ligne ne fournit pas de nominal, maturite, frequence, day count, prix ou YTM exploitable, elle est marquee `BLOCKED` dans les controles et documentee dans `DIAGNOSTIC_ERREURS`.
