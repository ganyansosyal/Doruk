import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/binance_service.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});
  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  List<Ticker> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await BinanceService.tickers24h();
      if (mounted) setState(() { _items = t.take(100).toList(); _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) return Center(child: Text('Hata: $_error'));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final t = _items[i];
        final up = t.changePct >= 0;
        return Card(
          child: ListTile(
            title: Text(t.symbol.replaceAll('USDT', ''), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('USDT', style: TextStyle(color: kTextDim)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(t.price < 1 ? t.price.toStringAsFixed(6) : t.price.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${up ? '+' : ''}${t.changePct.toStringAsFixed(2)}%',
                    style: TextStyle(color: up ? kUp : kDown, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
