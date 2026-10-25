import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/nabiz_service.dart';
import '../widgets/coin_search.dart';

const _kWarn = Color(0xFFFBBF24);

String _fmtUsd(double n) {
  if (n >= 1e9) return '\$${(n / 1e9).toStringAsFixed(2)}B';
  if (n >= 1e6) return '\$${(n / 1e6).toStringAsFixed(2)}M';
  if (n >= 1e3) return '\$${(n / 1e3).toStringAsFixed(1)}K';
  return '\$${n.toStringAsFixed(0)}';
}

String _two(int n) => n.toString().padLeft(2, '0');

class NabizPage extends StatefulWidget {
  const NabizPage({super.key});
  @override
  State<NabizPage> createState() => _NabizPageState();
}

class _NabizPageState extends State<NabizPage> {
  String _input = 'BTC';
  bool _loading = false;
  String? _error;
  NabizResult? _res;
  Timer? _tick;

  String get _symbol => _input.endsWith('USDT') ? _input : '${_input}USDT';

  @override
  void initState() {
    super.initState();
    // Sonraki funding geri sayımı için her saniye yenile
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _res?.fundingPct != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    if (_input.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await NabizService.run(_symbol);
      if (mounted) setState(() { _res = r; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e'.replaceFirst('Exception: ', '');
          _res = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Piyasa Nabzı'), leading: BackButton(onPressed: () => context.go('/more'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Seçilen coin için Funding Rate, Açık Pozisyonlar ve Long/Short oranlarını analiz eder.\n⚠️ Yalnızca bilgi amaçlıdır. Yatırım tavsiyesi değildir.',
              style: TextStyle(color: kTextDim, fontSize: 12, height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        CoinSearch(
          initial: 'BTC',
          onChanged: (v) => _input = v,
          onSubmit: (s) {
            _input = s;
            _run();
          },
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: _loading ? null : _run, child: const Text('📡 PİYASA NABZINI OKU')),
        const SizedBox(height: 12),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        if (_error != null)
          Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('⚠️ $_error', style: const TextStyle(color: kDown)))),
        if (!_loading && _res != null) ..._body(_res!),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: kTextDim)),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );

  Widget _tip(String text, {Color color = _kWarn}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, height: 1.5)),
      );

  List<Widget> _body(NabizResult r) {
    final name = r.symbol.replaceAll('USDT', '');
    final out = <Widget>[];

    // ---- FUNDING ----
    if (r.fundingPct != null) {
      final fr = r.fundingPct!;
      final c = fr > 0.05 ? kDown : fr < -0.05 ? kUp : _kWarn;
      final sign = fr >= 0 ? '+' : '';
      final durum = fr > 0.05 ? 'LONGLAR FAZLA' : fr < -0.05 ? "SHORT'LAR FAZLA" : 'DENGELİ';
      final yorum = fr > 0.1
          ? "🔴 Çok yüksek — piyasa aşırı iyimser. Longlar short'lara ödüyor. Düzeltme riski yüksek."
          : fr > 0.03
              ? '🟡 Pozitif — longlar hafif baskıda. Dikkatli ol.'
              : fr < -0.1
                  ? "🟢 Çok negatif — piyasa aşırı kötümser. Short'lar ödüyor. Sıçrama riski var."
                  : fr < -0.03
                      ? "🟡 Negatif — short'lar hafif baskıda."
                      : '⚪ Nötr — piyasa dengeli, belirgin yön yok.';
      final now = DateTime.now().millisecondsSinceEpoch;
      const h8 = 8 * 3600000;
      final diff = ((now / h8).ceil() * h8) - now;
      final cd = '${_two(diff ~/ 3600000)}:${_two((diff % 3600000) ~/ 60000)}:${_two((diff % 60000) ~/ 1000)}';
      final barPct = ((fr + 0.15) / 0.30).clamp(0.0, 1.0);

      out.add(_section('💰 FUNDING RATE — $name/USDT', [
        const Text('8 SAATLİK ORAN', style: TextStyle(fontSize: 9, color: kTextDim)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$sign${fr.toStringAsFixed(4)}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: c)),
            child: Text('⚠ $durum', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Yıllık eşdeğer: ~$sign${(fr * 3 * 365).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, color: kTextDim)),
        const SizedBox(height: 12),
        const Text('PİYASA ISISI', style: TextStyle(fontSize: 9, color: kTextDim)),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (ctx, cons) {
          final w = cons.maxWidth;
          return SizedBox(
            height: 16,
            child: Stack(children: [
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(colors: [kUp, _kWarn, kDown]),
                  ),
                ),
              ),
              Positioned(
                left: (w * barPct - 7).clamp(0.0, w - 14),
                top: 1,
                child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black54, width: 2))),
              ),
            ]),
          );
        }),
        const SizedBox(height: 4),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('🐻 Short', style: TextStyle(fontSize: 9, color: kTextDim)),
          Text('⚖ Nötr', style: TextStyle(fontSize: 9, color: kTextDim)),
          Text('🐂 Long', style: TextStyle(fontSize: 9, color: kTextDim)),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Sonraki funding: $cd', style: const TextStyle(color: _kWarn, fontWeight: FontWeight.w800, fontSize: 12)),
          const Text('Her 8 saatte bir', style: TextStyle(fontSize: 9, color: kTextDim)),
        ]),
        _tip('💡 $yorum'),
      ]));
    } else {
      out.add(_note('Funding rate verisi alınamadı', kDown));
    }

    // ---- OPEN INTEREST ----
    if (r.oiUsdt != null) {
      final up = r.chg24 >= 0;
      final cc = up ? kUp : kDown;
      final sign = up ? '+' : '';
      late final String baslik, aciklama;
      late final Color yc;
      late final String icon;
      if (r.chg24 > 1) {
        baslik = 'GÜÇLENİYOR';
        aciklama = 'Fiyat artarken OI de artıyor → yeni long pozisyonlar açılıyor. Yükseliş trendi güçlü.';
        yc = kUp;
        icon = '📈';
      } else if (r.chg24 < -1) {
        baslik = 'POZİSYONLAR KAPANIYOR';
        aciklama = 'Fiyat düşerken OI de düşüyor → satış baskısı altında pozisyonlar kapanıyor.';
        yc = kDown;
        icon = '📉';
      } else {
        baslik = 'KARARSIZ';
        aciklama = 'Fiyat ve OI dengeli seyrediyor. Belirgin bir yön baskısı yok.';
        yc = _kWarn;
        icon = '⚖️';
      }
      out.add(_section('📊 OPEN INTEREST — Açık Pozisyonlar', [
        Row(children: [
          _stat('TOPLAM OI', _fmtUsd(r.oiUsdt!), kAccent),
          const SizedBox(width: 8),
          _stat('24S DEĞİŞİM', '$sign${r.chg24.toStringAsFixed(1)}%', cc),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _stat('FİYAT', fmtPrice(r.price), kText),
          const SizedBox(width: 8),
          _stat('YORUM', baslik, yc, small: true),
        ]),
        _tip('$icon  $aciklama', color: yc),
        _tip('💡 OI artar + fiyat artar → güçlü yükseliş\nOI düşer + fiyat düşer → pozisyonlar kapanıyor\nOI artar + fiyat düşer → short baskısı artıyor'),
      ]));
    }

    // ---- LONG / SHORT ----
    if (r.allLong != null || r.topLong != null) {
      String yorum = '';
      if (r.topLong != null && r.allLong != null) {
        if (r.topLong! > r.allLong! + 5) {
          yorum = '💡 Perakende short yapıyor ama büyük oyuncular long tutuyor. Genellikle büyük oyuncular kazanır — ilginç ayrışma!';
        } else if (r.topShort! > r.allShort! + 5) {
          yorum = '💡 Perakende long yapıyor ama büyük oyuncular short tutuyor. Büyük oyuncuların yönüne dikkat et.';
        } else if (r.allLong! > 60) {
          yorum = '💡 Perakende aşırı long — kalabalık pozisyon, likidite tuzağı riski olabilir.';
        } else if (r.allShort! > 60) {
          yorum = '💡 Perakende aşırı short — short sıkışması (squeeze) riski var.';
        } else {
          yorum = '💡 Piyasa dengeli — belirgin bir ayrışma yok, her iki yönde de risk var.';
        }
      }
      out.add(_section('✖ BÜYÜK OYUNCU POZİSYONLARI', [
        if (r.allLong != null) _lsBar('TÜM HESAPLAR', r.allLong!, r.allShort!),
        if (r.topLong != null) _lsBar('BÜYÜK OYUNCULAR', r.topLong!, r.topShort!),
        if (yorum.isNotEmpty) _tip(yorum),
      ]));
    }

    // ---- LİKİDASYON ----
    if (r.liqs.isNotEmpty) {
      final total = r.liqs.fold<double>(0, (s, l) => s + l.value);
      final shortT = r.liqs.where((l) => l.isShortLiq).fold<double>(0, (s, l) => s + l.value);
      final longT = r.liqs.where((l) => !l.isShortLiq).fold<double>(0, (s, l) => s + l.value);
      out.add(_section('💥 LİKİDASYONLAR — Son İşlemler', [
        Row(children: [
          _stat('TOPLAM', _fmtUsd(total), kAccent),
          const SizedBox(width: 8),
          _stat('SHORT LİKİT', _fmtUsd(shortT), kUp),
          const SizedBox(width: 8),
          _stat('LONG LİKİT', _fmtUsd(longT), kDown),
        ]),
        const SizedBox(height: 10),
        for (final l in r.liqs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 60, child: Text('${_two(l.time.hour)}:${_two(l.time.minute)}', style: const TextStyle(fontSize: 10, color: kTextDim))),
              Expanded(child: Text(l.isShortLiq ? 'SHORT LİKİT' : 'LONG LİKİT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: l.isShortLiq ? kUp : kDown))),
              Text(_fmtUsd(l.value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            ]),
          ),
        _tip('💡 Long likit = fiyat hızla düştü, alıcılar tasfiye edildi.\nShort likit = fiyat hızla çıktı, satıcılar tasfiye edildi.'),
      ]));
    } else {
      out.add(_note('Son 1 saatte büyük likidasyon yok', kTextDim));
    }

    out.add(Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Son güncelleme: ${_two(r.fetchedAt.hour)}:${_two(r.fetchedAt.minute)}:${_two(r.fetchedAt.second)}', style: const TextStyle(fontSize: 9, color: kTextDim)),
      ),
    ));
    out.add(OutlinedButton(onPressed: _loading ? null : _run, child: const Text('🔄 YENİLE')));
    out.add(const SizedBox(height: 24));
    return out;
  }

  Widget _note(String t, Color c) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.2))),
        child: Text(t, textAlign: TextAlign.center, style: TextStyle(color: c, fontSize: 11)),
      );

  Widget _stat(String label, String value, Color c, {bool small = false}) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 8, color: kTextDim, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: small ? 11 : 14, fontWeight: FontWeight.w900, color: c)),
          ]),
        ),
      );

  Widget _lsBar(String label, double l, double s) {
    final longDom = l > s;
    final c = longDom ? kUp : kDown;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 9, color: kTextDim, letterSpacing: 1)),
          Text('Long %${l.toStringAsFixed(1)} / Short %${s.toStringAsFixed(1)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              Expanded(flex: (l * 10).round().clamp(1, 999), child: Container(color: kUp)),
              Expanded(flex: (s * 10).round().clamp(1, 999), child: Container(color: kDown)),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(longDom ? '● Long Ağırlıklı' : '● Short Baskısı', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c)),
        ),
      ]),
    );
  }
}
