import 'dart:convert';
import 'package:http/http.dart' as http;

class DovizService {
  /// "1.234,56" → 1234.56  (eski parseTR)
  static double parseTR(dynamic v) {
    if (v == null) return 0;
    final s = '$v'.replaceAll('%', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(s) ?? 0;
  }

  /// truncgil today.json → { 'USD': {'Satış': '...', 'Alış': '...', 'Değişim': '...'}, ... }
  static Future<Map<String, dynamic>> fetchToday() async {
    final r = await http
        .get(Uri.parse('https://finans.truncgil.com/today.json?_=${DateTime.now().millisecondsSinceEpoch}'))
        .timeout(const Duration(seconds: 15));
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }
}
