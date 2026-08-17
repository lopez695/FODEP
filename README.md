# Risque Management

Base modulaire d'un outil de calcul et de pilotage des RWA et des risques, avec un backend Python et un frontend Flutter.

## Architecture

- `backend/` expose les APIs metier et les calculs prudentiels.
- `frontend/` contient l'interface Flutter structuree par modules.
- Chaque module suit la meme logique: modeles, services, routes ou ecrans.

## Modules metier

- Dashboard
- Expositions
- Hors Bilan
- CRM
- Referentiels
- Rapports

## Demarrage backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe run_server.py --reload --port 8001
```

> Appeler `.venv\Scripts\python.exe` plutot que `python` : c'est le seul moyen
> d'etre certain d'utiliser l'interprete du venv. Lance avec le `python` global,
> le serveur echoue sur `ModuleNotFoundError: No module named 'bcrypt'`, car les
> dependances ne sont installees que dans le venv.

> Ne pas lancer `python -m uvicorn app.main:app --reload` directement : le
> rechargement automatique surveillerait alors aussi `data/` (base SQLite,
> logs) et redemarrerait le serveur a chaque enregistrement, faisant echouer
> les requetes en cours. `run_server.py` exclut ces dossiers du rechargement.
> Le port 8001 est celui attendu par defaut par le client desktop.

### Si tu preferes taper `python` tout court

`.venv\Scripts\activate` echoue quand l'execution de scripts PowerShell est
desactivee (`PSSecurityException`, *UnauthorizedAccess*). Inutile de toucher a
l'ExecutionPolicy : le script ne fait qu'ajouter le dossier `Scripts` du venv en
tete du `PATH`, ce qu'on peut faire sans executer quoi que ce soit. Pour la
session PowerShell en cours :

```powershell
$env:Path = "$PWD\.venv\Scripts;" + $env:Path
```

`python` designe alors l'interprete du venv, jusqu'a la fermeture du terminal.

Si `python -m venv .venv` echoue sous Windows, verifie que Python est bien installe hors alias `WindowsApps`, puis recree le venv avec l'interprete reel.

## Demarrage frontend

```bash
cd frontend
flutter pub get
flutter run
```

## Generation d'un executable Windows

Le projet peut maintenant etre livre sous forme d'un installateur `.exe` Windows qui embarque:

- le frontend Flutter Windows
- le backend Python FastAPI compile en executable
- la base SQLite et les fichiers runtime dans `AppData\Local\RWA Calculator`

Commande de build:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows_package.ps1
```

Artefacts generes:

- `dist\RWA_Calculator_Setup.exe` : installateur a transmettre
- `dist\RWA Calculator Portable\` : version portable deja assemblee

## Arborescence

```text
backend/
  app/
    core/
    dashboard/
    expositions/
    hors_bilan/
    crm/
    referentiels/
    rapports/
    main.py

frontend/
  lib/
    core/
    modules/
    shared/
    main.dart
```
