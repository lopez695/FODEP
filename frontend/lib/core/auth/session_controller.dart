import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'http_client_factory.dart';

/// Profil de l'utilisateur connecté.
class SessionProfile {
  const SessionProfile({
    required this.identifiant,
    required this.role,
    this.nomComplet,
  });

  final String identifiant;
  final String role;
  final String? nomComplet;

  /// Tout compte connecté travaille dans son propre espace : importer ou
  /// corriger n'affecte personne d'autre. Le rôle ne bride donc plus
  /// l'écriture des données.
  bool get peutEditer => true;

  /// Gérer l'équipe reste réservé : les comptes sont communs à tous les
  /// espaces, contrairement aux données. Un rôle inconnu n'y donne pas droit.
  bool get peutGererEquipe => role == 'edition';

  factory SessionProfile.fromJson(Map<String, dynamic> json) {
    return SessionProfile(
      identifiant: (json['identifiant'] ?? '') as String,
      role: (json['role'] ?? 'consultation') as String,
      nomComplet: json['nom_complet'] as String?,
    );
  }
}

/// État de la session au démarrage de l'application.
enum SessionState {
  /// Vérification en cours : ni connecté, ni écran de connexion.
  verification,

  /// Aucune session : l'écran de connexion doit être affiché.
  deconnecte,

  /// Session ouverte.
  connecte,
}

/// Détient le jeton d'accès et le profil, et rejoue le renouvellement.
///
/// Le jeton d'accès n'est **jamais** écrit sur disque : il vit dans ce champ,
/// en mémoire vive. Un rechargement de page le perd, et c'est voulu — il est
/// alors redemandé via le cookie de renouvellement, illisible par le
/// JavaScript. Un XSS ne trouve donc rien à voler qui survive à la page.
class SessionController extends ChangeNotifier {
  SessionController({required this.baseUrl, http.Client? client})
      : _client = client ?? createHttpClient();

  final String baseUrl;
  final http.Client _client;

  String? _accessToken;
  SessionProfile? _profil;
  SessionState _etat = SessionState.verification;
  Timer? _renouvellement;
  bool _authentificationRequise = true;

  SessionState get etat => _etat;
  SessionProfile? get profil => _profil;
  String? get accessToken => _accessToken;

  /// Vrai quand le backend impose une authentification. Faux sur un poste de
  /// travail où l'API tourne en local sans compte.
  bool get authentificationRequise => _authentificationRequise;

  /// Droit d'écriture. Sans profil chargé, la réponse est non : l'interface ne
  /// doit pas proposer une action que le serveur refusera.
  bool get peutEditer => _profil?.peutEditer ?? false;

  Uri _uri(String chemin) => Uri.parse('$baseUrl$chemin');

  /// Détermine l'état de session au lancement.
  ///
  /// Trois cas : le backend n'exige rien (poste local), un cookie de
  /// renouvellement est encore valide (retour sur l'onglet), ou il faut se
  /// connecter.
  Future<void> initialiser() async {
    _etat = SessionState.verification;
    notifyListeners();

    try {
      final reponse = await _client.get(_uri('/auth/me'));
      if (reponse.statusCode == 200) {
        // L'API répond sans jeton : l'authentification est désactivée.
        _authentificationRequise = false;
        _profil = SessionProfile.fromJson(
          jsonDecode(reponse.body) as Map<String, dynamic>,
        );
        _etat = SessionState.connecte;
        notifyListeners();
        return;
      }
    } catch (_) {
      // Backend injoignable : on présente l'écran de connexion, qui affichera
      // l'erreur au premier essai plutôt que de bloquer sur un écran vide.
    }

    _authentificationRequise = true;
    final renouvele = await renouveler();
    _etat = renouvele ? SessionState.connecte : SessionState.deconnecte;
    notifyListeners();
  }

  /// Ouvre une session. Retourne un message d'erreur, ou null si tout va bien.
  Future<String?> connecter({
    required String identifiant,
    required String motDePasse,
  }) async {
    try {
      final reponse = await _client.post(
        _uri('/auth/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifiant': identifiant,
          'mot_de_passe': motDePasse,
        }),
      );
      if (reponse.statusCode == 200) {
        _appliquer(jsonDecode(reponse.body) as Map<String, dynamic>);
        return null;
      }
      return _messageErreur(reponse, 'Identifiant ou mot de passe incorrect.');
    } catch (_) {
      return 'Serveur injoignable. Vérifiez votre connexion.';
    }
  }

  /// Redemande un jeton d'accès à partir du cookie de renouvellement.
  Future<bool> renouveler() async {
    try {
      final reponse = await _client.post(_uri('/auth/refresh'));
      if (reponse.statusCode == 200) {
        _appliquer(jsonDecode(reponse.body) as Map<String, dynamic>);
        return true;
      }
    } catch (_) {
      // Réseau indisponible : la session n'est pas perdue pour autant, le
      // prochain appel réessaiera.
    }
    return false;
  }

  Map<String, String> _entetes({bool json = false}) {
    final entetes = <String, String>{};
    if (json) entetes['Content-Type'] = 'application/json';
    final jeton = _accessToken;
    if (jeton != null && jeton.isNotEmpty) {
      entetes['Authorization'] = 'Bearer $jeton';
    }
    return entetes;
  }

  /// Liste les membres de l'équipe. Réservé au rôle édition côté serveur.
  Future<List<Map<String, dynamic>>> listerEquipe() async {
    final reponse = await _client.get(_uri('/auth/comptes'), headers: _entetes());
    if (reponse.statusCode != 200) {
      throw Exception(_messageErreur(reponse, 'Liste indisponible.'));
    }
    return (jsonDecode(reponse.body) as List)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Ajoute un membre. Son espace de travail se crée à sa première connexion.
  Future<String?> ajouterMembre({
    required String identifiant,
    required String motDePasse,
    required String role,
    String? nomComplet,
  }) async {
    try {
      final reponse = await _client.post(
        _uri('/auth/comptes'),
        headers: _entetes(json: true),
        body: jsonEncode({
          'identifiant': identifiant,
          'mot_de_passe': motDePasse,
          'role': role,
          if (nomComplet != null && nomComplet.trim().isNotEmpty)
            'nom_complet': nomComplet.trim(),
        }),
      );
      if (reponse.statusCode == 201) return null;
      if (reponse.statusCode == 422) {
        return 'Le mot de passe doit faire au moins 12 caractères.';
      }
      return _messageErreur(reponse, 'Ajout impossible.');
    } catch (_) {
      return 'Serveur injoignable.';
    }
  }

  Future<String?> changerActivation({
    required String identifiant,
    required bool actif,
  }) async {
    try {
      final reponse = await _client.put(
        _uri('/auth/comptes/$identifiant/activation'),
        headers: _entetes(json: true),
        body: jsonEncode({'actif': actif}),
      );
      if (reponse.statusCode == 204) return null;
      return _messageErreur(reponse, 'Modification impossible.');
    } catch (_) {
      return 'Serveur injoignable.';
    }
  }

  Future<String?> reinitialiserMotDePasse({
    required String identifiant,
    required String motDePasse,
  }) async {
    try {
      final reponse = await _client.put(
        _uri('/auth/comptes/$identifiant/mot-de-passe'),
        headers: _entetes(json: true),
        body: jsonEncode({'mot_de_passe': motDePasse}),
      );
      if (reponse.statusCode == 204) return null;
      if (reponse.statusCode == 422) {
        return 'Le mot de passe doit faire au moins 12 caractères.';
      }
      return _messageErreur(reponse, 'Modification impossible.');
    } catch (_) {
      return 'Serveur injoignable.';
    }
  }

  Future<void> deconnecter() async {
    try {
      await _client.post(_uri('/auth/logout'));
    } catch (_) {
      // La session locale est effacée même si le serveur n'a pas répondu.
    }
    _renouvellement?.cancel();
    _accessToken = null;
    _profil = null;
    _etat = SessionState.deconnecte;
    notifyListeners();
  }

  /// Efface la session sans appeler le serveur : utilisé quand une requête
  /// revient en 401 malgré un renouvellement.
  void invalider() {
    _renouvellement?.cancel();
    _accessToken = null;
    _profil = null;
    _etat = SessionState.deconnecte;
    notifyListeners();
  }

  void _appliquer(Map<String, dynamic> charge) {
    _accessToken = charge['access_token'] as String?;
    final profil = charge['profil'];
    if (profil is Map<String, dynamic>) {
      _profil = SessionProfile.fromJson(profil);
    }
    _etat = SessionState.connecte;
    _programmerRenouvellement((charge['expires_in'] as num?)?.toInt() ?? 3600);
    notifyListeners();
  }

  /// Renouvelle une minute avant l'expiration : l'utilisateur ne doit pas être
  /// éjecté au milieu d'une consultation.
  void _programmerRenouvellement(int expiresIn) {
    _renouvellement?.cancel();
    final delai = Duration(seconds: (expiresIn - 60).clamp(30, 86400));
    _renouvellement = Timer(delai, () async {
      final ok = await renouveler();
      if (!ok) invalider();
    });
  }

  String _messageErreur(http.Response reponse, String defaut) {
    try {
      final charge = jsonDecode(reponse.body);
      if (charge is Map && charge['detail'] is String) {
        return charge['detail'] as String;
      }
    } catch (_) {
      // Corps non JSON : le message par défaut fait l'affaire.
    }
    return defaut;
  }

  @override
  void dispose() {
    _renouvellement?.cancel();
    super.dispose();
  }
}
