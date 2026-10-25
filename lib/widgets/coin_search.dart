import 'dart:async';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/binance_service.dart';

/// Ortak coin arama kutusu (Fibo, Sinyal, Whale, Nabız...)
/// onChanged: yazılan/seçilen metin (örn. "BTC")
/// onSubmit : listeden seçilince veya klavyede "ara"ya basılınca tam sembol (örn. "BTCUSDT")
class CoinSearch extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final double minVolume;
  const CoinSearch({
    super.key,
    this.initial = '',
    required this.onChanged,
    required this.onSubmit,
    this.minVolume = 500000,
  });
  @override
  State<CoinSearch> createState() => _CoinSearchState();
}

class _CoinSearchState extends State<CoinSearch> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial);
  Timer? _debounce;
  List<Ticker> _all = [];
  List<Ticker> _suggest = [];

  static bool _lev(String s) => s.contains('UP') || s.contains('DOWN') || s.contains('BEAR') || s.contains('BULL');

  @override
  void initState() {
    super.initState();
    BinanceService.tickers24h().then((l) {
      if (mounted) setState(() => _all = l.where((t) => t.quoteVolume > widget.minVolume && !_lev(t.symbol)).toList());
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String _sym(String t) {
    final u = t.trim().toUpperCase();
    return u.endsWith('USDT') ? u : '${u}USDT';
  }

  void _onChanged(String v) {
    widget.onChanged(v.trim().toUpperCase());
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() => _suggest = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () {
      final q = v.trim().toUpperCase();
      final f = _all.where((t) => t.symbol.replaceAll('USDT', '').contains(q)).toList()
        ..sort((a, b) {
          final x = a.symbol.startsWith(q), y = b.symbol.startsWith(q);
          return x == y ? 0 : (x ? -1 : 1);
        });
      if (mounted) setState(() => _suggest = f.take(6).toList());
    });
  }

  void _pick(Ticker t) {
    FocusScope.of(context).unfocus();
    final name = t.symbol.replaceAll('USDT', '');
    _ctrl.text = name;
    setState(() => _suggest = []);
    widget.onChanged(name);
    widget.onSubmit(t.symbol);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: _ctrl,
        onChanged: _onChanged,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          setState(() => _suggest = []);
          if (v.trim().isNotEmpty) widget.onSubmit(_sym(v));
        },
        decoration: InputDecoration(
          hintText: 'Coin ara (BTC, ETH...)',
          prefixIcon: const Icon(Icons.search),
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
                onTap: () => _pick(t),
                title: Text(t.symbol.replaceAll('USDT', '')),
                subtitle: Text('Vol \$${fmtVol(t.quoteVolume)}', style: const TextStyle(color: kTextDim, fontSize: 11)),
                trailing: Text('${t.changePct >= 0 ? '+' : ''}${t.changePct.toStringAsFixed(2)}%',
                    style: TextStyle(color: t.changePct >= 0 ? kUp : kDown, fontWeight: FontWeight.w800)),
              ),
          ]),
        ),
    ]);
  }
}
