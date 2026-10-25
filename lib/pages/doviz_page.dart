import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/doviz_service.dart';

class DovizPage extends StatefulWidget {
  const DovizPage({super.key});
  @override
  State<DovizPage> createState() => _DovizPageState();
}

class _DovizPageState extends State<DovizPage> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;

  static const _keys = ['USD', 'EUR', 'GBP', 'CHF', 'JPY', 'gram-altin', 'ceyrek-altin', 'ons'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await DovizService.fetchToday();
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Hata: $_error'));
    final rows = _keys.where(_data.containsKey).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final k in rows)
            Card(
              child: ListTile(
                title: Text(k.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Alış: ${_data[k]['Alış'] ?? _data[k]['Alis'] ?? '-'}',
                    style: const TextStyle(color: kTextDim)),
                trailing: Text('${_data[k]['Satış'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}
