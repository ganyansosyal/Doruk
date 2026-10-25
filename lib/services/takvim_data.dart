class TakEtkinlik {
  final int gun, ay; // ay: 0-11
  final String ad, emoji, tip; // tip: resmi | dini | onemli
  final DateTime? tarih;
  const TakEtkinlik(this.gun, this.ay, this.ad, this.emoji, this.tip, [this.tarih]);
}

const takvimAylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const takvimGunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar']; // weekday-1

const _sabit = <TakEtkinlik>[
  TakEtkinlik(1, 0, 'Yılbaşı', '🎆', 'resmi'),
  TakEtkinlik(14, 1, 'Sevgililer Günü', '❤️', 'onemli'),
  TakEtkinlik(8, 2, 'Dünya Kadınlar Günü', '💜', 'onemli'),
  TakEtkinlik(21, 2, 'Nevruz', '🌸', 'onemli'),
  TakEtkinlik(23, 3, 'Ulusal Egemenlik ve Çocuk Bayramı', '🎈', 'resmi'),
  TakEtkinlik(23, 3, 'Dünya Kitap Günü', '📚', 'onemli'),
  TakEtkinlik(1, 4, 'Emek ve Dayanışma Günü', '✊', 'resmi'),
  TakEtkinlik(19, 4, 'Gençlik ve Spor Bayramı', '🏃', 'resmi'),
  TakEtkinlik(5, 4, 'Dünya Çevre Günü', '🌍', 'onemli'),
  TakEtkinlik(15, 6, 'Demokrasi ve Millî Birlik Günü', '🇹🇷', 'resmi'),
  TakEtkinlik(30, 7, 'Zafer Bayramı', '🏆', 'resmi'),
  TakEtkinlik(29, 9, 'Cumhuriyet Bayramı', '🎉', 'resmi'),
  TakEtkinlik(31, 9, 'Dünya Tasarruf Günü', '💰', 'onemli'),
  TakEtkinlik(10, 10, "Atatürk'ü Anma Günü", '🕯️', 'onemli'),
  TakEtkinlik(20, 10, 'Dünya Çocuk Günü', '🎠', 'onemli'),
  TakEtkinlik(24, 10, 'Öğretmenler Günü', '🍎', 'onemli'),
  TakEtkinlik(31, 11, 'Yılbaşı Arifesi', '🎄', 'onemli'),
];

List<TakEtkinlik> _dinamik(int yil) {
  final r = <TakEtkinlik>[];
  var sayac = 0;
  for (var i = 1; i <= 31; i++) {
    if (DateTime(yil, 5, i).weekday == DateTime.sunday) {
      sayac++;
      if (sayac == 2) {
        r.add(TakEtkinlik(i, 4, 'Anneler Günü', '🌹', 'onemli'));
        break;
      }
    }
  }
  sayac = 0;
  for (var i = 1; i <= 30; i++) {
    if (DateTime(yil, 6, i).weekday == DateTime.sunday) {
      sayac++;
      if (sayac == 3) {
        r.add(TakEtkinlik(i, 5, 'Babalar Günü', '👔', 'onemli'));
        break;
      }
    }
  }
  return r;
}

List<TakEtkinlik> diniBayramlar(int yil) {
  const hicriGun = 354.36667;
  final fark = ((yil - 2024) * hicriGun).round();
  final ramazan = DateTime(2024, 4, 10 + fark);
  final kurban = DateTime(2024, 6, 17 + fark);
  final r = <TakEtkinlik>[];
  const re = ['Ramazan Arefe', 'Ramazan Bayramı 1.Gün', 'Ramazan Bayramı 2.Gün', 'Ramazan Bayramı 3.Gün'];
  for (var i = -1; i <= 2; i++) {
    final d = DateTime(ramazan.year, ramazan.month, ramazan.day + i);
    r.add(TakEtkinlik(d.day, d.month - 1, re[i + 1], '🌙', 'dini', d));
  }
  const ke = ['Kurban Arefe', 'Kurban Bayramı 1.Gün', 'Kurban Bayramı 2.Gün', 'Kurban Bayramı 3.Gün', 'Kurban Bayramı 4.Gün'];
  for (var i = -1; i <= 3; i++) {
    final d = DateTime(kurban.year, kurban.month, kurban.day + i);
    r.add(TakEtkinlik(d.day, d.month - 1, ke[i + 1], '🐑', 'dini', d));
  }
  return r;
}

List<TakEtkinlik> takvimEtkinlikler(int gun, int ay, int yil) => [
      ..._sabit.where((e) => e.gun == gun && e.ay == ay),
      ..._dinamik(yil).where((e) => e.gun == gun && e.ay == ay),
      ...diniBayramlar(yil).where((e) => e.gun == gun && e.ay == ay),
    ];

/// Önümüzdeki 90 gündeki yaklaşan günler (en fazla 7)
List<TakEtkinlik> yaklasanGunler() {
  final simdi = DateTime.now();
  final sinir = simdi.add(const Duration(days: 90));
  final liste = <TakEtkinlik>[];
  for (var y = simdi.year; y <= simdi.year + 1; y++) {
    for (final o in [..._sabit, ..._dinamik(y)]) {
      final d = DateTime(y, o.ay + 1, o.gun);
      if (d.isAfter(simdi) && !d.isAfter(sinir)) liste.add(TakEtkinlik(o.gun, o.ay, o.ad, o.emoji, o.tip, d));
    }
    for (final t in diniBayramlar(y)) {
      if (t.tarih!.isAfter(simdi) && !t.tarih!.isAfter(sinir)) liste.add(t);
    }
  }
  liste.sort((a, b) => a.tarih!.compareTo(b.tarih!));
  final goruldu = <String>{};
  return liste.where((t) => goruldu.add('${t.tarih}${t.ad}')).take(7).toList();
}
