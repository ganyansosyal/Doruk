import 'dart:convert';
import 'package:http/http.dart' as http;

class LiqItem {
  final DateTime time;
  final bool isShortLiq; // BUY = short tasfiye
  final double value;
  LiqItem(this.time, this.isShortLiq, this.value);
}

class NabizResult {
  final String symbol;
  final double? fundingPct; // 8 saatlik oran (%)
  final double? oiUsdt;
  final double price;
  final double chg24;
  final double? allLong, allShort, topLong, topShort; // %
  final List<LiqItem> liqs;
  final DateTime fetchedAt;
  NabizResult({
    required this.symbol,
    this.fundingPct,
    this.oiUsdt,
    required this.price,
    required this.chg24,
    this.allLong,
    this.allShort,
    this.topLong,
    this.topShort,
    required this.liqs,
    required this.fetchedAt,
  });
}

class NabizService {
  static const _f = 'https://fapi.binance.com';
  static const _timeout = Duration(seconds: 15);

  static double _d(dynamic v) => double.tryParse('$v') ?? 0;

  static Future<dynamic> _get(String path) async {
    try {
      final r = await http.get(Uri.parse('$_f$path')).timeout(_timeout);
      return jsonDecode(r.body);
    } catch (_) {
      return null;
    }
  }

  static Future<NabizResult> run(String symbol) async {
    final res = await Future.wait([
      _get('/fapi/v1/fundingRate?symbol=$symbol&limit=1'),
      _get('/fapi/v1/openInterest?symbol=$symbol'),
      _get('/futures/data/topLongShortPositionRatio?symbol=$symbol&period=5m&limit=1'),
      _get('/futures/data/globalLongShortAccountRatio?symbol=$symbol&period=5m&limit=1'),
      _get('/fapi/v1/ticker/24hr?symbol=$symbol'),
      _get('/fapi/v1/forceOrders?symbol=$symbol&autoCloseType=LIQUIDATION&limit=20'),
    ]);

    double? fr;
    if (res[0] is List && (res[0] as List).isNotEmpty) {
      fr = _d((res[0] as List)[0]['fundingRate']) * 100;
    }

    final ticker = res[4];
    final price = ticker is Map ? _d(ticker['lastPrice']) : 0.0;
    final chg = ticker is Map ? _d(ticker['priceChangePercent']) : 0.0;

    double? oiUsdt;
    if (res[1] is Map && (res[1] as Map)['openInterest'] != null) {
      oiUsdt = _d((res[1] as Map)['openInterest']) * price;
    }

    double? tl, ts, al, as_;
    if (res[2] is List && (res[2] as List).isNotEmpty) {
      final m = (res[2] as List)[0];
      tl = _d(m['longAccount']) * 100;
      ts = _d(m['shortAccount']) * 100;
    }
    if (res[3] is List && (res[3] as List).isNotEmpty) {
      final m = (res[3] as List)[0];
      al = _d(m['longAccount']) * 100;
      as_ = _d(m['shortAccount']) * 100;
    }

    final liqs = <LiqItem>[];
    if (res[5] is List) {
      for (final l in (res[5] as List).take(10)) {
        liqs.add(LiqItem(
          DateTime.fromMillisecondsSinceEpoch((l['time'] as num).toInt()),
          l['side'] == 'BUY',
          _d(l['origQty']) * _d(l['price']),
        ));
      }
    }

    if (fr == null && oiUsdt == null && tl == null && al == null && liqs.isEmpty && price == 0) {
      throw Exception('Veri alınamadı');
    }

    return NabizResult(
      symbol: symbol,
      fundingPct: fr,
      oiUsdt: oiUsdt,
      price: price,
      chg24: chg,
      allLong: al,
      allShort: as_,
      topLong: tl,
      topShort: ts,
      liqs: liqs,
      fetchedAt: DateTime.now(),
    );
  }
}
