import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../services/scanner_service.dart';

String _fmtV(double v) => v >= 1e9
    ? '\$${(v / 1e9).toStringAsFixed(2)}B'
    : v >= 1e6
        ? '\$${(v / 1e6).toStringAsFixed(1)}M'
        : '\$${(v / 1e3).toStringAsFixed(0)}K';

class HacimPage extends StatefulWidget {
  const HacimPage({super.key});
  @override
  State<HacimPage> createState() => _HacimPageState();
}

class _HacimPageState extends State<HacimPage> {
  bool _loading = false;
  String _progress = '';
  String? _error;
  List<VolItem>? _items;

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _items = null; _progress = 'Veri alınıyor...'; });
    try {
      final r = await volumeScan(onProgress: (s) {
        if (mounted) setState(() => _progress = s);
      });
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'Veri alınamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hacim Tarayıcı'), leading: BackButton(onPressed: () => context.go('/more'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          FilledButton(onPressed: _loading ? null : _run, child: const Text('TARA')),
          const SizedBox(height: 12),
          if (_loading)
            Column(children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(_progress, style: const TextStyle(color: kTextDim, fontSize: 12)),
            ]),
          if (_error != null) Center(child: Text(_error!, style: const TextStyle(color: kDown))),
          if (_items != null)
            for (var i = 0; i < _items!.length; i++) _tile(i, _items![i]),
        ],
      ),
    );
  }

  Widget _tile(int idx, VolItem it) {
    final up = it.change >= 0;
    final cc = up ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final fire = idx < 3 ? '🔥🔥🔥' : idx < 8 ? '🔥🔥' : '🔥';
    final buy = it.buyPct;
    String? yorum;
    Color yc = kTextDim;
    if (buy != null) {
      if (buy >= 55) {
        yorum = 'Alıcılar baskın — yükseliş güçlü';
        yc = const Color(0xFF86EFAC);
      } else if (100 - buy >= 55) {
        yorum = 'Satıcılar baskın — düşüş güçlü, dikkat';
        yc = const Color(0xFFFCA5A5);
      } else {
        yorum = 'Denge — net yön yok';
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$fire ${it.symbol.replaceAll('USDT', '')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            Text('${up ? '▲ +' : '▼ '}${it.change.toStringAsFixed(2)}%', style: TextStyle(color: cc, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text('24s hacim: ${_fmtV(it.vol24)}  ·  ${it.count} işlem', style: const TextStyle(color: kTextDim, fontSize: 11)),
          if (buy != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(children: [
                  Expanded(flex: (buy * 10).round().clamp(1, 999), child: Container(color: kUp)),
                  Expanded(flex: ((100 - buy) * 10).round().clamp(1, 999), child: Container(color: kDown)),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('%${buy.toStringAsFixed(1)} Alış', style: const TextStyle(color: kUp, fontSize: 10)),
              Text('%${(100 - buy).toStringAsFixed(1)} Satış', style: const TextStyle(color: kDown, fontSize: 10)),
            ]),
            const SizedBox(height: 4),
            Text(yorum!, style: TextStyle(color: yc, fontSize: 11)),
          ],
        ]),
      ),
    );
  }
}
