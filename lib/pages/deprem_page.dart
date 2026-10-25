import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../services/deprem_service.dart';

class DepremPage extends StatefulWidget {
  const DepremPage({super.key});
  @override
  State<DepremPage> createState() => _DepremPageState();
}

class _DepremPageState extends State<DepremPage> {
  List<Quake> _data = [];
  bool _loading = true;
  String? _error;
  double _min = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await depremYukle();
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Veri alınamadı: $e'; _loading = false; });
    }
  }

  void _detail(Quake q) {
    final sev = depremSev(q.mag);
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('M${q.mag.toStringAsFixed(1)} — ${sev.label}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(sev.color))),
          const SizedBox(height: 8),
          Text(q.loc, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _kv('Tarih', depremTarihSaat(q.date).isEmpty ? '—' : depremTarihSaat(q.date)),
          _kv('Geçen süre', depremZamanFark(q.date)),
          _kv('Derinlik', '${q.depth} km'),
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

  Widget _stat(String t, String v) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kAccent)),
              Text(t, style: const TextStyle(fontSize: 10, color: kTextDim)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final filtered = _data.where((q) => q.mag >= _min).toList();
    final maxMag = _data.isEmpty ? '—' : _data.map((q) => q.mag).reduce((a, b) => a > b ? a : b).toStringAsFixed(1);
    final m4 = _data.where((q) => q.mag >= 4.0).length;
    final big = _data.where((q) => q.mag >= 3.0).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deprem'),
        leading: BackButton(onPressed: () => context.go('/more')),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (_loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: kDown)))),
          if (!_loading && _error == null) ...[
            Row(children: [
              _stat('TOPLAM', '${_data.length}'),
              _stat('EN BÜYÜK', maxMag),
              _stat('M4+', '$m4'),
            ]),
            if (big.isNotEmpty) _alert(big.first),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              for (final e in const {0.0: 'Hepsi', 2.0: 'M2+', 3.0: 'M3+', 4.0: 'M4+', 5.0: 'M5+'}.entries)
                ChoiceChip(label: Text(e.value), selected: _min == e.key, onSelected: (_) => setState(() => _min = e.key)),
            ]),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Bu filtre için deprem bulunamadı.', style: TextStyle(color: kTextDim)))),
            for (final q in filtered.take(200)) _tile(q),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('M3+ → son 7 gün, diğerleri → son 24 saat · Kaynak: Kandilli', textAlign: TextAlign.center, style: TextStyle(color: kTextDim, fontSize: 10)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _alert(Quake q) {
    final sev = depremSev(q.mag);
    final c = Color(sev.color);
    final baslik = q.mag >= 5.0 ? 'BÜYÜK DEPREM' : q.mag >= 4.0 ? 'DİKKAT — DEPREM' : 'DEPREM';
    return Card(
      color: c.withOpacity(0.10),
      child: ListTile(
        onTap: () => _detail(q),
        leading: Icon(Icons.warning_amber_rounded, color: c, size: 32),
        title: Text('$baslik · M${q.mag.toStringAsFixed(1)}', style: TextStyle(color: c, fontWeight: FontWeight.w900)),
        subtitle: Text('${q.loc}\n${depremZamanFark(q.date)}', style: const TextStyle(fontSize: 12)),
        isThreeLine: true,
      ),
    );
  }

  Widget _tile(Quake q) {
    final sev = depremSev(q.mag);
    final c = Color(sev.color);
    return Card(
      child: ListTile(
        onTap: () => _detail(q),
        leading: CircleAvatar(
          backgroundColor: c.withOpacity(0.18),
          child: Text(q.mag.toStringAsFixed(1), style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
        title: Text(q.loc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text('${sev.label} · ${q.depth} km · ${depremZamanFark(q.date)}', style: const TextStyle(color: kTextDim, fontSize: 11)),
      ),
    );
  }
}
