import 'dart:math';
import '../core/indicators.dart';
import 'binance_service.dart';

class Zone {
  double price;
  final bool isRes;
  int tests;
  String strength = 'weak'; // weak | medium | strong
  Zone(this.price, this.isRes, this.tests);
}

class MarketStructure {
  final double ema50, ema200;
  final bool emaGolden, structureBull;
  MarketStructure(this.ema50, this.ema200, this.emaGolden, this.structureBull);
}

class IndRow {
  final String name, value, text;
  final String cls; // bull | bear | neu
  IndRow(this.name, this.value, this.text, this.cls);
}

class MtfRow {
  final String label;
  final bool bull, bear, emaUp;
  MtfRow(this.label, this.bull, this.bear, this.emaUp);
}

class AnalysisResult {
  final String symbol, tf;
  final double price, chgPct;
  final String signal, signalEmoji, signalClass; // buy | wait | none
  final int score;
  final double confidence;
  final double sl, risk, tp1, tp2, tp3;
  final List<Zone> resistances, supports;
  final List<IndRow> indicators;
  final List<MtfRow> mtf;
  final String? mtfWarning;
  final DateTime updated;

  AnalysisResult({
    required this.symbol,
    required this.tf,
    required this.price,
    required this.chgPct,
    required this.signal,
    required this.signalEmoji,
    required this.signalClass,
    required this.score,
    required this.confidence,
    required this.sl,
    required this.risk,
    required this.tp1,
    required this.tp2,
    required this.tp3,
    required this.resistances,
    required this.supports,
    required this.indicators,
    required this.mtf,
    required this.mtfWarning,
    required this.updated,
  });
}

bool _isPivotHigh(List<Kline> k, int i) {
  for (final d in [1, 2, 3]) {
    if (!(k[i].high > k[i - d].high && k[i].high > k[i + d].high)) return false;
  }
  return true;
}

bool _isPivotLow(List<Kline> k, int i) {
  for (final d in [1, 2, 3]) {
    if (!(k[i].low < k[i - d].low && k[i].low < k[i + d].low)) return false;
  }
  return true;
}

({List<Zone> res, List<Zone> sup}) findSupportResistance(List<Kline> k) {
  final current = k.last.close;
  final threshold = current * 0.015;
  final zones = <Zone>[];
  for (var i = 3; i < k.length - 3; i++) {
    if (_isPivotHigh(k, i)) zones.add(Zone(k[i].high, true, 1));
    if (_isPivotLow(k, i)) zones.add(Zone(k[i].low, false, 1));
  }
  final merged = <Zone>[];
  for (final z in zones) {
    final ex = merged.where((m) => (m.price - z.price).abs() < threshold && m.isRes == z.isRes).firstOrNull;
    if (ex != null) {
      ex.tests++;
      ex.price = (ex.price * (ex.tests - 1) + z.price) / ex.tests;
    } else {
      merged.add(Zone(z.price, z.isRes, 1));
    }
  }
  for (final z in merged) {
    z.strength = z.tests >= 3 ? 'strong' : z.tests >= 2 ? 'medium' : 'weak';
  }
  final res = merged.where((z) => z.isRes && z.price > current).toList()..sort((a, b) => a.price.compareTo(b.price));
  final sup = merged.where((z) => !z.isRes && z.price < current).toList()..sort((a, b) => b.price.compareTo(a.price));
  return (res: res.take(3).toList(), sup: sup.take(3).toList());
}

MarketStructure marketStructure(List<Kline> k) {
  final closes = k.map((e) => e.close).toList();
  final n = closes.length;
  final e50 = ema(closes, 50)[n - 1];
  final e200 = ema(closes, min(200, n))[n - 1];

  final slice = k.length > 40 ? k.sublist(k.length - 40) : k;
  final highs = <double>[], lows = <double>[];
  for (var i = 3; i < slice.length - 3; i++) {
    if (_isPivotHigh(slice, i)) highs.add(slice[i].high);
    if (_isPivotLow(slice, i)) lows.add(slice[i].low);
  }
  final hh = highs.length >= 2 && highs.last > highs[highs.length - 2];
  final hl = lows.length >= 2 && lows.last > lows[lows.length - 2];
  final lh = highs.length >= 2 && highs.last < highs[highs.length - 2];
  final ll = lows.length >= 2 && lows.last < lows[lows.length - 2];
  final bullish = (hh && hl) ? true : (lh && ll) ? false : e50 > e200;
  return MarketStructure(e50, e200, e50 > e200, bullish);
}

double _snapTp(double base, List<Zone> resistances) {
  for (final r in resistances) {
    final dist = (r.price - base) / base;
    if (dist > 0.002 && dist < 0.05) return r.price * 0.999;
  }
  return base;
}

Future<AnalysisResult> runAnalysis(String symbol, String tf) async {
  final res = await Future.wait<dynamic>([
    BinanceService.klines(symbol, '1h', limit: 500),
    BinanceService.klines(symbol, '4h', limit: 300),
    BinanceService.klines(symbol, '1d', limit: 365),
    BinanceService.ticker24h(symbol),
  ]);
  final k1h = res[0] as List<Kline>;
  final k4h = res[1] as List<Kline>;
  final k1d = res[2] as List<Kline>;
  final ticker = res[3] as Ticker;

  if (k1h.length < 60) throw Exception('1 saatlik veri yetersiz');
  if (k4h.length < 60 || k1d.length < 60) throw Exception('Veri yetersiz (yeni listelenmiş coin olabilir)');

  final klines = tf == '1h' ? k1h : tf == '4h' ? k4h : k1d;
  final closes = klines.map((e) => e.close).toList();
  final n = closes.length;
  final current = closes[n - 1];

  final rsiV = rsi(closes);
  final macdV = macd(closes);
  final atrV = atr(klines);
  final bb = bollinger(closes);
  final vol = klines[n - 1].volume;
  final volMa = klines.sublist(n - 20).fold<double>(0, (a, k) => a + k.volume) / 20;

  final ms = marketStructure(klines);
  final sr = findSupportResistance(klines);

  // ── Confluence puanı (maks 9) ──
  var score = 0;
  if (ms.emaGolden) score += 2;
  if (ms.structureBull) score += 1;
  if ((rsiV >= 50 && rsiV <= 70) || rsiV < 30) score += 1;
  if (macdV.hist > 0 && macdV.macd > macdV.signal) score += 1;
  if (sr.sup.isNotEmpty && (current - sr.sup[0].price).abs() / current < 0.02) score += 1;
  final prevHigh = klines.sublist(n - 20, n - 3).map((k) => k.high).reduce(max);
  final lastK = klines[n - 1];
  if (lastK.close > prevHigh) score += 1;
  final body = (lastK.close - lastK.open).abs();
  final range = (lastK.high - lastK.low) == 0 ? 0.000001 : lastK.high - lastK.low;
  if (body / range > 0.6 && lastK.close > lastK.open) score += 1;
  if (vol > volMa) score += 1;
  final wickLow = min(lastK.open, lastK.close) - lastK.low;
  if (wickLow > body * 1.5) score += 1;

  final confidence = min(100.0, score / 9 * 100);
  String signal, emoji, cls;
  if (score >= 7) {
    signal = 'AL'; emoji = '🟢'; cls = 'buy';
  } else if (score >= 4) {
    signal = 'BEKLE'; emoji = '🟡'; cls = 'wait';
  } else {
    signal = 'İŞLEM YOK'; emoji = '⛔'; cls = 'none';
  }

  // ── Risk ──
  final nearestSupport = sr.sup.isNotEmpty ? sr.sup[0].price : null;
  final atrSL = current - atrV * 1.5;
  final sl = (nearestSupport != null && (current - nearestSupport) / current < 0.08)
      ? min(nearestSupport * 0.998, atrSL)
      : atrSL;
  final risk = max(current - sl, atrV * 0.5);
  final tp1 = _snapTp(current + risk, sr.res);
  final tp2 = _snapTp(current + risk * 2, sr.res);
  final tp3 = _snapTp(current + risk * 3, sr.res);

  // ── Gösterge satırları ──
  final atrOk = (atrV / current) * 100 > 0.5;
  final indicators = <IndRow>[
    IndRow('RSI', rsiV.toStringAsFixed(1),
        rsiV > 70 ? 'Aşırı alım — dikkat' : rsiV < 30 ? 'Aşırı satım — toparlanabilir' : rsiV < 50 ? 'Momentum zayıf' : 'Momentum güçlü',
        rsiV > 70 ? 'bear' : rsiV < 30 ? 'bull' : rsiV < 50 ? 'neu' : 'bull'),
    IndRow('MACD', macdV.hist.toStringAsFixed(4), macdV.hist > 0 ? 'Alım ivmesi artıyor' : 'Satım baskısı var',
        macdV.hist > 0 ? 'bull' : 'bear'),
    IndRow('EMA 50/200', ms.emaGolden ? 'Golden' : 'Death', ms.emaGolden ? 'Yükseliş trendi' : 'Düşüş trendi',
        ms.emaGolden ? 'bull' : 'bear'),
    IndRow('Bollinger', bb.mid.toStringAsFixed(4),
        current > bb.upper ? 'Fiyat çok yükseldi' : current < bb.lower ? 'Fiyat çok düştü' : 'Normal aralıkta',
        current > bb.upper ? 'bear' : current < bb.lower ? 'bull' : 'neu'),
    IndRow('ATR', '${((atrV / current) * 100).toStringAsFixed(2)}%',
        atrOk ? 'Hareket var, işlem uygun' : 'Hareketsiz piyasa', atrOk ? 'bull' : 'neu'),
    IndRow('Hacim', vol > volMa ? 'Yüksek' : 'Düşük', vol > volMa ? 'Yoğun işlem' : 'Düşük işlem',
        vol > volMa ? 'bull' : 'neu'),
  ];

  // ── MTF ──
  MtfRow mtfRow(String label, List<Kline> k) {
    final m = marketStructure(k);
    return MtfRow(label, m.emaGolden && m.structureBull, !m.emaGolden && !m.structureBull, m.emaGolden);
  }

  final mtf = [mtfRow('1 SAATLİK', k1h), mtfRow('4 SAATLİK', k4h), mtfRow('GÜNLÜK', k1d)];
  final bullCount = mtf.where((m) => m.bull).length;
  String? warn;
  if (bullCount == 0) {
    warn = '⚠ Hiçbir zaman diliminde boğa trendi yok';
  } else if (bullCount < 3) {
    final bad = mtf.where((m) => !m.bull).map((m) => m.label).join(', ');
    warn = '⚠ Zaman dilimleri uyumsuz — boğa olmayanlar: $bad';
  }

  return AnalysisResult(
    symbol: symbol,
    tf: tf,
    price: current,
    chgPct: ticker.changePct,
    signal: signal,
    signalEmoji: emoji,
    signalClass: cls,
    score: score,
    confidence: confidence,
    sl: sl,
    risk: risk,
    tp1: tp1,
    tp2: tp2,
    tp3: tp3,
    resistances: sr.res,
    supports: sr.sup,
    indicators: indicators,
    mtf: mtf,
    mtfWarning: warn,
    updated: DateTime.now(),
  );
}
