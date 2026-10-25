import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../services/ceviri_service.dart';

class CeviriPage extends StatefulWidget {
  const CeviriPage({super.key});
  @override
  State<CeviriPage> createState() => _CeviriPageState();
}

class _CeviriPageState extends State<CeviriPage> {
  final _ctrl = TextEditingController();
  Dil _src = ceviriDiller[0];
  Dil _tgt = ceviriDiller[1];
  bool _loading = false;
  String _sonuc = '';
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cevir() async {
    final m = _ctrl.text.trim();
    if (m.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ceviriYap(m, _src, _tgt);
      if (mounted) setState(() => _sonuc = r);
    } catch (e) {
      if (mounted) setState(() { _error = 'Bağlantı hatası: $e'; _sonuc = ''; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _swap() {
    setState(() {
      final t = _src;
      _src = _tgt;
      _tgt = t;
      if (_sonuc.isNotEmpty) {
        _ctrl.text = _sonuc;
        _sonuc = '';
      }
    });
  }

  void _pick(bool isSrc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(12), children: [
          for (final d in ceviriDiller)
            ListTile(
              leading: Text(d.flag, style: const TextStyle(fontSize: 24)),
              title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () {
                setState(() => isSrc ? _src = d : _tgt = d);
                Navigator.pop(context);
              },
            ),
        ]),
      ),
    );
  }

  Widget _langBtn(Dil d, bool isSrc) => Expanded(
        child: OutlinedButton(
          onPressed: () => _pick(isSrc),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Column(children: [
            Text(d.flag, style: const TextStyle(fontSize: 22)),
            Text(d.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Çeviri'), leading: BackButton(onPressed: () => context.go('/more'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          _langBtn(_src, true),
          IconButton(onPressed: _swap, icon: const Icon(Icons.swap_horiz, color: kAccent)),
          _langBtn(_tgt, false),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          maxLines: 6,
          maxLength: 5000,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Çevirmek istediğiniz metni yazın...',
            filled: true,
            fillColor: kCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _loading ? null : _cevir, child: Text(_loading ? '⟳ Çevriliyor...' : '⚡ ÇEVİR')),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _error ?? (_sonuc.isEmpty ? 'Metin girin ve Çevir butonuna basın.' : _sonuc),
                style: TextStyle(fontSize: 16, color: _error != null ? kDown : (_sonuc.isEmpty ? kTextDim : kText)),
              ),
              if (_sonuc.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${_sonuc.length} karakter', style: const TextStyle(color: kTextDim, fontSize: 11)),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _sonuc));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kopyalandı')));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Kopyala'),
                  ),
                ]),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
