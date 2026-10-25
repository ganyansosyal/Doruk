import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/fibo_engine.dart';
import '../widgets/coin_search.dart';

class FiboPage extends StatefulWidget {
  const FiboPage({super.key});
  @override
  State<FiboPage> createState() => _FiboPageState();
}

class _FiboPageState extends State<FiboPage> {
  String _input = 'BTC';
  String _tf = '1h';
  bool _loading = false;
  String? _error;
  FiboResult? _res;

  String get _symbol => _input.endsWith('USDT') ? _input : '${_input}USDT';

  Future<void> _run() async {
    if (_input.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await runFibo(_symbol, _tf);
      if (mounted) setState(() { _res = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'.replaceFirst('Exception: ', ''); _res = null; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fibonacci'), leading: BackButton(onPressed: () => context.go('/more'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        CoinSearch(
          initial: 'BTC',
          onChanged: (v) => _input = v,
          onSubmit: (s) {
            _input = s;
            _run();
          },
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final e in const {'1h': '1 Saat', '4h': '4 Saat', '1d': '1 Gün', '1w': '1 Hafta'}.entries)
            ChoiceChip(label: Text(e.value), selected: _tf == e.key, onSelected: (_) => setState(() => _tf = e.key)),
        ]),
        const SizedBox(height: 10),
        FilledButton(onPressed: _loading ? null : _run, child: const Text('HESAPLA')),
        const SizedBox(height: 12),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        if (_error != null) Center(child: Text(_error!, style: const TextStyle(color: kDown), textAlign: TextAlign.center)),
        if (!_loading && _res != null) ..._body(_res!),
      ]),
    );
  }

  List<Widget> _body(FiboResult r) {
    final trendC = r.isUp ? kUp : kDown;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(r.symbol.replaceAll('USDT', ''), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text(fmtPrice(r.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(r.isUp ? '📈 Yükseliş Trendi' : '📉 Düşüş Trendi', style: TextStyle(color: trendC, fontWeight: FontWeight.w800)),
              Text('${r.chgPct >= 0 ? '+' : ''}${r.chgPct.toStringAsFixed(2)}% (24s)',
                  style: TextStyle(color: r.chgPct >= 0 ? kUp : kDown, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Dip ${fmtPrice(r.low)}', style: const TextStyle(color: kTextDim, fontSize: 11)),
              Text('Zirve ${fmtPrice(r.high)}', style: const TextStyle(color: kTextDim, fontSize: 11)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(value: r.curPos, minHeight: 8, color: kAccent, backgroundColor: Colors.white10),
            ),
          ]),
        ),
      ),
      if (r.resistances.isNotEmpty) _near('EN YAKIN DİRENÇLER', r.resistances, r.price, kDown),
      if (r.supports.isNotEmpty) _near('EN YAKIN DESTEKLER', r.supports, r.price, kUp),
      _title('GERİ ÇEKİLME SEVİYELERİ'),
      for (final l in r.retrace) _level(l, l == r.nearest),
      _title('HEDEF SEVİYELERİ'),
      for (final l in r.ext) _level(l, l == r.nearest),
    ];
  }

  Widget _near(String t, List<FiboLevel> ls, double price, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(t),
        Card(
          child: Column(children: [
            for (final l in ls.take(2))
              ListTile(
                dense: true,
                title: Text('${l.label}  ${fmtPrice(l.price)}', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
                trailing: Text('${l.distPct >= 0 ? '+' : ''}${l.distPct.toStringAsFixed(2)}%', style: const TextStyle(color: kTextDim)),
              ),
          ]),
        ),
      ]);

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextDim, letterSpacing: 1)),
      );

  Widget _level(FiboLevel l, bool isNearest) {
    final c = Color(l.color);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isNearest ? kAccent : Colors.transparent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${l.golden ? '✨ ' : ''}${l.label}', style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 15)),
            Text(fmtPrice(l.price), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${l.distPct >= 0 ? '▲ +' : '▼ '}${l.distPct.toStringAsFixed(2)}%',
                style: TextStyle(color: l.distPct >= 0 ? kUp : kDown, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text(l.desc, style: const TextStyle(color: kTextDim, fontSize: 11)),
          if (isNearest) const Text('◀ Fiyata en yakın seviye', style: TextStyle(color: kAccent, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
