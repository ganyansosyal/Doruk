import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../services/takvim_data.dart';

Color _tipRenk(String t) => t == 'resmi' ? const Color(0xFF00D4FF) : t == 'dini' ? const Color(0xFFC05AC8) : const Color(0xFFF59E0B);
String _tipRozet(String t) => t == 'resmi' ? 'RESMİ TATİL' : t == 'dini' ? 'DİNİ BAYRAM' : 'ÖNEMLİ GÜN';

class TakvimPage extends StatefulWidget {
  const TakvimPage({super.key});
  @override
  State<TakvimPage> createState() => _TakvimPageState();
}

class _TakvimPageState extends State<TakvimPage> {
  int _yil = DateTime.now().year;
  int _ay = DateTime.now().month - 1;
  int? _secili;

  void _degistir(int d) {
    setState(() {
      _ay += d;
      if (_ay > 11) { _ay = 0; _yil++; }
      if (_ay < 0) { _ay = 11; _yil--; }
      _secili = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    final ilk = DateTime(_yil, _ay + 1, 1).weekday; // 1=Pzt
    final bosluk = ilk - 1;
    final ayGun = DateTime(_yil, _ay + 2, 0).day;

    final cells = <Widget>[for (var i = 0; i < bosluk; i++) const SizedBox()];
    for (var g = 1; g <= ayGun; g++) {
      final et = takvimEtkinlikler(g, _ay, _yil);
      String? tip;
      for (final t in ['resmi', 'dini', 'onemli']) {
        if (et.any((e) => e.tip == t)) { tip = t; break; }
      }
      final isBugun = bugun.day == g && bugun.month == _ay + 1 && bugun.year == _yil;
      final isSecili = _secili == g;
      final hs = DateTime(_yil, _ay + 1, g).weekday >= 6;
      Color? bg;
      Color fg = hs ? const Color(0xFFEF4444) : const Color(0xFFC8D8F0);
      if (tip != null) { bg = _tipRenk(tip); fg = Colors.white; }
      if (isSecili) { bg = tip != null ? _tipRenk(tip) : const Color(0xCCA855F7); fg = Colors.white; }
      if (isBugun && bg == null) { bg = kAccent; fg = const Color(0xFF050C18); }
      cells.add(GestureDetector(
        onTap: () => setState(() => _secili = _secili == g ? null : g),
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: isBugun && bg != null ? Border.all(color: Colors.white, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text('$g', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ),
      ));
    }

    final ayEtkinlik = <TakEtkinlik>[for (var g = 1; g <= ayGun; g++) ...takvimEtkinlikler(g, _ay, _yil)];
    final yaklasan = yaklasanGunler();

    return Scaffold(
      appBar: AppBar(title: const Text('Takvim'), leading: BackButton(onPressed: () => context.go('/more'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(onPressed: () => _degistir(-1), icon: const Icon(Icons.chevron_left)),
          Text('${takvimAylar[_ay]} $_yil', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          IconButton(onPressed: () => _degistir(1), icon: const Icon(Icons.chevron_right)),
        ]),
        Row(children: [
          for (final g in const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'])
            Expanded(child: Center(child: Text(g, style: const TextStyle(color: kTextDim, fontSize: 11, fontWeight: FontWeight.w800)))),
        ]),
        const SizedBox(height: 6),
        GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1, children: cells),
        if (_secili != null) _gunDetay(_secili!),
        _title('BU AYIN ETKİNLİKLERİ'),
        if (ayEtkinlik.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Bu ay için kayıtlı etkinlik yok.', style: TextStyle(color: kTextDim)))),
        for (final g in List.generate(ayGun, (i) => i + 1))
          for (final e in takvimEtkinlikler(g, _ay, _yil)) _row(e, '$g ${takvimAylar[_ay]}'),
        _title('YAKLAŞAN GÜNLER'),
        if (yaklasan.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Yaklaşan özel gün yok.', style: TextStyle(color: kTextDim)))),
        for (final t in yaklasan)
          _row(t, '${t.gun} ${takvimAylar[t.ay]}', kalan: t.tarih!.difference(DateTime.now()).inHours ~/ 24 + 1),
      ]),
    );
  }

  Widget _gunDetay(int g) {
    final tarih = DateTime(_yil, _ay + 1, g);
    final et = takvimEtkinlikler(g, _ay, _yil);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$g ${takvimAylar[_ay]} $_yil · ${takvimGunler[tarih.weekday - 1]}', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (et.isEmpty) const Text('Bu gün için özel bir etkinlik yok.', style: TextStyle(color: kTextDim)),
          for (final e in et) _row(e, null, plain: true),
        ]),
      ),
    );
  }

  Widget _row(TakEtkinlik e, String? tarih, {int? kalan, bool plain = false}) {
    final c = _tipRenk(e.tip);
    final child = Row(children: [
      Text(e.emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.ad, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          if (tarih != null) Text(tarih, style: const TextStyle(color: kTextDim, fontSize: 11)),
        ]),
      ),
      if (kalan != null) Padding(padding: const EdgeInsets.only(right: 8), child: Text('$kalan gün', style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withOpacity(0.4))),
        child: Text(_tipRozet(e.tip), style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w900)),
      ),
    ]);
    if (plain) return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: child);
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: child));
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kTextDim, letterSpacing: 1)),
      );
}
