import 'dart:convert';
import 'package:http/http.dart' as http;

class Dil {
  final String code, name, flag;
  const Dil(this.code, this.name, this.flag);
}

const ceviriDiller = <Dil>[
  Dil('tr', 'TÜRKÇE', '🇹🇷'),
  Dil('en', 'İNGİLİZCE', '🇬🇧'),
  Dil('de', 'ALMANCA', '🇩🇪'),
  Dil('fr', 'FRANSIZCA', '🇫🇷'),
  Dil('es', 'İSPANYOLCA', '🇪🇸'),
  Dil('it', 'İTALYANCA', '🇮🇹'),
  Dil('pt', 'PORTEKİZCE', '🇵🇹'),
  Dil('ru', 'RUSÇA', '🇷🇺'),
  Dil('ar', 'ARAPÇA', '🇸🇦'),
  Dil('zh', 'ÇİNCE', '🇨🇳'),
  Dil('ja', 'JAPONCA', '🇯🇵'),
  Dil('ko', 'KORECE', '🇰🇷'),
  Dil('nl', 'FELEMENKÇE', '🇳🇱'),
  Dil('pl', 'LEHÇE', '🇵🇱'),
  Dil('sv', 'İSVEÇÇE', '🇸🇪'),
  Dil('fa', 'FARSÇA', '🇮🇷'),
  Dil('hi', 'HİNTÇE', '🇮🇳'),
  Dil('el', 'YUNANCA', '🇬🇷'),
  Dil('uk', 'UKRAYNACA', '🇺🇦'),
  Dil('az', 'AZERBAYCANCA', '🇦🇿'),
];

Future<String> ceviriYap(String metin, Dil src, Dil tgt) async {
  final uri = Uri.parse('https://translate.googleapis.com/translate_a/single').replace(queryParameters: {
    'client': 'gtx',
    'sl': src.code,
    'tl': tgt.code,
    'dt': 't',
    'q': metin,
  });
  final r = await http.get(uri).timeout(const Duration(seconds: 15));
  final data = jsonDecode(utf8.decode(r.bodyBytes));
  final parts = (data[0] as List).map((x) => '${x[0] ?? ''}').join();
  if (parts.isEmpty) throw Exception('Çeviri yapılamadı.');
  return parts;
}
