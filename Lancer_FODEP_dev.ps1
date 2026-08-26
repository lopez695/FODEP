# Lancement de FODEP en developpement, backend et interface sur le meme port.
#
# Raison d'etre : l'interface resout l'adresse du backend depuis les variables
# d'environnement du terminal qui la lance. Une RWA_API_PORT laissee dans une
# session Windows envoie donc tous les appels a une adresse morte, sans que
# rien ne l'indique a l'ecran. Ce script impose le port aux deux moities, quoi
# que contienne la session appelante.

param(
    # Un seul endroit a changer si le port doit bouger.
    [int]$Port = 8001
)

$ErrorActionPreference = 'Stop'
$racine = $PSScriptRoot

# Confine a ce script et aux processus qu'il demarre : la session de
# l'utilisateur n'est pas modifiee.
$env:RWA_API_PORT = "$Port"
Remove-Item Env:RWA_API_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:RWA_API_HOST -ErrorAction SilentlyContinue

Write-Host "FODEP - backend et interface sur le port $Port" -ForegroundColor Cyan

$python = Join-Path $racine 'backend\.venv\Scripts\python.exe'
if (-not (Test-Path $python)) {
    throw "Environnement Python introuvable : $python"
}

$dejaEnEcoute = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
if ($dejaEnEcoute) {
    Write-Host "  backend  : deja en ecoute, reutilise" -ForegroundColor DarkGray
} else {
    Write-Host "  backend  : demarrage..." -ForegroundColor DarkGray
    Start-Process -FilePath $python `
        -ArgumentList 'run_server.py' `
        -WorkingDirectory (Join-Path $racine 'backend') `
        -WindowStyle Minimized
}

# L'interface reessaie d'elle-meme pendant quelques secondes au demarrage :
# inutile d'attendre ici que le port soit ouvert.
Write-Host "  interface: demarrage..." -ForegroundColor DarkGray
Set-Location (Join-Path $racine 'frontend')

# --dart-define l'emporte sur les variables d'environnement dans l'ordre de
# resolution : c'est la garantie de dernier recours.
flutter run -d windows --dart-define=RWA_API_BASE_URL="http://127.0.0.1:$Port"
