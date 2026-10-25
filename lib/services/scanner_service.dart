import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

const _spot = 'https://api.binance.com/api/v3';
const _timeout = Duration(seconds: 15);

double _d(dynamic v) => double.tryParse('$v') ?? 0;

bool _isLeveraged(String s) =>
    s.contains('UP') || s.contains('DOWN') || s.contains('BEAR') || s.contains('BULL');

Future<List<dynamic>> _tickers() async {
  final r = await http.get(Uri.parse('$_spot/ticker/24hr')).timeout(_timeout);
  return jsonDecode(r.body) as List;
}

// ───────────────────────── RSI TARAYICI ─────────────────────────

class RsiHit {
  final String symbol;
  final double rsi, change;
  final bool oversold;
  RsiHit(this.symbol, this.rsi, this.change, this.oversold);
}

/// mode: oversold | overbought | both   |  interval: 1h | 4h | 1d
Future<List<RsiHit>> rsiScan(String interval, String mode, {void Function(String)? onProgress}) async {
  onProgress?.call('Coin listesi alınıyor...');
  final all = await _tickers();
  final symbols = all
      .where((t) => (t['symbol'] as String).endsWith('USDT') && !_isLeveraged(t['symbol']) && _d(t['quoteVolume']) > 200000)
      .toList()
    ..sort((a, b) => _d(b['quoteVolume']).compareTo(_d(a['quoteVolume'])));
  final syms = symbols.map((t) => t['symbol'] as String).take(200).toList();

  final hits = <RsiHit>[];
  const batch = 20;
  for (var i = 0; i < syms.length; i += batch) {
    final part = syms.sublist(i, min(i + batch, syms.length));
    onProgress?.call('${min(i + batch, syms.length)} / ${syms.length} coin tarandı...');
    await Future.wait(part.map((sym) async {
      try {
        final r = await http
            .get(Uri.parse('$_spot/klines?symbol=$sym&interval=$interval&limit=15'))
            .timeout(_timeout);
        final k = jsonDecode(r.body);
        if (k is! List || k.length < 14) return;
        final closes = k.map<double>((e) => _d(e[4])).toList();
        double gains = 0, losses = 0;
        for (var j = 1; j < 14; j++) {
          final diff = closes[j] - closes[j - 1];
          if (diff > 0) {
            gains += diff;
          } else {
            losses += diff.abs();
          }
        }
        final avgGain = gains / 14, avgLoss = losses / 14;
        if (avgLoss == 0) return;
        final rsi = 100 - (100 / (1 + avgGain / avgLoss));
        final change = (closes.last - closes.first) / closes.first * 100;
        if (rsi < 30 && (mode == 'oversold' || mode == 'both')) {
          hits.add(RsiHit(sym, rsi, change, true));
        } else if (rsi > 70 && (mode == 'overbought' || mode == 'both')) {
          hits.add(RsiHit(sym, rsi, change, false));
        }
      } catch (_) {}
    }));
  }
  hits.sort((a, b) {
    if (a.oversold && b.oversold) return a.rsi.compareTo(b.rsi);
    if (!a.oversold && !b.oversold) return b.rsi.compareTo(a.rsi);
    return a.oversold ? -1 : 1;
  });
  return hits;
}

// ───────────────────────── HACİM TARAYICI ─────────────────────────

class VolItem {
  final String symbol;
  final double vol24, change, price;
  final int count;
  double? buyPct; // taker alış %
  VolItem(this.symbol, this.vol24, this.change, this.price, this.count);
  double? get sellPct => buyPct == null ? null : 100 - buyPct!;
}

Future<List<VolItem>> volumeScan({void Function(String)? onProgress}) async {
  final all = await _tickers();
  final results = all
      .where((t) => (t['symbol'] as String).endsWith('USDT') && !_isLeveraged(t['symbol']) && _d(t['quoteVolume']) > 500000)
      .map((t) => VolItem(t['symbol'], _d(t['quoteVolume']), _d(t['priceChangePercent']), _d(t['lastPrice']), int.tryParse('${t['count']}') ?? 0))
      .toList()
    ..sort((a, b) => b.vol24.compareTo(a.vol24));

  final sorted = results.where((r) => r.change.abs() > 1).take(30).toList();

  const batch = 10;
  for (var i = 0; i < sorted.length; i += batch) {
    final part = sorted.sublist(i, min(i + batch, sorted.length));
    onProgress?.call('Alış/Satış oranı hesaplanıyor... ${min(i + batch, sorted.length)}/${sorted.length}');
    await Future.wait(part.map((item) async {
      try {
        final r = await http
            .get(Uri.parse('$_spot/klines?symbol=${item.symbol}&interval=1h&limit=24'))
            .timeout(_timeout);
        final kl = jsonDecode(r.body) as List;
        double total = 0, buy = 0;
        for (final k in kl) {
          total += _d(k[7]);
          buy += _d(k[10]);
        }
        if (total > 0) item.buyPct = buy / total * 100;
      } catch (_) {}
    }));
  }
  return sorted;
}
