import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/analysis_engine.dart';
import '../services/binance_service.dart';

const _kAmber = Color(0xFFFBBF24);
const _kPurple = Color(0xFFA78BFA);

class AnalizPage extends StatefulWidget {
  const AnalizPage({super.key});
  @override
  State<AnalizPage> createState() => _AnalizPageState();
}

class _AnalizPageState extends State<AnalizPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Ticker> _symbols = [];
  List<Ticker> _suggest = [];
  String? _symbol;
  String _tf = '1h';
  bool _loading = false;
  String? _error;
  AnalysisResult? _res;

  @override
  void initState() {
    super.initState();
    BinanceService.tickers24h().then((l) {
      if (mounted) setState(() => _symbols = l.where((t) => t.quoteVolume > 500000).toList());
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _suggest = []; _res = null; _symbol = null; _error = null; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () => _search(q.trim().toUpperCase()));
  }

  Future<void> _search(String uq) async {
    var f = _symbols.where((t) => t.symbol.replaceAll('USDT', '').contains(uq)).toList();
    f.sort((a, b) {
      final as = a.symbol.startsWith(uq), bs = b.symbol.startsWith(uq);
      return as == bs ? 0 : (as ? -1 : 1);
    });
    f = f.take(8).toList();
    if (f.isEmpty) {
      try {
        f = [await BinanceService.ticker24h('${uq}USDT')];
      } catch (_) {}
    }
    if (mounted) setState(() => _suggest = f);
  }

  void _select(Ticker t) {
    FocusScope.of(context).unfocus();
    _ctrl.text = t.symbol.replaceAll('USDT', '');
    setState(() { _symbol = t.symbol; _suggest = []; });
    _run();
  }

  Future<void> _run() async {
    final s = _symbol;
    if (s == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await runAnalysis(s, _tf);
      if (mounted) setState(() { _res = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'.replaceFirst('Exception: ', ''); _loading = false; _res = null; });
    }
  }

  Color _cls(String c) => c == 'bull' || c == 'buy' ? kUp : c == 'bear' || c == 'none' ? kDown : _kAmber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kripto Analiz'),
        leading: BackButton(onPressed: () => context.go('/more')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Coin ara (BTC, ETH...)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _ctrl.clear();
                        _onChanged('');
                      }),
              filled: true,
              fillColor: kCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          if (_suggest.isNotEmpty)
            Card(
              child: Column(children: [
                for (final t in _suggest)
                  ListTile(
                    dense: true,
                    onTap: () => _select(t),
                    title: Text(t.symbol.replaceAll('USDT', '')),
                    subtitle: Text('Vol \$${fmtVol(t.quoteVolume)}', style: const TextStyle(color: kTextDim, fontSize: 11)),
                    trailing: Text('${t.changePct >= 0 ? '+' : ''}${t.changePct.toStringAsFixed(2)}%',
                        style: TextStyle(color: t.changePct >= 0 ? kUp : kDown, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
          const SizedBox(height: 10),
          Row(children: [
            for (final tf in const ['1h', '4h', '1d'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(tf == '1h' ? '1 Saat' : tf == '4h' ? '4 Saat' : 'Günlük'),
                  selected: _tf == tf,
                  onSelected: (_) {
                    setState(() => _tf = tf);
                    _run();
                  },
                ),
              ),
          ]),
          const SizedBox(height: 12),
          if (_loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('⚠️', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: kTextDim), textAlign: TextAlign.center),
                TextButton(onPressed: _run, child: const Text('Tekrar dene')),
              ]),
            ),
          if (!_loading && _error == null && _res == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('Analiz için bir coin seç', style: TextStyle(color: kTextDim))),
            ),
          if (!_loading && _res != null) ..._result(_res!),
        ],
      ),
    );
  }

  List<Widget> _result(AnalysisResult r) {
    final coin = r.symbol.replaceAll('USDT', '');
    final sc = _cls(r.signalClass);
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$coin / USDT', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text(r.symbol, style: const TextStyle(color: kTextDim, fontSize: 11)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtPrice(r.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text('${r.chgPct >= 0 ? '+' : ''}${r.chgPct.toStringAsFixed(2)}% (24s)',
                  style: TextStyle(color: r.chgPct >= 0 ? kUp : kDown, fontSize: 12)),
            ]),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${r.signalEmoji} ${r.signal}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: sc)),
              Text('${r.score}/9', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: sc)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: r.confidence / 100, minHeight: 8, color: sc, backgroundColor: Colors.white10),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Güven: ${r.confidence.toStringAsFixed(0)}%', style: const TextStyle(color: kTextDim, fontSize: 11)),
            ),
          ]),
        ),
      ),
      _title('SEVİYELER'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            _lvl('Giriş', fmtPrice(r.price), kText),
            _lvl('Stop Loss', fmtPrice(r.sl), kDown, sub: '-${(r.risk / r.price * 100).toStringAsFixed(2)}%'),
            _lvl('TP1', fmtPrice(r.tp1), kUp),
            _lvl('TP2', fmtPrice(r.tp2), kAccent2),
            _lvl('TP3', fmtPrice(r.tp3), _kPurple),
          ]),
        ),
      ),
      _title('DESTEK / DİRENÇ'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            for (final z in r.resistances) _zone(z, r.price),
            for (final z in r.supports) _zone(z, r.price),
            if (r.resistances.isEmpty && r.supports.isEmpty)
              const Text('Yeterli destek/direnç verisi yok', style: TextStyle(color: kTextDim, fontSize: 12)),
          ]),
        ),
      ),
      _title('GÖSTERGELER'),
      Card(
        child: Column(children: [
          for (final i in r.indicators)
            ListTile(
              dense: true,
              title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(i.text, style: TextStyle(color: _cls(i.cls), fontSize: 11)),
              trailing: Text(i.value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
      _title('ÇOKLU ZAMAN DİLİMİ'),
      Row(children: [
        for (final m in r.mtf)
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  Text(m.label, style: const TextStyle(fontSize: 9, color: kTextDim, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(m.bull ? '📈 BOĞA' : m.bear ? '📉 AYI' : '↔ NÖTR',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: m.bull ? kUp : m.bear ? kDown : _kAmber)),
                  const SizedBox(height: 4),
                  Text(m.emaUp ? 'Trend ↑' : 'Trend ↓', style: const TextStyle(fontSize: 10, color: kTextDim)),
                ]),
              ),
            ),
          ),
      ]),
      if (r.mtfWarning != null)
        Card(
          color: kDown.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(r.mtfWarning!, style: const TextStyle(color: Color(0xFFFF8080), fontSize: 11)),
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            'Son güncelleme: ${r.updated.hour.toString().padLeft(2, '0')}:${r.updated.minute.toString().padLeft(2, '0')}:${r.updated.second.toString().padLeft(2, '0')}',
            style: const TextStyle(color: kTextDim, fontSize: 10),
          ),
        ),
      ),
    ];
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextDim, letterSpacing: 1)),
      );

  Widget _lvl(String label, String value, Color c, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: kTextDim)),
          Row(children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: c)),
            if (sub != null) Padding(padding: const EdgeInsets.only(left: 8), child: Text(sub, style: TextStyle(color: c, fontSize: 11))),
          ]),
        ]),
      );

  Widget _zone(Zone z, double price) {
    final c = z.isRes ? kDown : kUp;
    final dist = ((z.price - price).abs() / price * 100).toStringAsFixed(2);
    final str = z.strength == 'strong' ? 'GÜÇLÜ' : z.strength == 'medium' ? 'ORTA' : 'ZAYIF';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(flex: 3, child: Text(z.isRes ? '⬆ DİRENÇ' : '⬇ DESTEK', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w900))),
        Expanded(flex: 3, child: Text(fmtPrice(z.price), style: const TextStyle(fontWeight: FontWeight.w800))),
        Expanded(flex: 2, child: Text('${z.tests}x', style: const TextStyle(color: kTextDim, fontSize: 11))),
        Expanded(flex: 2, child: Text(str, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800))),
        Text('${z.isRes ? '+' : '-'}$dist%', style: const TextStyle(color: kTextDim, fontSize: 10)),
      ]),
    );
  }
}
