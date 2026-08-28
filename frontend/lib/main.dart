// Ce fichier demarre l'application Flutter.
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/rwa_api_service.dart';

// Lance l'application Flutter avec la configuration par défaut.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Filtrer les assertions internes bénignes du framework Flutter sous Windows
  // (ex: glitch de synchronisation de la touche Alt / RawKeyDownEvent dans raw_keyboard.dart).
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    if (message.contains('RawKeyDownEvent') ||
        message.contains('keysPressed') ||
        message.contains('raw_keyboard.dart')) {
      // Ignorer cette assertion connue du moteur Windows sans polluer la console
      return;
    }
    if (originalOnError != null) {
      originalOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final message = error.toString();
    if (message.contains('RawKeyDownEvent') ||
        message.contains('The document is empty') ||
        message.contains('keysPressed')) {
      return true;
    }
    return false;
  };

  // L'adresse du backend est résolue depuis l'environnement du processus, donc
  // depuis le terminal qui a lancé l'application. Une variable RWA_API_PORT
  // héritée sans qu'on le sache fait échouer tous les appels sans jamais dire
  // où ils sont partis. On l'annonce une fois, au démarrage.
  debugPrint('[FODEP] Backend visé : ${RwaApiService.resolveDefaultBaseUrl()}');
  runApp(const RwaApp());
}
