import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/binance_service.dart';
import '../services/doviz_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/coin_search.dart';

// ───────────────────────── yardımcılar ─────────────────────────

String _trNum(double v, int dec) => NumberFormat('#,##0.${'#' * dec}', 'tr_TR').format(v);
String _usd(double p) => '\$${_trNum(p, priceDecimals(p))}';

String _glPrice(double p) {
  if (p >= 1000) return '\$${NumberFormat('#,##0', 'en_US').format(p)}';
  if (p >= 1) return '\$${p.toStringAsFixed(2)}';
  if (p >= 0.01) return '\$${p.toStringAsFixed(4)}';
  return '\$${p.toStringAsFixed(6)}';
}

String _fmtCap(double n) {
  if (n >= 1e12) return '\$${(n / 1e12).toStringAsFixed(2)}T';
  if (n >= 1e9) return '\$${(n / 1e9).toStringAsFixed(0)}B';
  return '\$${n.toStringAsFixed(0)}';
}

String _pct(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';

// Web'deki dolaşım arzı tablosu (piyasa özeti hesabı)
const _supply = <String, double>{
  'BTCUSDT': 19850000,
  'ETHUSDT': 120270000,
  'BNBUSDT': 145887575,
  'SOLUSDT': 468000000,
  'XRPUSDT': 57800000000,
  'ADAUSDT': 35700000000,
  'DOGEUSDT': 146000000000,
  'AVAXUSDT': 412000000,
  'TRXUSDT': 87000000000,
  'LINKUSDT': 608000000,
  'LTCUSDT': 74800000,
  'DOTUSDT': 1400000000,
  'UNIUSDT': 600000000,
  'ATOMUSDT': 390000000,
  'NEARUSDT': 1130000000,
  'MATICUSDT': 9900000000,
  'APTUSDT': 1020000000,
  'SHIBUSDT': 589000000000000,
  'OPUSDT': 1090000000,
  'ARBUSDT': 3370000000,
};

// İzleme listesindeki yerel (döviz/altın) öğeler → truncgil anahtarı
const _localKey = <String, String>{
  'USD-TRY': 'USD',
  'EUR-TRY': 'EUR',
  'GBP-TRY': 'GBP',
  'XAU-GR': 'gram-altin',
  'XAU-CE': 'ceyrek-altin',
  'XAU-TA': 'tam-altin',
  'XAU-ONS': 'ons',
  'XAG-GR': 'gumus',
};

// Canlı piyasa şeridi: (etiket, truncgil anahtarı, para birimi simgesi, altın mı)
const _seritItems = <(String, String, String, bool)>[
  ('🇺🇸 USD/TRY', 'USD', '₺', false),
  ('🇪🇺 EUR/TRY', 'EUR', '₺', false),
  ('🇬🇧 GBP/TRY', 'GBP', '₺', false),
  ('🥇 GR ALTIN', 'gram-altin', '₺', true),
  ('🥇 ÇEY ALTIN', 'ceyrek-altin', '₺', true),
  ('🥇 TAM ALTIN', 'tam-altin', '₺', true),
  ('🥇 ALTIN ONS', 'ons', '\$', true),
  ('🥈 GR GÜMÜŞ', 'gumus', '₺', true),
];

// Modül ızgarası: (rota, etiket, ikon, renk)
const _moduller = <(String, String, IconData, Color)>[
  ('analiz', 'ANALİZ', Icons.bar_chart_rounded, Color(0xFF06B6D4)),
  ('notes', 'NOT DEFTERİ', Icons.description_outlined, Color(0xFF22C55E)),
  ('takvim', 'TAKVİM', Icons.calendar_month_outlined, Color(0xFF3B82F6)),
  ('doviz', 'DÖVİZ ÇEVİR', Icons.currency_exchange, Color(0xFFF97316)),
  ('ceviri', 'ÇEVİRİ', Icons.translate, Color(0xFFF43F5E)),
  ('deprem', 'DEPREM', Icons.monitor_heart_outlined, Color(0xFFEF6C2F)),
  ('sinyal', 'TREND', Icons.sensors, Color(0xFF4ADE80)),
  ('cuzdan', 'CÜZDAN', Icons.account_balance_wallet_outlined, Color(0xFFA855F7)),
  ('futures', 'STRATEJİ', Icons.trending_up, Color(0xFFFB923C)),
  ('fibo', 'AUTO FİBO', Icons.architecture, Color(0xFFFACC15)),
  ('sentinel', 'SENTİNEL', Icons.gps_fixed, Color(0xFF8B5CF6)),
  ('nabiz', 'PİYASA NABZI', Icons.show_chart, Color(0xFF9F7AEA)),
  ('whale', 'WHALE', Icons.waves, Color(0xFF0EA5E9)),
  ('rsi', 'RSI', Icons.ssid_chart, Color(0xFFEF4444)),
  ('hacim', 'HACİM', Icons.equalizer, Color(0xFF22C55E)),
  ('cevirkazan', 'ÇEVİR KAZAN', Icons.casino_outlined, Color(0xFFF59E0B)),
];

const _fgLabels = {
  'Extreme Fear': 'AŞIRI KORKU',
  'Fear': 'KORKU',
  'Neutral': 'TARAFSIZ',
  'Greed': 'AÇGÖZLÜLÜK',
  'Extreme Greed': 'AŞIRI AÇGÖZLÜLÜK',
};
const _fgColors = {
  'Extreme Fear': Color(0xFFEF4444),
  'Fear': Color(0xFFF97316),
  'Neutral': Color(0xFFEAB308),
  'Greed': Color(0xFF84CC16),
  'Extreme Greed': Color(0xFF22C55E),
};

// ───────────────────────── sayfa ─────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<WlItem> _wl = [];
  List<Ticker> _all = [];
  Map<String, Ticker> _map = {};
  Map<String, dynamic> _doviz = {};
  final Map<String, List<double>> _spark = {};
  int? _fg, _fgY;
  String _fgLabel = '', _fgYLabel = '';
  bool _showUp = true;
  DateTime? _sonGuncelleme;
  Timer? _fast, _slow;

  @override
  void initState() {
    super.initState();
    _init();
    _fast = Timer.periodic(const Duration(seconds: 15), (_) => _loadTickers());
    _slow = Timer.periodic(const Duration(minutes: 2), (_) {
      _loadDoviz();
      _loadFg();
      _loadSparks();
    });
  }

  @override
  void dispose() {
    _fast?.cancel();
    _slow?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _loadTickers();
    _loadDoviz();
    _loadFg();
    final l = await WatchlistService.load();
    if (!mounted) return;
    setState(() => _wl = l);
    _loadSparks();
  }

  Future<void> _loadTickers() async {
    try {
      final t = await BinanceService.tickers24h();
      if (!mounted) return;
      setState(() {
        _all = t;
        _map = {for (final x in t) x.symbol: x};
        _sonGuncelleme = DateTime.now();
      });
    } catch (_) {}
  }

  Future<void> _loadDoviz() async {
    try {
      final d = await DovizService.fetchToday();
      if (mounted) setState(() => _doviz = d);
    } catch (_) {}
  }

  Future<void> _loadFg() async {
    try {
      final r = await http.get(Uri.parse('https://api.alternative.me/fng/?limit=2')).timeout(const Duration(seconds: 10));
      final d = jsonDecode(r.body)['data'] as List;
      if (!mounted) return;
      setState(() {
        _fg = int.tryParse('${d[0]['value']}');
        _fgLabel = '${d[0]['value_classification']}';
        _fgY = int.tryParse('${d[1]['value']}');
        _fgYLabel = '${d[1]['value_classification']}';
      });
    } catch (_) {}
  }

  Future<void> _loadSparks() async {
    final crypto = _wl.where((e) => e.type == 'crypto').toList();
    await Future.wait(crypto.map((e) async {
      try {
        final k = await BinanceService.klines(e.id, '1h', limit: 24);
        if (mounted) setState(() => _spark[e.id] = k.map((x) => x.close).toList());
      } catch (_) {}
    }));
  }

  void _ekle(String sym) {
    if (_wl.any((e) => e.id == sym)) return;
    setState(() => _wl = [..._wl, WlItem(sym, sym.replaceAll('USDT', ''), 'crypto')]);
    WatchlistService.save(_wl);
    _loadSparks();
  }

  void _sil(WlItem it) {
    setState(() => _wl = _wl.where((e) => e.id != it.id).toList());
    WatchlistService.save(_wl);
  }

  List<Ticker> _gl(bool up) {
    final f = _all
        .where((t) => !RegExp(r'DOWN|UP|BEAR|BULL').hasMatch(t.symbol) && t.quoteVolume > 5000000)
        .toList()
      ..sort((a, b) => b.changePct.compareTo(a.changePct));
    return up ? f.take(10).toList() : f.reversed.take(10).toList();
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        _serit(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: CoinSearch(
            hint: 'Coin, Altın veya Döviz ekle...',
            onChanged: (_) {},
            onSubmit: _ekle,
          ),
        ),
        _baslik('İZLEME LİSTEM', kAccent),
        _izleme(),
        const SizedBox(height: 18),
        const Center(
          child: Text('M O D Ü L L E R', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 4, color: kAccent)),
        ),
        const SizedBox(height: 12),
        _izgara(),
        const SizedBox(height: 8),
        _widgetlar(),
        const SizedBox(height: 14),
        _glBaslik(),
        _glListe(),
      ],
    );
  }

  // ───────────────────────── canlı piyasa şeridi ─────────────────────────

  Widget _serit() {
    final items = _seritItems.where((e) => _doviz[e.$2] is Map).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: kUp, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('CANLI PİYASA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2, color: kAccent2)),
        ]),
      ),
      SizedBox(
        height: 54,
        child: items.isEmpty
            ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final e = items[i];
                  final m = _doviz[e.$2] as Map;
                  final satis = '${m['Satış'] ?? m['Satis'] ?? '-'}';
                  final ch = DovizService.parseTR(m['Değişim'] ?? m['Degisim']);
                  final up = ch >= 0;
                  final gold = e.$4;
                  final tint = gold ? const Color(0xFFEAB308) : kAccent;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: tint.withOpacity(0.07),
                      border: Border.all(color: tint.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      Text(e.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: gold ? const Color(0xFFFDE68A) : kTextDim)),
                      const SizedBox(width: 10),
                      Text('${e.$3}$satis', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kText)),
                      const SizedBox(width: 10),
                      Text(_pct(ch), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: up ? kUp : kDown)),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _baslik(String t, Color c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2, color: c)),
        ]),
      );

  // ───────────────────────── izleme listesi ─────────────────────────

  Widget _izleme() {
    if (_wl.isEmpty) return const SizedBox(height: 160);
    final w = (MediaQuery.of(context).size.width - 32 - 20) / 3;
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _wl.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _wlKart(_wl[i], w),
      ),
    );
  }

  Widget _wlKart(WlItem it, double w) {
    String price = '…';
    double pct = 0;
    var hasData = false;
    if (it.type == 'crypto') {
      final t = _map[it.id];
      if (t != null) {
        price = _usd(t.price);
        pct = t.changePct;
        hasData = true;
      }
    } else {
      final k = _localKey[it.id];
      final m = k == null ? null : _doviz[k];
      if (m is Map) {
        price = '${it.id == 'XAU-ONS' ? '\$' : '₺'}${m['Satış'] ?? m['Satis'] ?? '-'}';
        pct = DovizService.parseTR(m['Değişim'] ?? m['Degisim']);
        hasData = true;
      }
    }
    final up = pct >= 0;
    final c = up ? kUp : kDown;
    final spark = _spark[it.id];
    return Container(
      width: w,
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF111C33), Color(0xFF070D1C)]),
        border: Border.all(color: kAccent.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: kAccent.withOpacity(0.18),
            child: Text(it.name.isEmpty ? '?' : it.name[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kAccent)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(it.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: kText))),
          GestureDetector(
            onTap: () => _sil(it),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kTextDim.withOpacity(0.6))),
              child: const Icon(Icons.close, size: 12, color: kTextDim),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(price, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: hasData ? c : kTextDim)),
        ),
        const SizedBox(height: 2),
        Text(hasData ? '%${pct.abs().toStringAsFixed(2)}' : '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.withOpacity(0.85))),
        const Spacer(),
        SizedBox(
          height: 34,
          width: double.infinity,
          child: (spark == null || spark.length < 2) ? const SizedBox.shrink() : CustomPaint(painter: _SparkPainter(spark, c)),
        ),
      ]),
    );
  }

  // ───────────────────────── modül ızgarası ─────────────────────────

  Widget _izgara() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.08,
        children: [for (final m in _moduller) _tile(m)],
      ),
    );
  }

  Widget _tile((String, String, IconData, Color) m) {
    final c = m.$4;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (m.$1 == 'cevirkazan') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎰 Çevir Kazan yakında')));
        } else {
          context.go('/${m.$1}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: RadialGradient(center: Alignment.topCenter, radius: 1.1, colors: [c.withOpacity(0.28), const Color(0xFF060A14)]),
          border: Border(top: BorderSide(color: c.withOpacity(0.55)), left: BorderSide(color: c.withOpacity(0.15)), right: BorderSide(color: c.withOpacity(0.15)), bottom: BorderSide(color: c.withOpacity(0.15))),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c, Color.lerp(c, Colors.black, 0.55)!]),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Icon(m.$3, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(m.$2, maxLines: 1, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: Color.lerp(c, Colors.white, 0.45))),
            ),
          ),
        ]),
      ),
    );
  }

  // ───────────────────────── Fear&Greed + Piyasa özeti ─────────────────────────

  Widget _widgetlar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _fgKart()),
          const SizedBox(width: 10),
          Expanded(child: _ozetKart()),
        ]),
      ),
    );
  }

  BoxDecoration get _kartDeko => BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0E1A33), Color(0xFF060B18)]),
        border: Border.all(color: kAccent.withOpacity(0.15)),
      );

  Widget _fgKart() {
    final v = _fg;
    final color = _fgColors[_fgLabel] ?? const Color(0xFFFBBF24);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _kartDeko,
      child: Column(children: [
        Row(children: [
          const Text('🧠', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          const Expanded(child: Text('FEAR & GREED', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: kAccent))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: kAccent.withOpacity(0.5))),
            child: const Text('GÜNCEL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1, color: kAccent)),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(height: 70, width: double.infinity, child: CustomPaint(painter: _GaugePainter(v ?? 50, color, v != null))),
        Text(v == null ? '—' : '$v', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color, height: 1)),
        const SizedBox(height: 2),
        Text(_fgLabels[_fgLabel] ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(_fgY == null ? '' : 'Dün: ${_fgLabels[_fgYLabel] ?? _fgYLabel} ($_fgY)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kTextDim)),
        const Spacer(),
        if (v != null)
          SizedBox(
            height: 14,
            child: Stack(alignment: Alignment.center, children: [
              Row(children: [
                for (final k in const [Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFEAB308), Color(0xFF84CC16), Color(0xFF22C55E)])
                  Expanded(child: Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: k, borderRadius: BorderRadius.circular(2)))),
              ]),
              Align(
                alignment: Alignment((v.clamp(0, 100) / 50.0) - 1.0, 0),
                child: Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _ozetKart() {
    double total = 0, btcCap = 0, vol = 0;
    var btcChg = 0.0;
    for (final e in _supply.entries) {
      final t = _map[e.key];
      if (t == null) continue;
      final cap = t.price * e.value;
      total += cap;
      vol += t.quoteVolume;
      if (e.key == 'BTCUSDT') {
        btcCap = cap;
        btcChg = t.changePct;
      }
    }
    final est = total / 0.82;
    final dom = est > 0 ? btcCap / est * 100 : 0.0;
    final ready = est > 0;
    final saat = _sonGuncelleme == null ? '--:--:--' : DateFormat('HH:mm:ss').format(_sonGuncelleme!);
    const lbl = TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: kAccent);
    return Container(
      decoration: _kartDeko,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            const Text('📈', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            const Expanded(child: Text('PİYASA ÖZETİ', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: kAccent))),
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: kUp, shape: BoxShape.circle)),
            const SizedBox(width: 3),
            const Text('CANLI', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kUp)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MKT CAP', style: lbl),
            const SizedBox(height: 2),
            Text(ready ? _fmtCap(est) : '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kText)),
            Text(ready ? '${btcChg >= 0 ? '▲ +' : '▼ '}${btcChg.toStringAsFixed(1)}%' : '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: btcChg >= 0 ? kUp : kDown)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BTC DOM.', style: lbl),
                const SizedBox(height: 2),
                Text(ready ? '${dom.toStringAsFixed(1)}%' : '—', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kText)),
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: (dom / 100).clamp(0.0, 1.0), minHeight: 5, backgroundColor: Colors.white10, color: kAccent)),
                const SizedBox(height: 3),
                Text(!ready ? '' : (dom > 50 ? '▲ BTC Baskın' : '▶ Altcoin Sezon'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: dom > 50 ? kUp : kTextDim)),
              ]),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('24S HACİM', style: lbl),
                const SizedBox(height: 2),
                Text(ready ? _fmtCap(vol) : '—', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kText)),
              ]),
            ),
          ),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: kAccent.withOpacity(0.12)))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Flexible(child: Text('SON GÜNC.', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, letterSpacing: 1, color: kTextDim))),
            Text(saat, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kAccent)),
          ]),
        ),
      ]),
    );
  }

  // ───────────────────────── en çok artan / gerileyen ─────────────────────────

  Widget _glBaslik() {
    final c = _showUp ? kUp : kDown;
    final n = _gl(_showUp).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => setState(() => _showUp = !_showUp),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: c.withOpacity(0.1), border: Border.all(color: c.withOpacity(0.5))),
            child: Text(_showUp ? '▲ YÜKSELEN' : '▼ DÜŞEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: c)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(_showUp ? 'EN ÇOK ARTAN' : 'EN ÇOK GERİLEYEN', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.5, color: kAccent))),
        Text('$n coin', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kAccent)),
      ]),
    );
  }

  Widget _glListe() {
    final list = _gl(_showUp);
    if (list.isEmpty) {
      return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    }
    final maxPct = list.first.changePct.abs() == 0 ? 1.0 : list.first.changePct.abs();
    final c = _showUp ? kUp : kDown;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(children: [
        Row(children: [
          for (var i = 0; i < math.min(3, list.length); i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _glBuyuk(list[i], i, c, maxPct)),
          ],
        ]),
        const SizedBox(height: 8),
        for (var i = 3; i < list.length; i++) _glSatir(list[i], i, c, maxPct),
      ]),
    );
  }

  Widget _rank(int i, Color c, {double size = 26}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(0.12), border: Border.all(color: c.withOpacity(0.6))),
        child: Text('${i + 1}', style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w900, color: c)),
      );

  Widget _bar(double pct, double maxPct, Color c) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(value: (pct.abs() / maxPct).clamp(0.0, 1.0), minHeight: 4, backgroundColor: Colors.white10, color: c),
      );

  Widget _glBuyuk(Ticker t, int i, Color c, double maxPct) {
    final sym = t.symbol.replaceAll('USDT', '');
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.withOpacity(0.2), const Color(0xFF070C16)]),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _rank(i, c, size: 24),
          if (i == 0) Text(_showUp ? '🔥' : '💀', style: const TextStyle(fontSize: 14)),
        ]),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(sym, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kText))),
        Text(_glPrice(t.price), style: const TextStyle(fontSize: 11, color: kTextDim)),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, child: Text('${_showUp ? '▲' : '▼'}${t.changePct.abs().toStringAsFixed(2)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c))),
        const SizedBox(height: 8),
        _bar(t.changePct, maxPct, c),
      ]),
    );
  }

  Widget _glSatir(Ticker t, int i, Color c, double maxPct) {
    final sym = t.symbol.replaceAll('USDT', '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [c.withOpacity(0.14), const Color(0xFF070C16)]),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Row(children: [
        _rank(i, c),
        const SizedBox(width: 14),
        Expanded(child: Text(sym, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kText))),
        Text(_glPrice(t.price), style: const TextStyle(fontSize: 12, color: kTextDim)),
        const SizedBox(width: 12),
        SizedBox(
          width: 76,
          child: Text('${_showUp ? '▲' : '▼'}${t.changePct.abs().toStringAsFixed(2)}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c)),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 44, child: _bar(t.changePct, maxPct, c)),
      ]),
    );
  }
}

// ───────────────────────── çizimler ─────────────────────────

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final minV = data.reduce(math.min), maxV = data.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height - ((data[i] - minV) / range) * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withOpacity(0.12));
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.data != data || old.color != color;
}

class _GaugePainter extends CustomPainter {
  final int value;
  final Color color;
  final bool ready;
  _GaugePainter(this.value, this.color, this.ready);

  @override
  void paint(Canvas canvas, Size size) {
    const cols = [Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFEAB308), Color(0xFF84CC16), Color(0xFF22C55E)];
    final c = Offset(size.width / 2, size.height - 2);
    final r = math.min(size.width / 2, size.height) - 8;
    final rect = Rect.fromCircle(center: c, radius: r);
    final seg = math.pi / cols.length;
    for (var i = 0; i < cols.length; i++) {
      canvas.drawArc(rect, math.pi + i * seg + 0.02, seg - 0.04, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 9..color = cols[i]);
    }
    if (!ready) return;
    final a = math.pi + (value.clamp(0, 100) / 100) * math.pi;
    final end = c + Offset(math.cos(a), math.sin(a)) * (r - 4);
    canvas.drawLine(c, end, Paint()..color = const Color(0xFF84CC16)..strokeWidth = 2..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value || old.color != color || old.ready != ready;
}
