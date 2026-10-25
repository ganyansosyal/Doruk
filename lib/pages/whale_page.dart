import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/whale_service.dart';
import '../widgets/coin_search.dart';

const _amber = Color(0xFFFBBF24);

class WhalePage extends StatefulWidget {
  const WhalePage({super.key});
  @override
  State<WhalePage> createState() => _WhalePageState();
}

class _WhalePageState extends State<WhalePage> {
  String _input = 'BTC';
  bool _daily = true;
  double _thresh = 10000;
  bool _loading = false;
  String? _error;
  WhaleDaily? _d;
  WhaleLive? _l;

  String get _symbol => _input.endsWith('USDT') ? _input : '${_input}USDT';

  Future<void> _run() async {
    if (_input.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_daily) {
        final r = await whaleDaily(_symbol);
        if (mounted) setState(() { _d = r; _l = null; });
      } else {
        final r = await whaleLive(_symbol, _thresh);
        if (mounted) setState(() { _l = r; _d = null; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'.replaceFirst('Exception: ', ''); _d = null; _l = null; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _pressureColor(double bp) => bp >= 65 ? kUp : bp <= 35 ? kDown : _amber;
  String _pressureLabel(double bp) => bp >= 65 ? '💪 Alım Baskısı' : bp <= 35 ? '🔻 Satım Baskısı' : '⚖️ Dengeli';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Whale'), leading: BackButton(onPressed: () => context.go('/more'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        CoinSearch(initial: 'BTC', onChanged: (v) => _input = v, onSubmit: (s) { _input = s; _run(); }),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('📅 Günlük'), selected: _daily, onSelected: (_) => setState(() => _daily = true)),
          ChoiceChip(label: const Text('⚡ Anlık'), selected: !_daily, onSelected: (_) => setState(() => _daily = false)),
        ]),
        if (!_daily) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final v in const [5000.0, 10000.0, 50000.0, 100000.0, 500000.0])
              ChoiceChip(label: Text(whaleFmt(v)), selected: _thresh == v, onSelected: (_) => setState(() => _thresh = v)),
          ]),
        ],
        const SizedBox(height: 10),
        FilledButton(onPressed: _loading ? null : _run, child: const Text('TARA')),
        const SizedBox(height: 12),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        if (_error != null) Center(child: Text(_error!, style: const TextStyle(color: kDown))),
        if (!_loading && _d != null) ..._dailyBody(_d!),
        if (!_loading && _l != null) ..._liveBody(_l!),
      ]),
    );
  }

  Widget _summary(String title, double bp, String sub) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(title, style: const TextStyle(color: kTextDim, fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(_pressureLabel(bp), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _pressureColor(bp))),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 8,
                child: Row(children: [
                  Expanded(flex: (bp * 10).round().clamp(1, 999), child: Container(color: kUp)),
                  Expanded(flex: ((100 - bp) * 10).round().clamp(1, 999), child: Container(color: kDown)),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('%${bp.toStringAsFixed(1)} Alım', style: const TextStyle(color: kUp, fontSize: 11)),
              Text('%${(100 - bp).toStringAsFixed(1)} Satım', style: const TextStyle(color: kDown, fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            Text(sub, style: const TextStyle(color: kTextDim, fontSize: 11), textAlign: TextAlign.center),
          ]),
        ),
      );

  List<Widget> _dailyBody(WhaleDaily d) {
    final maxV = d.hours.map((h) => h.quoteVol).reduce((a, b) => a > b ? a : b);
    return [
      _summary('BUGÜN (TR 00:00 →) — ${_symbol.replaceAll('USDT', '')}', d.buyPct,
          'Hacim ${whaleFmt(d.totalVol)} · Alım ${whaleFmt(d.totalBuy)} · Satım ${whaleFmt(d.totalSell)} · ${d.totalTrades} işlem\nEn yoğun saat: ${d.maxVolHour.trLabel}'),
      const SizedBox(height: 6),
      for (final h in d.hours.reversed) _hourRow(h, maxV, h.openTime == d.maxVolHour.openTime),
    ];
  }

  Widget _hourRow(WhaleHour h, double maxV, bool isMax) {
    final bp = h.buyPct;
    final empty = h.quoteVol <= 0;
    final Color col;
    final String lbl;
    if (empty) { col = kTextDim; lbl = '⏳ Veri yok'; }
    else if (bp >= 65) { col = kUp; lbl = '💪 Güçlü alım'; }
    else if (bp >= 55) { col = kAccent; lbl = '🔵 Hafif alım'; }
    else if (bp >= 45) { col = kTextDim; lbl = '⚖️ Dengeli'; }
    else if (bp >= 35) { col = const Color(0xFFFB923C); lbl = '🟠 Hafif satım'; }
    else { col = kDown; lbl = '🔴 Güçlü satım'; }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _hourSheet(h, col, lbl),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            SizedBox(width: 50, child: Text(h.trLabel, style: TextStyle(fontWeight: FontWeight.w900, color: isMax ? kUp : kText))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: maxV > 0 ? (h.quoteVol / maxV).clamp(0.02, 1.0) : 0.02, minHeight: 6, color: col, backgroundColor: Colors.white10),
                ),
                const SizedBox(height: 4),
                Text('$lbl · ${whaleFmt(h.quoteVol)}${isMax ? ' · 🔥 en yoğun' : ''}', style: TextStyle(color: col, fontSize: 11)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _hourSheet(WhaleHour h, Color col, String lbl) {
    final pchg = h.open > 0 ? (h.close - h.open) / h.open * 100 : 0.0;
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${h.trLabel} — $lbl', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: col)),
          const SizedBox(height: 12),
          _kv('Hacim', whaleFmt(h.quoteVol)),
          _kv('Alım', '${whaleFmt(h.buyQuote)} (%${h.buyPct.toStringAsFixed(1)})'),
          _kv('Satım', whaleFmt(h.sellQuote)),
          _kv('İşlem sayısı', '${h.trades}'),
          _kv('Açılış / Kapanış', '${fmtPrice(h.open)} → ${fmtPrice(h.close)}'),
          _kv('Yüksek / Düşük', '${fmtPrice(h.high)} / ${fmtPrice(h.low)}'),
          _kv('Fiyat değişimi', '${pchg >= 0 ? '+' : ''}${pchg.toStringAsFixed(2)}%'),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: kTextDim)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );

  List<Widget> _liveBody(WhaleLive l) {
    if (l.trades.isEmpty) {
      return [const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Bu eşiğin üzerinde işlem bulunamadı.\nDaha düşük bir eşik dene.', textAlign: TextAlign.center, style: TextStyle(color: kTextDim))))];
    }
    return [
      _summary('BÜYÜK İŞLEMLER — Eşik ${whaleFmt(_thresh)}+', l.buyPct,
          'Alım ${l.buyCount} işlem (${whaleFmt(l.buyVol)}) · Satım ${l.sellCount} işlem (${whaleFmt(l.sellVol)})'),
      const SizedBox(height: 6),
      for (final t in l.trades)
        Card(
          child: ListTile(
            dense: true,
            title: Text('${t.isBuy ? '🟢 ALIM' : '🔴 SATIM'}${t.value >= _thresh * 5 ? ' 🐋' : ''}',
                style: TextStyle(color: t.isBuy ? kUp : kDown, fontWeight: FontWeight.w900)),
            subtitle: Text('${fmtPrice(t.price)} · ${whaleTimeAgo(t.time)}', style: const TextStyle(color: kTextDim, fontSize: 11)),
            trailing: Text(whaleFmt(t.value), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
    ];
  }
}
