import 'dart:math';
import '../core/indicators.dart';
import 'analysis_engine.dart';
import 'binance_service.dart';

/// tip → uyumlu zaman dilimleri
const sinyalTfler = <String, List<String>>{
  'scalp': ['15m', '30m', '1h'],
  'swing': ['1h', '4h'],
  'pozisyon': ['4h', '1d'],
};

class SinyalResult {
  final String symbol, tip, tf;
  final String direction; // LONG | SHORT | BEKLE
  final int longScore, shortScore, longPct;
  final String strength;
  final double price, chgPct;
  final double entry, slDist, slPct;
  final double? sl;
  final double slLongWait, slShortWait;
  final double tp1, tp2, tp3;
  final String rr1, rr2, rr3;
  final double rsi, macdHist, ema20, ema50, atrPct, volRatio;
  final int bbPos;
  final bool obvBull;
  final double? supDist, resDist;
  SinyalResult({
    required this.symbol, required this.tip, required this.tf, required this.direction,
    required this.longScore, required this.shortScore, required this.longPct, required this.strength,
    required this.price, required this.chgPct, required this.entry, required this.slDist, required this.slPct,
    required this.sl, required this.slLongWait, required this.slShortWait,
    required this.tp1, required this.tp2, required this.tp3, required this.rr1, required this.rr2, required this.rr3,
    required this.rsi, required this.macdHist, required this.ema20, required this.ema50, required this.atrPct,
    required this.volRatio, required this.bbPos, required this.obvBull, required this.supDist, required this.resDist,
  });
}

double _macdHist(List<double> closes) {
  if (closes.length < 35) return 0;
  const k12 = 2 / 13, k26 = 2 / 27, k9 = 2 / 10;
  var e12 = closes[0], e26 = closes[0];
  final arr = <double>[];
  for (var i = 1; i < closes.length; i++) {
    e12 = closes[i] * k12 + e12 * (1 - k12);
    e26 = closes[i] * k26 + e26 * (1 - k26);
    arr.add(e12 - e26);
  }
  var sig = arr[0];
  for (var i = 1; i < arr.length; i++) {
    sig = arr[i] * k9 + sig * (1 - k9);
  }
  return arr.last - sig;
}

double _snap(double base, List<double> levels, bool long, Set<double> used) {
  for (final l in levels) {
    if (used.contains(l)) continue;
    final dist = long ? (l - base) / base : (base - l) / base;
    if (dist > 0 && dist < 0.05) {
      used.add(l);
      return l * (long ? 0.999 : 1.001);
    }
  }
  return base;
}

Future<SinyalResult> runSinyal(String symbol, String tip, String tf) async {
  final slMult = tip == 'scalp' ? 1.2 : tip == 'swing' ? 2.2 : 3.5;
  final tp1M = tip == 'scalp' ? 1.8 : tip == 'swing' ? 3.3 : 5.25;
  final tp2M = tip == 'scalp' ? 3.0 : tip == 'swing' ? 5.5 : 8.75;
  final tp3M = tip == 'scalp' ? 5.0 : tip == 'swing' ? 9.0 : 15.0;

  final limit = tf == '1d' ? 365 : (tf == '4h' ? 300 : 500);
  final res = await Future.wait<dynamic>([
    BinanceService.klines(symbol, tf, limit: limit),
    BinanceService.ticker24h(symbol),
  ]);
  final c = res[0] as List<Kline>;
  final t = res[1] as Ticker;
  if (c.length < 60) throw Exception('Yeterli veri bulunamadı (${c.length} mum, minimum 60)');

  final closes = c.map((e) => e.close).toList();
  final n = closes.length;
  final cur = closes[n - 1];
  final chg = t.changePct;

  final rsi14 = rsi(closes, 14);
  final hist = _macdHist(closes);
  final e20 = ema(closes, min(20, n)).last;
  final e50 = ema(closes, min(50, n)).last;
  final atrV = atr(c, min(14, c.length - 1));
  final atrPct = atrV / cur * 100;

  // OBV
  var obv = 0.0;
  final obvArr = <double>[0];
  for (var i = 1; i < c.length; i++) {
    if (c[i].close > c[i - 1].close) {
      obv += c[i].volume;
    } else if (c[i].close < c[i - 1].close) {
      obv -= c[i].volume;
    }
    obvArr.add(obv);
  }
  final obvBull = obvArr.last > obvArr[max(0, obvArr.length - 20)];

  // Bollinger konumu
  final bbSlice = closes.sublist(n - 20);
  final bbMid = bbSlice.fold<double>(0, (a, b) => a + b) / 20;
  final bbSd = sqrt(bbSlice.fold<double>(0, (a, b) => a + pow(b - bbMid, 2)) / 20);
  final bbUp = bbMid + 2 * bbSd, bbLo = bbMid - 2 * bbSd;
  final bbPos = (bbUp - bbLo) == 0 ? 50 : (((cur - bbLo) / (bbUp - bbLo)) * 100).round();

  // Hacim
  final vols = c.map((e) => e.volume).toList();
  final volMa = vols.sublist(vols.length - 20).fold<double>(0, (a, b) => a + b) / 20;
  final volRatio = volMa == 0 ? 1.0 : vols.last / volMa;
  final volBull = volRatio >= 1.2, volBear = volRatio < 0.7;

  final sr = findSupportResistance(c);
  final nearSup = sr.sup.isNotEmpty ? sr.sup.first : null;
  final nearRes = sr.res.isNotEmpty ? sr.res.first : null;
  final supDist = nearSup != null ? (cur - nearSup.price) / cur * 100 : null;
  final resDist = nearRes != null ? (nearRes.price - cur) / cur * 100 : null;

  var ls = 0, ss = 0;
  if (rsi14 >= 50 && rsi14 <= 70) {
    ls++;
  } else if (rsi14 < 30) {
    ls++;
  } else if (rsi14 > 70) {
    ss++;
  } else if (rsi14 < 45) {
    ss++;
  }
  if (hist > 0) { ls++; } else { ss++; }
  if (cur > e20) { ls++; } else { ss++; }
  if (cur > e50) { ls++; } else { ss++; }
  if (obvBull) { ls++; } else { ss++; }
  if (bbPos < 45) {
    ls++;
  } else if (bbPos > 65) {
    ss++;
  }
  if (chg > 1) {
    ls++;
  } else if (chg < -1) {
    ss++;
  }
  if (volBull) {
    ls++;
  } else if (volBear) {
    ss++;
  }
  if (supDist != null && supDist < 2.0) ls++;
  if (resDist != null && resDist < 2.0) ss++;

  final total = ls + ss;
  final longPct = total > 0 ? ((ls / total) * 100).round() : 50;
  final dir = ls >= ss + 2 ? 'LONG' : ss >= ls + 2 ? 'SHORT' : 'BEKLE';
  final isLong = dir == 'LONG', isShort = dir == 'SHORT';

  final entry = cur;
  final atrSl = atrV * slMult;
  final slLong = (nearSup != null && supDist! < 8) ? min(nearSup.price * 0.998, entry - atrSl) : entry - atrSl;
  final slShort = (nearRes != null && resDist! < 8) ? max(nearRes.price * 1.002, entry + atrSl) : entry + atrSl;
  final double? sl = isLong ? slLong : isShort ? slShort : null;
  final slDist = isLong ? entry - slLong : isShort ? slShort - entry : atrSl;

  final d1 = atrV * tp1M, d2 = atrV * tp2M, d3 = atrV * tp3M;
  final longT = sr.res.map((z) => z.price).toList();
  final shortT = sr.sup.map((z) => z.price).toList();
  final used = <double>{};
  double tp(double dist) => isLong
      ? _snap(entry + dist, longT, true, used)
      : isShort
          ? _snap(entry - dist, shortT, false, used)
          : entry + dist;
  var tp1 = tp(d1), tp2 = tp(d2), tp3 = tp(d3);
  if (isLong) {
    if (tp2 <= tp1) tp2 = entry + d2;
    if (tp3 <= tp2) tp3 = entry + d3;
  } else if (isShort) {
    if (tp2 >= tp1) tp2 = entry - d2;
    if (tp3 >= tp2) tp3 = entry - d3;
  }
  double dd(double p) => isLong ? p - entry : entry - p;
  String rr(double p) => slDist > 0 ? (dd(p) / slDist).toStringAsFixed(1) : '—';

  final strengthN = max(ls, ss);
  final strength = strengthN >= 7 ? 'ÇOK GÜÇLÜ' : strengthN >= 5 ? 'GÜÇLÜ' : strengthN >= 3 ? 'ORTA' : 'ZAYIF';

  return SinyalResult(
    symbol: symbol, tip: tip, tf: tf, direction: dir, longScore: ls, shortScore: ss, longPct: longPct,
    strength: strength, price: cur, chgPct: chg, entry: entry, slDist: slDist, slPct: slDist / entry * 100,
    sl: sl, slLongWait: slLong, slShortWait: slShort, tp1: tp1, tp2: tp2, tp3: tp3,
    rr1: rr(tp1), rr2: rr(tp2), rr3: rr(tp3), rsi: rsi14, macdHist: hist, ema20: e20, ema50: e50,
    atrPct: atrPct, volRatio: volRatio, bbPos: bbPos, obvBull: obvBull, supDist: supDist, resDist: resDist,
  );
}
