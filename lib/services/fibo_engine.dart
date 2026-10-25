import 'dart:math';
import 'binance_service.dart';

class FiboLevel {
  final double pct;
  final String label;
  final int color;
  final bool ext, golden;
  double price = 0, distPct = 0;
  String desc = '';
  FiboLevel(this.pct, this.label, this.color, this.ext, {this.golden = false});
}

List<FiboLevel> _defs() => [
      FiboLevel(0, '0%', 0xFFFF4664, false),
      FiboLevel(0.236, '23.6%', 0xFFFF7A45, false),
      FiboLevel(0.382, '38.2%', 0xFFFBBF24, false),
      FiboLevel(0.5, '50%', 0xFF00D4FF, false),
      FiboLevel(0.618, '61.8%', 0xFF00E676, false, golden: true),
      FiboLevel(0.786, '78.6%', 0xFFA78BFA, false),
      FiboLevel(1, '100%', 0xFFFF4664, false),
      FiboLevel(1.272, '127.2%', 0xFFF97316, true),
      FiboLevel(1.414, '141.4%', 0xFFFACC15, true),
      FiboLevel(1.618, '161.8%', 0xFF00FFCC, true, golden: true),
      FiboLevel(2.0, '200%', 0xFFC084FC, true),
      FiboLevel(2.618, '261.8%', 0xFF818CF8, true),
    ];

String _desc(String l, bool up) {
  switch (l) {
    case '0%':
      return up ? 'Dönem zirvesi — güçlü direnç noktası, kırılırsa yükseliş devam eder' : 'Dönem zirvesi — kırılırsa düşüş hızlanabilir';
    case '23.6%':
      return up ? 'Zayıf geri çekilme — düşüş sığ, alıcılar hâlâ güçlü' : 'Zayıf tepki yükselişi — satıcılar hâlâ güçlü';
    case '38.2%':
      return up ? 'Orta geri çekilme — sağlıklı düzeltme, tepki alınabilir' : 'Orta tepki yükselişi — sağlıklı düzeltme olabilir';
    case '50%':
      return 'Tam orta nokta — psikolojik denge seviyesi';
    case '61.8%':
      return '✨ Altın Oran — en kritik destek/direnç, profesyonellerin izlediği seviye';
    case '78.6%':
      return up ? 'Derin geri çekilme — dip yakın, kırılırsa trend değişebilir' : 'Derin tepki yükselişi — zirve yakın, kırılırsa trend değişebilir';
    case '100%':
      return up ? 'Dönem dibi — burası kırılırsa düşüş devam eder' : 'Dönem dibi — kırılırsa yükselişe dönebilir';
    case '127.2%':
      return up ? '1. uzatma hedefi — zirveyi kırdıktan sonra 1. fiyat hedefi' : '1. uzatma hedefi — dibi kırdıktan sonra 1. fiyat hedefi';
    case '141.4%':
      return up ? '2. uzatma hedefi — güçlü yükselişte ulaşılabilecek seviye' : '2. uzatma hedefi — güçlü düşüşte ulaşılabilecek seviye';
    case '161.8%':
      return up ? '✨ Altın Oran Hedef — güçlü boğa trendinde ana fiyat hedefi' : '✨ Altın Oran Hedef — güçlü ayı trendinde ana fiyat hedefi';
    case '200%':
      return up ? '2x hedef — zirveden 2 katı mesafede büyük direnç' : '2x hedef — dipten 2 katı mesafede büyük destek';
    default:
      return 'Güçlü uzatma — çok güçlü trendlerde ulaşılan uzun vadeli hedef';
  }
}

class FiboResult {
  final String symbol, tf;
  final double price, chgPct, high, low, curPos;
  final bool isUp;
  final List<FiboLevel> retrace, ext, supports, resistances;
  final FiboLevel nearest;
  FiboResult(this.symbol, this.tf, this.price, this.chgPct, this.high, this.low, this.curPos, this.isUp,
      this.retrace, this.ext, this.supports, this.resistances, this.nearest);
}

Future<FiboResult> runFibo(String symbol, String tf) async {
  const limits = {'1h': 200, '4h': 150, '1d': 120, '1w': 80};
  final res = await Future.wait<dynamic>([
    BinanceService.klines(symbol, tf, limit: limits[tf] ?? 150),
    BinanceService.ticker24h(symbol),
  ]);
  final c = res[0] as List<Kline>;
  final t = res[1] as Ticker;
  final n = c.length;
  if (n == 0) throw Exception('Mum verisi alınamadı, lütfen tekrar deneyin.');
  final cur = t.price;
  if (cur <= 0) throw Exception('Güncel fiyat alınamadı.');

  final win = min(100, n);
  double high = -double.infinity, low = double.infinity;
  for (var i = n - win; i < n; i++) {
    if (c[i].high > high) high = c[i].high;
    if (c[i].low < low) low = c[i].low;
  }

  bool up;
  if (win < 4) {
    up = c[n - 1].close >= c[n - win].close;
  } else {
    final slice = c.sublist(n - win);
    final half = win ~/ 2;
    final a = slice.sublist(0, half).fold<double>(0, (s, k) => s + k.close) / half;
    final b = slice.sublist(half).fold<double>(0, (s, k) => s + k.close) / (win - half);
    up = b >= a;
  }

  final range = high - low;
  if (range <= 0) throw Exception('Fiyat aralığı hesaplanamadı. Farklı bir zaman dilimi deneyin.');
  final curPos = ((cur - low) / range).clamp(0.0, 1.0);

  final defs = _defs();
  for (final l in defs) {
    l.price = l.ext
        ? (up ? high + (l.pct - 1) * range : low - (l.pct - 1) * range)
        : (up ? high - l.pct * range : low + l.pct * range);
    l.distPct = (l.price - cur) / cur * 100;
    l.desc = _desc(l.label, up);
  }
  final retrace = defs.where((l) => !l.ext).toList();
  final ext = defs.where((l) => l.ext).toList();
  final sup = retrace.where((l) => l.price < cur).toList()..sort((a, b) => b.price.compareTo(a.price));
  final res2 = retrace.where((l) => l.price > cur).toList()..sort((a, b) => a.price.compareTo(b.price));
  final nearest = defs.reduce((a, b) => a.distPct.abs() <= b.distPct.abs() ? a : b);

  return FiboResult(symbol, tf, cur, t.changePct, high, low, curPos, up, retrace, ext,
      sup.take(3).toList(), res2.take(3).toList(), nearest);
}
