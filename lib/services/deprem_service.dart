import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _cacheKey = 'depremM3Cache';

class Quake {
  final double mag, depth;
  final String loc, date;
  Quake(this.mag, this.depth, this.loc, this.date);

  Map<String, dynamic> toJson() => {'mag': mag, 'depth': depth, 'loc': loc, 'date': date};
  factory Quake.fromJson(Map<String, dynamic> j) =>
      Quake((j['mag'] as num).toDouble(), (j['depth'] as num).toDouble(), j['loc'] as String, j['date'] as String);

  DateTime? get time => parseQuakeDate(date);
  String get key => '$date|$loc';
}

/// "2024.05.01 12:34:56" / "2024-05-01 12:34:56" → DateTime (TR saati kabul edilir)
DateTime? parseQuakeDate(String raw) {
  if (raw.trim().isEmpty) return null;
  var s = raw
      .trim()
      .replaceFirstMapped(RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})'), (m) => '${m[1]}-${m[2]}-${m[3]}')
      .replaceFirst(' ', 'T');
  if (!s.contains('Z') && !s.contains('+')) s += '+03:00';
  return DateTime.tryParse(s);
}

({String label, int color}) depremSev(double m) {
  if (m < 2.0) return (label: 'Mikro', color: 0xFF7AA0C4);
  if (m < 3.0) return (label: 'Küçük', color: 0xFF00E676);
  if (m < 4.0) return (label: 'Orta', color: 0xFFFBBF24);
  if (m < 5.0) return (label: 'Güçlü', color: 0xFFFB923C);
  if (m < 6.0) return (label: 'Büyük', color: 0xFFFF5252);
  return (label: 'Şiddetli', color: 0xFFE040FB);
}

String depremZamanFark(String date) {
  final d = parseQuakeDate(date);
  if (d == null) return date.isEmpty ? '—' : date;
  final diff = DateTime.now().difference(d).inSeconds;
  if (diff < 0) return 'az önce';
  if (diff < 60) return '$diff sn önce';
  if (diff < 3600) return '${diff ~/ 60} dk önce';
  if (diff < 86400) return '${diff ~/ 3600} saat önce';
  return '${diff ~/ 86400} gün önce';
}

String depremTarihSaat(String date) {
  final d = parseQuakeDate(date)?.toLocal();
  if (d == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}.${p(d.month)}.${d.year} ${p(d.hour)}:${p(d.minute)}';
}

Future<List<Quake>> _cacheLoad() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_cacheKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Quake.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

Future<void> _cacheSave(List<Quake> yeni) async {
  try {
    final sp = await SharedPreferences.getInstance();
    final map = <String, Quake>{};
    for (final q in [...await _cacheLoad(), ...yeni]) {
      if (q.date.isEmpty) continue;
      map.putIfAbsent(q.key, () => q);
    }
    final sinir = DateTime.now().subtract(const Duration(days: 7));
    final clean = map.values.where((q) {
      final t = q.time;
      return t == null || !t.isBefore(sinir);
    }).toList();
    await sp.setString(_cacheKey, jsonEncode(clean.map((q) => q.toJson()).toList()));
  } catch (_) {}
}

double _d(dynamic v) => double.tryParse('$v') ?? 0;

Future<List<Quake>> depremYukle() async {
  const base = 'https://api.orhanaydogdu.com.tr/deprem/kandilli/live?limit=500';
  final pages = await Future.wait([0, 500, 1000, 1500].map((skip) async {
    try {
      final r = await http.get(Uri.parse('$base&skip=$skip')).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return <dynamic>[];
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      return (j['result'] ?? j['data'] ?? <dynamic>[]) as List;
    } catch (_) {
      return <dynamic>[];
    }
  }));

  final seen = <String>{};
  final apiList = <Map<String, dynamic>>[];
  for (final p in pages) {
    for (final q in p) {
      final m = q as Map<String, dynamic>;
      final key = '${m['date_time'] ?? m['date'] ?? m['time'] ?? ''}${m['title'] ?? m['location'] ?? ''}';
      if (seen.add(key)) apiList.add(m);
    }
  }
  if (apiList.isEmpty) throw Exception('Boş yanıt');

  final mapped = apiList.map((q) {
    final loc = q['title'] ?? q['location'] ?? q['yer'] ?? (q['location_properties']?['closestCity']?['name']) ?? 'Bilinmiyor';
    final mag = _d(q['mag'] ?? q['ml'] ?? q['mw'] ?? 0);
    final depth = _d(q['depth'] ?? q['derinlik'] ?? 0);
    final date = '${q['date_time'] ?? q['date'] ?? q['created_at'] ?? q['time'] ?? ''}';
    return Quake(double.parse(mag.toStringAsFixed(1)), double.parse(depth.toStringAsFixed(1)), '$loc', date);
  }).toList();

  await _cacheSave(mapped.where((q) => q.mag >= 3.0).toList());

  final all = <String, Quake>{};
  for (final q in await _cacheLoad()) {
    all[q.key] = q;
  }
  final h24 = DateTime.now().subtract(const Duration(hours: 24));
  for (final q in mapped) {
    final t = q.time;
    if (t == null || !t.isBefore(h24)) all[q.key] = q;
  }
  final list = all.values.toList()
    ..sort((a, b) => (b.time?.millisecondsSinceEpoch ?? 0).compareTo(a.time?.millisecondsSinceEpoch ?? 0));
  return list;
}
