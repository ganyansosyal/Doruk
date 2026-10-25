import 'dart:math';
import '../services/binance_service.dart';

/// Ortak teknik göstergeler (Analiz, RSI, Sinyal, Fibo sayfaları kullanacak)

List<double> ema(List<double> data, int period) {
  final k = 2 / (period + 1);
  var e = data[0];
  final out = <double>[];
  for (var i = 0; i < data.length; i++) {
    if (i == 0) {
      out.add(e);
    } else {
      e = data[i] * k + e * (1 - k);
      out.add(e);
    }
  }
  return out;
}

double rsi(List<double> closes, [int period = 14]) {
  if (closes.length < period + 1) return 50;
  double gains = 0, losses = 0;
  for (var i = 1; i <= period; i++) {
    final d = closes[i] - closes[i - 1];
    if (d > 0) {
      gains += d;
    } else {
      losses -= d;
    }
  }
  var avgGain = gains / period, avgLoss = losses / period;
  for (var i = period + 1; i < closes.length; i++) {
    final d = closes[i] - closes[i - 1];
    avgGain = (avgGain * (period - 1) + (d > 0 ? d : 0)) / period;
    avgLoss = (avgLoss * (period - 1) + (d < 0 ? -d : 0)) / period;
  }
  if (avgLoss == 0) return 100;
  return 100 - 100 / (1 + avgGain / avgLoss);
}

({double macd, double signal, double hist}) macd(List<double> closes) {
  final e12 = ema(closes, 12);
  final e26 = ema(closes, 26);
  final line = <double>[for (var i = 0; i < closes.length; i++) e12[i] - e26[i]];
  final sig = ema(line, 9);
  final last = line.last;
  final s = sig.last;
  return (macd: last, signal: s, hist: last - s);
}

double atr(List<Kline> k, [int period = 14]) {
  final trs = <double>[];
  for (var i = 1; i < k.length; i++) {
    final prev = k[i - 1].close;
    trs.add(max(k[i].high - k[i].low, max((k[i].high - prev).abs(), (k[i].low - prev).abs())));
  }
  final slice = trs.length > period ? trs.sublist(trs.length - period) : trs;
  return slice.fold<double>(0, (a, b) => a + b) / period;
}

({double upper, double mid, double lower, double std}) bollinger(List<double> closes, [int period = 20]) {
  final slice = closes.length > period ? closes.sublist(closes.length - period) : closes;
  final mean = slice.fold<double>(0, (a, b) => a + b) / period;
  final variance = slice.fold<double>(0, (a, b) => a + pow(b - mean, 2)) / period;
  final std = sqrt(variance);
  return (upper: mean + 2 * std, mid: mean, lower: mean - 2 * std, std: std);
}
