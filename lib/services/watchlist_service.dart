import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/firebase_init.dart';
import 'auth_service.dart';

/// İzleme listesi öğesi. Web'deki {id, name, type} ile aynı biçim.
class WlItem {
  final String id; // BTCUSDT veya XAU-GR gibi
  final String name; // BTC
  final String type; // crypto | local ...
  const WlItem(this.id, this.name, this.type);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type};

  static WlItem? from(Object? o) {
    if (o is! Map) return null;
    final id = o['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return WlItem(id, (o['name'] ?? id).toString(), (o['type'] ?? 'crypto').toString());
  }
}

/// Web'deki watchlist/{kullanici} yapısı: { list: [...], guncelleme: ms }
class WatchlistService {
  static const defaults = [
    WlItem('BTCUSDT', 'BTC', 'crypto'),
    WlItem('ETHUSDT', 'ETH', 'crypto'),
    WlItem('SOLUSDT', 'SOL', 'crypto'),
    WlItem('AVAXUSDT', 'AVAX', 'crypto'),
  ];

  static String get _user => (AuthService.user.value ?? '').toLowerCase();
  static String get _cacheKey => 'doruk_wl_${_user.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

  static List<WlItem> _parse(Object? raw) {
    if (raw is! List) return [];
    return raw.map(WlItem.from).whereType<WlItem>().toList();
  }

  static Future<List<WlItem>> load() async {
    var list = <WlItem>[];
    final prefs = await SharedPreferences.getInstance();
    try {
      final s = prefs.getString(_cacheKey);
      if (s != null) list = _parse(jsonDecode(s));
    } catch (_) {}

    if (firebaseReady && _user.isNotEmpty) {
      try {
        final snap = await db().ref('watchlist/${fbKey(_user)}/list').get().timeout(const Duration(seconds: 3));
        if (snap.exists) {
          final fb = _parse(snap.value);
          if (fb.isNotEmpty) {
            list = fb;
            await prefs.setString(_cacheKey, jsonEncode(fb.map((e) => e.toJson()).toList()));
          }
        }
      } catch (_) {}
    }
    return list.isEmpty ? List<WlItem>.of(defaults) : list;
  }

  static Future<void> save(List<WlItem> list) async {
    final json = list.map((e) => e.toJson()).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(json));
    } catch (_) {}
    if (firebaseReady && _user.isNotEmpty) {
      try {
        await db().ref('watchlist/${fbKey(_user)}').set({
          'list': json,
          'guncelleme': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (_) {}
    }
  }
}
