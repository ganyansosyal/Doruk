import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../core/firebase_init.dart';
import 'auth_service.dart';

/// Web'deki guest.js + rewards.js + core.js kredi mantığının karşılığı.
/// - Kayıtlı kullanıcı: kullanici_kredi/{key}  (ilk girişte 200)
/// - Misafir:           misafir_kredi/{key}    (ilk girişte 25)
/// - Korumalı bir sayfa her açıldığında 1 kredi düşer (Firebase transaction).
/// - Kayıtlı kullanıcı günde bir kez (TR saatiyle gün) +10 kredi alır.
class CreditService {
  static const int kayitliBaslangic = 200;
  static const int misafirBaslangic = 25;
  static const int gunlukHediye = 10;

  /// Web'deki _misafirKorunanlar listesi
  static const korunanlar = <String>{
    'analiz', 'notes', 'takvim', 'doviz', 'ceviri', 'deprem', 'sinyal', 'cuzdan',
    'futures', 'fibo', 'sentinel', 'whale', 'nabiz', 'rsi', 'hacim',
  };

  static final ValueNotifier<int> kredi = ValueNotifier<int>(0);
  static final ValueNotifier<bool> hediyeHazir = ValueNotifier<bool>(false);

  static DatabaseReference? _ref;
  static StreamSubscription<DatabaseEvent>? _sub;
  static StreamSubscription<DatabaseEvent>? _offsetSub;
  static int _offsetMs = 0;
  static Completer<void> _ilkVeri = Completer<void>();
  static bool _misafir = false;
  static String _key = '';

  /// main.dart'ta bir kez çağrılır: kullanıcı değişince servis kendini ayarlar.
  static void baslat() {
    AuthService.user.addListener(_kullaniciDegisti);
    _kullaniciDegisti();
  }

  static void _kullaniciDegisti() {
    final u = AuthService.user.value;
    if (u == null) {
      _durdur();
    } else {
      _ac(u, AuthService.misafir.value);
    }
  }

  static void _durdur() {
    _sub?.cancel();
    _offsetSub?.cancel();
    _sub = null;
    _offsetSub = null;
    _ref = null;
    _key = '';
    kredi.value = 0;
    hediyeHazir.value = false;
    _ilkVeri = Completer<void>();
  }

  static Future<void> _ac(String nick, bool misafir) async {
    _durdur();
    if (!firebaseReady) {
      if (!_ilkVeri.isCompleted) _ilkVeri.complete();
      return;
    }
    _misafir = misafir;
    _key = fbKey(nick);
    final r = db().ref('${misafir ? 'misafir_kredi' : 'kullanici_kredi'}/$_key');
    _ref = r;

    // Sunucu saati farkı: cihaz saatiyle hile yapılmasın
    _offsetSub = db().ref('.info/serverTimeOffset').onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num) _offsetMs = v.toInt();
    });

    // İlk girişte başlangıç kredisini yaz
    try {
      final snap = await r.get();
      if (!snap.exists) {
        await r.set({
          'kredi': misafir ? misafirBaslangic : kayitliBaslangic,
          'ilkGiris': ServerValue.timestamp,
        });
      }
    } catch (_) {}

    _sub = r.onValue.listen((e) {
      if (!e.snapshot.exists) return;
      final d = e.snapshot.value;
      final k = _krediOku(d);
      if (k != null) kredi.value = k;
      if (!misafir) _hediyeKontrol(d);
      if (!_ilkVeri.isCompleted) _ilkVeri.complete();
    }, onError: (_) {
      if (!_ilkVeri.isCompleted) _ilkVeri.complete();
    });
  }

  static int? _krediOku(Object? d) {
    if (d is Map) return int.tryParse('${d['kredi']}');
    return int.tryParse('$d');
  }

  static int get _simdi => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  /// Türkiye (UTC+3) saatine göre gün anahtarı
  static String _trGun(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts + 3 * 3600 * 1000, isUtc: true);
    return '${d.year}-${d.month}-${d.day}';
  }

  static void _hediyeKontrol(Object? d) {
    final son = (d is Map) ? (int.tryParse('${d['son_gunluk_hediye']}') ?? 0) : 0;
    final now = _simdi;
    if (son > 0 && son >= now) {
      hediyeHazir.value = false;
    } else {
      hediyeHazir.value = son == 0 || _trGun(son) != _trGun(now);
    }
  }

  /// Korumalı sayfa açılırken çağır. true = geçebilir, false = kredi yok.
  static Future<bool> harca() async {
    if (_ref == null) {
      // Firebase yok (çevrimdışı): web'deki gibi sadece yerelden düş
      if (kredi.value <= 0) return false;
      kredi.value = kredi.value - 1;
      return true;
    }
    // Dinleyici ilk veriyi getirene kadar bekle (en fazla 6 sn)
    await _ilkVeri.future.timeout(const Duration(seconds: 6), onTimeout: () {});
    if (kredi.value <= 0) return false;
    final onceki = kredi.value;
    kredi.value = onceki - 1; // iyimser güncelleme; dinleyici gerçeği düzeltir
    try {
      final res = await _ref!.runTransaction((cur) {
        if (cur == null) return Transaction.success(cur);
        final k = _krediOku(cur) ?? 0;
        if (k <= 0) return Transaction.abort();
        if (cur is Map) {
          final m = Map<String, dynamic>.from(cur);
          m['kredi'] = k - 1;
          m['guncelleme'] = DateTime.now().millisecondsSinceEpoch;
          return Transaction.success(m);
        }
        return Transaction.success(k - 1);
      });
      if (!res.committed) {
        kredi.value = onceki;
        return false;
      }
      return true;
    } catch (_) {
      // Ağ hatasında kullanıcıyı mağdur etme
      return true;
    }
  }

  /// Günlük hediyeyi al. Başarılıysa mesaj null, değilse hata metni döner.
  static Future<String?> hediyeAl() async {
    if (_misafir || _ref == null) return 'Günlük hediye sadece kayıtlı kullanıcılar için.';
    try {
      final snap = await _ref!.get();
      final d = snap.value;
      final mevcut = _krediOku(d) ?? 0;
      final son = (d is Map) ? (int.tryParse('${d['son_gunluk_hediye']}') ?? 0) : 0;
      final now = _simdi;
      if (son > 0 && son > now) return '⛔ Geçersiz işlem!';
      if (son > 0 && _trGun(son) == _trGun(now)) {
        hediyeHazir.value = false;
        return '⏳ Bugünkü hediyeni zaten aldın!';
      }
      final yeni = mevcut + gunlukHediye;
      await _ref!.update({
        'kredi': yeni,
        'son_gunluk_hediye': ServerValue.timestamp,
        'son_gunluk_hediye_miktar': gunlukHediye,
        'guncelleme': ServerValue.timestamp,
      });
      kredi.value = yeni;
      hediyeHazir.value = false;
      return null;
    } catch (e) {
      return 'Hata: $e';
    }
  }
}
