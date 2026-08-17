import 'dart:io';
import 'dart:convert';

void main() async {
  final url = Uri.parse('https://www.bceao.int/fr/cours/cours-des-devises-contre-Franc-CFA-appliquer-aux-transferts');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  final html = await response.transform(utf8.decoder).join();
  
  final bceaoName = 'Dollar us';
  final regex = RegExp(
    r'<td>' + bceaoName + r'</td>\s*<td>([\d,]+)</td>\s*<td>([\d,]+)</td>',
    caseSensitive: false,
  );
  
  final match = regex.firstMatch(html);
  if (match != null) {
    final achatStr = match.group(1)!.replaceAll(',', '.');
    final venteStr = match.group(2)!.replaceAll(',', '.');
    print('Achat: $achatStr, Vente: $venteStr');
    final achat = double.parse(achatStr);
    final vente = double.parse(venteStr);
    final mid = (achat + vente) / 2;
    print('Mid: $mid');
  } else {
    print('No match');
  }
}
