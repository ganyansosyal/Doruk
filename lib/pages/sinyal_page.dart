import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/sinyal_engine.dart';
import '../widgets/coin_search.dart';

const _amber = Color(0xFFFBBF24);

class SinyalPage extends StatefulWidget {
  const SinyalPage({super.key});
  @override
  State<SinyalPage> createState() => _SinyalPageState();
}

class _SinyalPageState extends State<SinyalPage> {
  String _input = '';
  String _tip = 'scalp';
  String _tf = '15m';
  bool _loading = false;
  String? _error;
  SinyalResult? _res;

  static const _tfLbl = {'15m': '15dk', '30m': '30dk', '1h': '1S', '4h': '4S', '1d': '1G'};

  Future<void> _run() async {
    if (_input.isEmpty) {
      setState(() => _error = 'Önce bir coin yaz veya seç');
      return;
    }
    final sym = _input.endsWith('USDT') ? _input : '${_input}USDT';
    setState(() { _loading = true; _error = null; });
    try {
      final r = await runSinyal(sym, _tip, _tf);
      if (mounted) setState(() { _res = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'.replaceFirst('Exception: ', ''); _res = null; _loading = false; });
    }
  }

  void _setTip(String tip) {
    setState(() {
      _tip = tip;
      if (!sinyalTfler[tip]!.contains(_tf)) _tf = sinyalTfler[tip]!.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sinyal'), leading: BackButton(onPressed: () => context.go('/more'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        CoinSearch(minVolume: 1000000, onChanged: (v) => _input = v, onSubmit: (s) { _input = s; _run(); }),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final e in const {'scalp': '⚡ Scalp', 'swing': '🌊 Swing', 'pozisyon': '🏔️ Pozisyon'}.entries)
            ChoiceChip(label: Text(e.value), selected: _tip == e.key, onSelected: (_) => _setTip(e.key)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final tf in sinyalTfler[_tip]!)
            ChoiceChip(label: Text(_tfLbl[tf]!), selected: _tf == tf, onSelected: (_) => setState(() => _tf = tf)),
        ]),
        const SizedBox(height: 10),
        FilledButton(onPressed: _loading ? null : _run, child: const Text('SİNYAL ÜRET')),
        const SizedBox(height: 12),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        if (_error != null) Center(child: Text(_error!, style: const TextStyle(color: kDown), textAlign: TextAlign.center)),
        if (!_loading && _res != null) ..._body(_res!),
      ]),
    );
  }

  List<Widget> _body(SinyalResult r) {
    final wait = r.direction == 'BEKLE';
    final dc = r.direction == 'LONG' ? kUp : r.direction == 'SHORT' ? kDown : _amber;
    final emoji = r.direction == 'LONG' ? '🟢' : r.direction == 'SHORT' ? '🔴' : '⚠️';
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(r.symbol.replaceAll('USDT', ''), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text(fmtPrice(r.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 12),
            Text('${r.direction} $emoji', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: dc)),
            Text('Güç: ${r.strength}  ·  Long ${r.longScore} / Short ${r.shortScore}', style: const TextStyle(color: kTextDim, fontSize: 12)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 8,
                child: Row(children: [
                  Expanded(flex: r.longPct.clamp(1, 99), child: Container(color: kUp)),
                  Expanded(flex: (100 - r.longPct).clamp(1, 99), child: Container(color: kDown)),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('%${r.longPct} Long', style: const TextStyle(color: kUp, fontSize: 10)),
              Text('%${100 - r.longPct} Short', style: const TextStyle(color: kDown, fontSize: 10)),
            ]),
          ]),
        ),
      ),
      _title(wait ? 'NET YÖN YOK — REFERANS SEVİYELER' : 'İŞLEM PLANI'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            _row('Giriş', fmtPrice(r.entry), kText),
            if (wait) ...[
              _row('Stop (long olursa)', fmtPrice(r.slLongWait), kDown),
              _row('Stop (short olursa)', fmtPrice(r.slShortWait), kDown),
            ] else
              _row('Stop Loss', fmtPrice(r.sl!), kDown, sub: '-${r.slPct.toStringAsFixed(2)}%'),
            if (!wait) ...[
              _row('TP1', fmtPrice(r.tp1), kUp, sub: 'R:R ${r.rr1}'),
              _row('TP2', fmtPrice(r.tp2), kAccent2, sub: 'R:R ${r.rr2}'),
              _row('TP3', fmtPrice(r.tp3), const Color(0xFFA78BFA), sub: 'R:R ${r.rr3}'),
            ],
          ]),
        ),
      ),
      _title('GÖSTERGELER'),
      Card(
        child: Column(children: [
          _ind('RSI (14)', r.rsi.toStringAsFixed(1)),
          _ind('MACD histogram', r.macdHist.toStringAsFixed(5)),
          _ind('EMA20 / EMA50', '${r.price > r.ema20 ? '↑' : '↓'} / ${r.price > r.ema50 ? '↑' : '↓'}'),
          _ind('OBV', r.obvBull ? 'Alım ↑' : 'Satım ↓'),
          _ind('Bollinger konumu', '%${r.bbPos}'),
          _ind('Hacim / ort.', '${r.volRatio.toStringAsFixed(2)}x'),
          _ind('ATR', '%${r.atrPct.toStringAsFixed(2)}'),
          if (r.supDist != null) _ind('En yakın destek', '-%${r.supDist!.toStringAsFixed(2)}'),
          if (r.resDist != null) _ind('En yakın direnç', '+%${r.resDist!.toStringAsFixed(2)}'),
        ]),
      ),
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Bu bir yatırım tavsiyesi değildir.', style: TextStyle(color: kTextDim, fontSize: 10), textAlign: TextAlign.center),
      ),
    ];
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextDim, letterSpacing: 1)),
      );

  Widget _row(String l, String v, Color c, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: const TextStyle(color: kTextDim)),
          Row(children: [
            Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: c)),
            if (sub != null) Padding(padding: const EdgeInsets.only(left: 8), child: Text(sub, style: TextStyle(color: c, fontSize: 11))),
          ]),
        ]),
      );

  Widget _ind(String l, String v) => ListTile(
        dense: true,
        title: Text(l, style: const TextStyle(color: kTextDim, fontSize: 13)),
        trailing: Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
      );
}
