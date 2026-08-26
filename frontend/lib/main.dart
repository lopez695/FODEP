// Ce fichier demarre l'application Flutter.
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/rwa_api_service.dart';

// Lance l'application Flutter avec la configuration par défaut.
void main() {
  // L'adresse du backend est résolue depuis l'environnement du processus, donc
  // depuis le terminal qui a lancé l'application. Une variable RWA_API_PORT
  // héritée sans qu'on le sache fait échouer tous les appels sans jamais dire
  // où ils sont partis. On l'annonce une fois, au démarrage.
  debugPrint('[FODEP] Backend visé : ${RwaApiService.resolveDefaultBaseUrl()}');
  runApp(const RwaApp());
}
