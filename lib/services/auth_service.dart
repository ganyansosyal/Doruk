import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/firebase_init.dart';

const _fakeMailDomains = {
  'mailinator.com', 'tempmail.com', 'guerrillamail.com', 'throwam.com', 'sharklasers.com',
  'guerrillamailblock.com', 'grr.la', 'guerrillamail.info', 'guerrillamail.biz', 'guerrillamail.de',
  'guerrillamail.net', 'guerrillamail.org', 'spam4.me', 'yopmail.com', 'yopmail.fr', 'cool.fr.nf',
  'jetable.fr.nf', 'nospam.ze.tc', 'nomail.xl.cx', 'mega.zik.dj', 'speed.1s.fr', 'courriel.fr.nf',
  'moncourrier.fr.nf', 'monemail.fr.nf', 'monmail.fr.nf', 'dispostable.com', 'mailnull.com',
  'spamgourmet.com', 'trashmail.at', 'trashmail.io', 'trashmail.me', 'trashmail.net', 'trashmail.org',
  'discard.email', 'spamhere.com', 'getairmail.com', 'filzmail.com', 'maildrop.cc',
  'spambox.us', 'fakeinbox.com', 'mailexpire.com', 'spamfree24.org', 'mailscrap.com',
  'spammotel.com', 'spam.la', 'tempr.email', 'discard.cf', 'crap.handcrafted.jp',
  'spamgob.com', 'spamhereplease.com', 'tempinbox.com', 'tempe-mail.com', 'spamex.com',
  'trashmail.com', 'mailnew.com', 'getonemail.net', 'discardmail.com',
  'burnermail.io', 'throwaway.email', 'tmpmail.org', 'tmpmail.net', 'tmp-mail.org',
  'spamwc.cf', 'spamwc.de', 'spamwc.ga', 'spamwc.gq', 'spamwc.ml',
  'getnada.com', 'nada.email', 'tmail.com', '10minutemail.com', '10minutemail.net',
  'minutemailbox.com', 'mailmetrash.com', '20minutemail.com', 'mobi-mail.de',
};

class AuthService {
  /// Giriş yapmış kullanıcı adı (null = giriş yok). Router bunu dinler.
  static final ValueNotifier<String?> user = ValueNotifier<String?>(null);

  /// Giriş ekranında gösterilecek mesaj (ban, hesap silindi vb.)
  static final ValueNotifier<String> notice = ValueNotifier<String>('');

  static SharedPreferences? _prefs;
  static String _deviceId = '';
  static String? _ip;
  static final List<StreamSubscription<DatabaseEvent>> _subs = [];

  static String get deviceId => _deviceId;

  static Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _deviceId = _prefs!.getString('doruk_device_id') ?? '';
    if (_deviceId.isEmpty) {
      _deviceId = 'dev_${Random().nextInt(1 << 31).toRadixString(36)}${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      await _prefs!.setString('doruk_device_id', _deviceId);
    }
    final saved = _prefs!.getString('doruk_login_user');
    if (saved != null && saved.isNotEmpty) {
      user.value = saved;
      _banDinle(saved);
      // Açılışta ban/force-logout kontrolü (arka planda)
      _banKontrol(saved).then((err) {
        if (err != null) _zorlaCikis(err);
      });
    }
  }

  static String _sha(String s) => sha256.convert(utf8.encode(s)).toString();

  static Future<String?> _getIp() async {
    if (_ip != null) return _ip;
    try {
      final r = await http.get(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 6));
      _ip = (jsonDecode(r.body)['ip'] as String?);
    } catch (_) {}
    return _ip;
  }

  // ───────────────────────── GİRİŞ ─────────────────────────

  /// Hata varsa metnini, başarılıysa null döner.
  static Future<String?> giris(String kullaniciRaw, String sifre) async {
    final kullanici = kullaniciRaw.trim().toLowerCase();
    if (kullanici.isEmpty || sifre.isEmpty) return 'Tüm alanları doldurun';
    if (kullanici == 'doruk') return 'Yönetici girişi mobil uygulamada kapalı. Web sürümünü kullanın.';
    if (!firebaseReady) return 'Veritabanına bağlanılamadı. İnternet bağlantını kontrol et.';

    try {
      final key = fbKey(kullanici);
      final snap = await db().ref('kullanicilar/$key').get();
      if (!snap.exists) return 'Kullanıcı bulunamadı';
      final data = Map<String, dynamic>.from(snap.value as Map);
      final email = data['email'] as String?;
      final dbHash = data['sifre'] as String?;

      // Şifre kontrolünden önce hesap ban kontrolü
      final ban = await db().ref('banlar/$key').get();
      if (ban.exists) return '🚫 Hesabınız yasaklandı. Giriş yapamazsınız.';

      final hash = _sha(sifre);
      var ok = false;

      // Önce Firebase Auth (şifre sıfırlandıysa bu çalışır)
      if (email != null && email.isNotEmpty) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: sifre);
          ok = true;
          if (dbHash != hash) {
            await db().ref('kullanicilar/$key/sifre').set(hash).catchError((_) {});
          }
        } catch (_) {
          if (dbHash == hash) {
            ok = true;
            // Auth'a kaydet (sessizce)
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: sifre);
            } catch (_) {}
          }
        }
      } else {
        ok = dbHash == hash;
      }
      if (!ok) return 'Şifre hatalı';

      return await _girisTamamla(kullanici);
    } catch (e) {
      return 'Bağlantı hatası: $e';
    }
  }

  static Future<String?> _girisTamamla(String kullanici) async {
    final banErr = await _banKontrol(kullanici);
    if (banErr != null) return banErr;

    await _prefs!.setString('doruk_login_user', kullanici);
    _kayitCihazVeIp(kullanici);
    _logKaydet(kullanici, 'giris');
    notice.value = '';
    user.value = kullanici;
    _banDinle(kullanici);
    return null;
  }

  // ───────────────────────── KAYIT ─────────────────────────

  static Future<String?> kayit({
    required String kullaniciRaw,
    required String emailRaw,
    required String sifre,
    required String sifre2,
  }) async {
    final kullanici = kullaniciRaw.trim().toLowerCase();
    final email = emailRaw.trim().toLowerCase();
    if (kullanici.isEmpty || email.isEmpty || sifre.isEmpty || sifre2.isEmpty) return 'Tüm alanları doldurun';
    if (kullanici.length < 3) return 'Kullanıcı adı en az 3 karakter';
    if (kullanici == 'doruk') return 'Bu kullanıcı adı alınmış';
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      return 'Geçerli bir e-posta adresi girin (örn: ad@gmail.com)';
    }
    if (sifre.length < 6) return 'Şifre en az 6 karakter';
    if (sifre != sifre2) return 'Şifreler eşleşmiyor';
    if (_fakeMailDomains.contains(email.split('@').last)) {
      return 'Geçici veya sahte e-posta adresleri kabul edilmiyor. Lütfen gerçek bir e-posta girin.';
    }
    if (!firebaseReady) return 'Veritabanına bağlanılamadı. İnternet bağlantını kontrol et.';

    try {
      final key = fbKey(kullanici);
      if ((await db().ref('kullanicilar/$key').get()).exists) return 'Bu kullanıcı adı alınmış';
      final emailKey = email.replaceAll(RegExp(r'[.#$\[\]@/]'), '_');
      if ((await db().ref('email_index/$emailKey').get()).exists) return 'Bu e-posta adresi zaten kayıtlı';

      // Firebase Auth'a kaydet (şifre sıfırlama buraya bağlı)
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: sifre);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-email') return 'Geçersiz e-posta adresi';
        // email-already-in-use / operation-not-allowed → doğrudan DB'ye yaz
        if (e.code != 'email-already-in-use' && e.code != 'operation-not-allowed') {
          return 'Kayıt başarısız: ${e.message ?? 'Bilinmeyen hata'}';
        }
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await db().ref('kullanicilar/$key').set({'kullanici': kullanici, 'email': email, 'sifre': _sha(sifre), 'kayit': now});
      db().ref('email_index/$emailKey').set({'kullanici': kullanici, 'kayit': now}).catchError((_) {});
      db().ref('force_logout/$key').remove().catchError((_) {});
      db().ref('deleted_accounts/$key').remove().catchError((_) {});
      return null; // sayfa kısa süre başarı mesajı gösterip giris çağıracak
    } catch (e) {
      return 'Hata: $e';
    }
  }

  // ───────────────────────── ŞİFRE SIFIRLAMA ─────────────────────────

  /// Başarılıysa (true, mesaj), değilse (false, hata)
  static Future<(bool, String)> sifreSifirla(String kullaniciRaw) async {
    final kullanici = kullaniciRaw.trim().toLowerCase();
    if (kullanici.isEmpty) return (false, 'Önce kullanıcı adını yaz');
    if (kullanici == 'doruk') return (false, 'Yönetici için web sürümünü kullanın.');
    if (!firebaseReady) return (false, 'Veritabanına bağlanılamadı');
    try {
      final snap = await db().ref('kullanicilar/${fbKey(kullanici)}').get();
      if (!snap.exists) return (false, 'Kullanıcı bulunamadı');
      final email = (snap.value as Map)['email'] as String?;
      if (email == null || email.isEmpty) return (false, 'Bu hesaba e-posta bağlı değil');
      final auth = FirebaseAuth.instance;
      try {
        await auth.sendPasswordResetEmail(email: email);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-email') {
          // Auth'ta yok — geçici şifreyle oluştur, sonra reset gönder
          final tmp = 'Tmp${Random().nextInt(1 << 31).toRadixString(36)}1!';
          await auth.createUserWithEmailAndPassword(email: email, password: tmp);
          await auth.sendPasswordResetEmail(email: email);
        } else {
          return (false, 'Hata: ${e.message}');
        }
      }
      return (true, '📧 Şifre sıfırlama e-postası gönderildi: $email');
    } catch (e) {
      return (false, 'Hata: $e');
    }
  }

  // ───────────────────────── ÇIKIŞ ─────────────────────────

  static Future<void> cikis({String mesaj = ''}) async {
    final k = user.value;
    if (k != null) _logKaydet(k, 'cikis');
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    await _prefs?.remove('doruk_login_user');
    await _prefs?.remove('doruk_sohbet_nick');
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    notice.value = mesaj;
    user.value = null;
  }

  static Future<void> _zorlaCikis(String mesaj) => cikis(mesaj: mesaj);

  // ───────────────────────── BAN ─────────────────────────

  /// Banlıysa mesaj döner, değilse null. Force logout varsa onu da uygular.
  static Future<String?> _banKontrol(String kullanici) async {
    if (!firebaseReady) return null;
    try {
      final key = fbKey(kullanici);
      final force = await db().ref('force_logout/$key').get();
      if (force.exists) {
        await db().ref('force_logout/$key').remove().catchError((_) {});
        return '🔌 Oturumunuz yönetici tarafından kapatıldı.';
      }
      if ((await db().ref('banlar/$key').get()).exists) return '🚫 Hesabınız yasaklandı. Giriş yapamazsınız.';
      final dev = fbKey(_deviceId);
      if ((await db().ref('cihaz_banlar/$dev').get()).exists) return '📱 Bu cihaz yasaklandı. Giriş yapamazsınız.';
      final ip = await _getIp();
      if (ip != null && (await db().ref('ip_banlar/${ip.replaceAll('.', '_')}').get()).exists) {
        return '🌐 Bu IP adresi yasaklandı. Giriş yapamazsınız.';
      }
    } catch (_) {}
    return null;
  }

  /// Uygulama açıkken ban/force-logout gelirse anında çıkış
  static void _banDinle(String kullanici) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    if (!firebaseReady) return;
    final key = fbKey(kullanici);

    _subs.add(db().ref('banlar/$key').onValue.listen((e) {
      if (e.snapshot.exists) _zorlaCikis('🚫 Hesabınız yasaklandı. Giriş yapamazsınız.');
    }));
    _subs.add(db().ref('cihaz_banlar/${fbKey(_deviceId)}').onValue.listen((e) {
      if (e.snapshot.exists) _zorlaCikis('📱 Bu cihaz yasaklandı. Giriş yapamazsınız.');
    }));
    _getIp().then((ip) {
      if (ip == null || user.value == null) return;
      _subs.add(db().ref('ip_banlar/${ip.replaceAll('.', '_')}').onValue.listen((e) {
        if (e.snapshot.exists) _zorlaCikis('🌐 Bu IP adresi yasaklandı. Giriş yapamazsınız.');
      }));
    });
    _subs.add(db().ref('force_logout/$key').onValue.listen((e) async {
      if (!e.snapshot.exists) return;
      final v = e.snapshot.value;
      final silindi = v is Map && v['deleted'] == true;
      await db().ref('force_logout/$key').remove().catchError((_) {});
      if (silindi) {
        await Future.delayed(const Duration(seconds: 3));
        _zorlaCikis('🗑️ Hesabınız silindi.');
      } else {
        _zorlaCikis('🔌 Oturumunuz yönetici tarafından kapatıldı.');
      }
    }));
  }

  // ───────────────────────── KAYITLAR ─────────────────────────

  static Future<void> _kayitCihazVeIp(String kullanici) async {
    if (!firebaseReady) return;
    final key = fbKey(kullanici);
    db().ref('nick_cihaz/$key').set(_deviceId).catchError((_) {});
    final ip = await _getIp();
    if (ip != null) db().ref('nick_ip/$key').set(ip).catchError((_) {});
  }

  static void _logKaydet(String kullanici, String tip) {
    if (!firebaseReady || kullanici.toLowerCase() == 'doruk') return;
    final key = fbKey(kullanici);
    final now = DateTime.now().millisecondsSinceEpoch;
    final base = 'login_logs/$key';
    db().ref('$base/gecmis').push().set({'tip': tip, 'ts': now}).catchError((_) {});
    db().ref('$base/${tip == 'giris' ? 'son_giris' : 'son_cikis'}').set(now).catchError((_) {});
    db().ref('$base/kullanici').set(kullanici).catchError((_) {});
  }
}
