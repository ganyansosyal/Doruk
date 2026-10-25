import 'dart:convert';
import 'package:http/http.dart' as http;

class Ticker {
  final String symbol;
  final double price;
  final double changePct;
  final double quoteVolume;
  Ticker(this.symbol, this.price, this.changePct, this.quoteVolume);

  factory Ticker.fromJson(Map<String, dynamic> e) => Ticker(
        e['symbol'] as String,
        BinanceService.d(e['lastPrice']),
        BinanceService.d(e['priceChangePercent']),
        BinanceService.d(e['quoteVolume']),
      );
}

class Kline {
  final DateTime time;
  final double open, high, low, close, volume;
  Kline(this.time, this.open, this.high, this.low, this.close, this.volume);
}

class BinanceService {
  static const _spot = 'https://api.binance.com/api/v3';
  static const _fut = 'https://fapi.binance.com/fapi/v1';
  static const _timeout = Duration(seconds: 15);

  static double d(dynamic v) => double.tryParse('$v') ?? 0;

  /// USDT paritelerinin 24s ticker listesi (hacme göre sıralı)
  static Future<List<Ticker>> tickers24h() async {
    final r = await http.get(Uri.parse('$_spot/ticker/24hr')).timeout(_timeout);
    final list = (jsonDecode(r.body) as List)
        .where((e) => (e['symbol'] as String).endsWith('USDT'))
        .map((e) => Ticker.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
    return list;
  }

  /// Tek sembol 24s ticker (bulunamazsa Exception)
  static Future<Ticker> ticker24h(String symbol) async {
    final r = await http.get(Uri.parse('$_spot/ticker/24hr?symbol=$symbol')).timeout(_timeout);
    final j = jsonDecode(r.body);
    if (j is Map && j['code'] != null) throw Exception('Coin bulunamadı: $symbol');
    return Ticker.fromJson(j as Map<String, dynamic>);
  }

  static Future<List<Kline>> klines(String symbol, String interval, {int limit = 200}) async {
    final r = await http
        .get(Uri.parse('$_spot/klines?symbol=$symbol&interval=$interval&limit=$limit'))
        .timeout(_timeout);
    final j = jsonDecode(r.body);
    if (j is Map) throw Exception('Coin bulunamadı: $symbol');
    return (j as List)
        .map((k) => Kline(DateTime.fromMillisecondsSinceEpoch(k[0] as int), d(k[1]), d(k[2]), d(k[3]), d(k[4]), d(k[5])))
        .toList();
  }

  /// Futures (Faz 3'te kullanılacak)
  static Future<List<dynamic>> futuresTickers() async {
    final r = await http.get(Uri.parse('$_fut/ticker/24hr')).timeout(_timeout);
    return jsonDecode(r.body) as List;
  }
}
