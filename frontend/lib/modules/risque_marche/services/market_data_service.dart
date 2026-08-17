import 'dart:convert';
import 'package:http/http.dart' as http;

class MarketDataService {
  /// Récupère le prix actuel d'une action via l'API publique de Yahoo Finance.
  /// Exemple de ticker : 'AAPL', 'MSFT', 'TSLA'.
  static Future<String?> fetchLivePrice(String ticker) async {
    try {
      final url = Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/$ticker');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Navigation sécurisée dans la structure JSON de Yahoo Finance
        final result = data['chart']?['result'];
        if (result != null && result.isNotEmpty) {
          final meta = result[0]['meta'];
          if (meta != null) {
            final double? price = meta['regularMarketPrice']?.toDouble();
            final String currency = meta['currency'] ?? 'USD';
            
            if (price != null) {
              // Formatage basique. Ex: "228.45 USD"
              return '${price.toStringAsFixed(2)} $currency';
            }
          }
        }
      }
      return null;
    } catch (e) {
      // En cas d'erreur réseau ou de parsing, on retourne null
      print('Erreur lors de la récupération du prix pour $ticker : $e');
      return null;
    }
  }
}
