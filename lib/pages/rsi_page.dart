import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/scanner_service.dart';

class RsiPage extends StatefulWidget {
  const RsiPage({super.key});
  @override
  State<RsiPage> createState() => _RsiPageState();
}

class _RsiPageState extends State<RsiPage> {
  String _interval = '1h';
  String _mode = 'both';
  bool _loading = false;
  String _progress = '';
  String? _error;
  List<RsiHit>? _hits;

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _hits = null; });
    try {
      final h = await rsiScan(_interval, _mode, onProgress: (s) {
        if (mounted) setState(() => _progress = s);
      });
      if (mounted) setState(() => _hits = h);
    } catch (e) {
      if (mounted) setState(() => _error = 'Veri alınamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RSI Tarayıcı'), leading: BackButton(onPressed: () => context.go('/more'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _interval,
                decoration: const InputDecoration(labelText: 'Zaman dilimi', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: '1h', child: Text('1 Saat')),
                  DropdownMenuItem(value: '4h', child: Text('4 Saat')),
                  DropdownMenuItem(value: '1d', child: Text('1 Gün')),
                ],
                onChanged: (v) => setState(() => _interval = v!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _mode,
                decoration: const InputDecoration(labelText: 'Mod', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'both', child: Text('İkisi')),
                  DropdownMenuItem(value: 'oversold', child: Text('Aşırı satım')),
                  DropdownMenuItem(value: 'overbought', child: Text('Aşırı alım')),
                ],
                onChanged: (v) => setState(() => _mode = v!),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          FilledButton(onPressed: _loading ? null : _run, child: const Text('TARA')),
          const SizedBox(height: 12),
          if (_loading)
            Column(children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(_progress, style: const TextStyle(color: kTextDim, fontSize: 12)),
            ]),
          if (_error != null) Center(child: Text(_error!, style: const TextStyle(color: kDown))),
          if (_hits != null && _hits!.isEmpty)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Eşleşen coin bulunamadı', style: TextStyle(color: kTextDim)))),
          if (_hits != null)
            for (final h in _hits!) _tile(h),
        ],
      ),
    );
  }

  Widget _tile(RsiHit h) {
    final c = h.oversold ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final cc = h.change >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    return Card(
      color: c.withOpacity(0.08),
      child: ListTile(
        title: Text(h.symbol.replaceAll('USDT', ''), style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          h.oversold ? '🟢 AŞIRI SATIM — dönüş potansiyeli' : '🔴 AŞIRI ALIM — düzeltme olabilir',
          style: TextStyle(color: c, fontSize: 11),
        ),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('RSI ${h.rsi.toStringAsFixed(1)}', style: TextStyle(color: c, fontWeight: FontWeight.w900)),
          Text('${h.change >= 0 ? '+' : ''}${h.change.toStringAsFixed(2)}%', style: TextStyle(color: cc, fontSize: 11)),
        ]),
      ),
    );
  }
}
