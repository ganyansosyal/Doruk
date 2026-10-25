import 'dart:convert';
import 'package:http/http.dart' as http;
import 'binance_service.dart';

const _spot = 'https://api.binance.com/api/v3';
const _to = Duration(seconds: 15);
double _d(dynamic v) => double.tryParse('$v') ?? 0;

String whaleFmt(double n) {
  if (n >= 1e6) return '\$${(n / 1e6).toStringAsFixed(2)}M';
  if (n >= 1e3) return '\$${(n / 1e3).toStringAsFixed(1)}K';
  return '\$${n.toStringAsFixed(0)}';
}

String whaleTimeAgo(int ts) {
  final sec = ((DateTime.now().millisecondsSinceEpoch - ts) / 1000).floor();
  if (sec < 60) return '$sec s önce';
  if (sec < 3600) return '${sec ~/ 60} dk önce';
  return '${sec ~/ 3600} sa önce';
}

// ── Günlük (TR saatine göre bugünün saatlik alım/satım dağılımı) ──
class WhaleHour {
  final int openTime, trades;
  final double open, high, low, close, quoteVol, buyQuote;
  WhaleHour(this.openTime, this.open, this.high, this.low, this.close, this.quoteVol, this.trades, this.buyQuote);
  double get sellQuote => quoteVol - buyQuote;
  double get buyPct => quoteVol > 0 ? buyQuote / quoteVol * 100 : 50;
  String get trLabel {
    final d = DateTime.fromMillisecondsSinceEpoch(openTime, isUtc: true);
    return '${((d.hour + 3) % 24).toString().padLeft(2, '0')}:00';
  }
}

class WhaleDaily {
  final Ticker ticker;
  final List<WhaleHour> hours;
  final double totalVol, totalBuy, totalSell, buyPct;
  final int totalTrades;
  final WhaleHour maxVolHour;
  WhaleDaily(this.ticker, this.hours, this.totalVol, this.totalBuy, this.totalSell, this.buyPct, this.totalTrades, this.maxVolHour);
}

Future<WhaleDaily> whaleDaily(String symbol) async {
  final nowTR = DateTime.now().toUtc().add(const Duration(hours: 3));
  final startTR = DateTime.utc(nowTR.year, nowTR.month, nowTR.day);
  final startMs = startTR.subtract(const Duration(hours: 3)).millisecondsSinceEpoch;

  final res = await Future.wait<dynamic>([
    http.get(Uri.parse('$_spot/klines?symbol=$symbol&interval=1h&startTime=$startMs&limit=24')).timeout(_to),
    BinanceService.ticker24h(symbol),
  ]);
  final j = jsonDecode((res[0] as http.Response).body);
  if (j is! List || j.isEmpty) throw Exception('Veri alınamadı.');
  final hours = j
      .map((k) => WhaleHour(k[0] as int, _d(k[1]), _d(k[2]), _d(k[3]), _d(k[4]), _d(k[7]), (k[8] as num).toInt(), _d(k[10])))
      .toList();
  final total = hours.fold<double>(0, (s, h) => s + h.quoteVol);
  final buy = hours.fold<double>(0, (s, h) => s + h.buyQuote);
  final trades = hours.fold<int>(0, (s, h) => s + h.trades);
  final maxH = hours.reduce((a, b) => b.quoteVol > a.quoteVol ? b : a);
  return WhaleDaily(res[1] as Ticker, hours, total, buy, total - buy, total > 0 ? buy / total * 100 : 50, trades, maxH);
}

// ── Anlık büyük işlemler ──
class BigTrade {
  final double price, qty, value;
  final bool isBuy;
  final int time;
  BigTrade(this.price, this.qty, this.value, this.isBuy, this.time);
}

class WhaleLive {
  final Ticker ticker;
  final List<BigTrade> trades;
  final double buyVol, sellVol, buyPct, maxVal;
  final int buyCount, sellCount;
  WhaleLive(this.ticker, this.trades, this.buyVol, this.sellVol, this.buyPct, this.maxVal, this.buyCount, this.sellCount);
}

Future<WhaleLive> whaleLive(String symbol, double threshold) async {
  final res = await Future.wait<dynamic>([
    http.get(Uri.parse('$_spot/trades?symbol=$symbol&limit=1000')).timeout(_to),
    BinanceService.ticker24h(symbol),
  ]);
  final j = jsonDecode((res[0] as http.Response).body);
  if (j is! List || j.isEmpty) throw Exception('İşlem verisi alınamadı.');
  final big = j
      .map((t) {
        final p = _d(t['price']), q = _d(t['qty']);
        return BigTrade(p, q, p * q, !(t['isBuyerMaker'] as bool), t['time'] as int);
      })
      .where((t) => t.value >= threshold)
      .toList()
    ..sort((a, b) => b.time.compareTo(a.time));
  final top = big.take(100).toList();
  final buys = top.where((t) => t.isBuy).toList();
  final sells = top.where((t) => !t.isBuy).toList();
  final bv = buys.fold<double>(0, (s, t) => s + t.value);
  final sv = sells.fold<double>(0, (s, t) => s + t.value);
  final tot = bv + sv;
  final maxVal = top.isEmpty ? 0.0 : top.map((t) => t.value).reduce((a, b) => a > b ? a : b);
  return WhaleLive(res[1] as Ticker, top, bv, sv, tot > 0 ? bv / tot * 100 : 50, maxVal, buys.length, sells.length);
}
