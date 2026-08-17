@echo off
title Risque Management - Lancement
echo ==============================================
echo       Demarrage de Risque Management
echo ==============================================

echo [1/2] Lancement du serveur Backend en arriere-plan...
cd backend
start /B cmd /C "python run_server.py > NUL 2>&1"
cd ..

echo [2/2] Lancement de l'interface graphique (Frontend)...
cd frontend\build\windows\x64\runner\Release
start "" "rwa_calculator.exe"

echo ==============================================
echo Application lancee ! Vous pouvez fermer cette fenetre.
echo ==============================================
timeout /t 3 > NUL
exit
