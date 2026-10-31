// lib/main.dart
//
// Önerilen klasör yapısı (modüler):
//
// lib/
//  ├─ main.dart                 -> Uygulama girişi (bu dosya)
//  ├─ core/
//  │   ├─ app_routes.dart       -> Rota isimleri ve yönlendirme
//  │   └─ app_theme.dart        -> Renkler ve tema
//  ├─ models/                   -> PlayerData, CardModel vb.
//  ├─ services/                 -> GameDatabaseService (Firebase)
//  ├─ screens/                  -> Ana menü, deste, mağaza vb.
//  └─ game/                     -> Flame bileşenleri (savaş arenası)

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/main_menu_screen.dart';

// -----------------------------------------------------------------------------
// TEMA (ileride core/app_theme.dart dosyasına taşınabilir)
// -----------------------------------------------------------------------------
class AppTheme {
  static const Color arkaPlan = Color(0xFF1B1030);
  static const Color vurgu = Color(0xFFFFC107);
  static const Color ikincil = Color(0xFF7C4DFF);

  static ThemeData get koyuTema => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: arkaPlan,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ikincil,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}

// -----------------------------------------------------------------------------
// ROTALAR (ileride core/app_routes.dart dosyasına taşınabilir)
// -----------------------------------------------------------------------------
class AppRoutes {
  static const String anaMenu = '/';
  static const String savas = '/savas';
  static const String deste = '/deste';
  static const String magaza = '/magaza';
  static const String gorevler = '/gorevler';
  static const String ayarlar = '/ayarlar';
}

// -----------------------------------------------------------------------------
// OYUNCU DURUMU (ileride models/ + provider ile genişletilecek)
// -----------------------------------------------------------------------------
class OyuncuDurumu extends ChangeNotifier {
  int seviye = 1;
  int altin = 500;
  int elmas = 20;
  List<String> desteKartIdleri = [];

  void altinEkle(int miktar) {
    altin += miktar;
    notifyListeners(); // Arayüzü günceller
  }

  void elmasEkle(int miktar) {
    elmas += miktar;
    notifyListeners();
  }
}

// -----------------------------------------------------------------------------
// GİRİŞ NOKTASI
// -----------------------------------------------------------------------------
Future<void> main() async {
  // Flutter motorunun hazır olduğundan emin ol (async işlemlerden önce şart)
  WidgetsFlutterBinding.ensureInitialized();

  // Oyunu yatay veya dikey kilitlemek isterseniz (şimdilik dikey):
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Tam ekran deneyimi için durum çubuğunu gizle
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Firebase'i başlat.
  // NOT: `flutterfire configure` komutunu çalıştırdıktan sonra
  // Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
  // şeklinde kullanın. Yapılandırma yokken uygulama çökmesin diye try/catch var.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase başlatılamadı (yapılandırma eksik olabilir): $e');
  }

  runApp(
    // Oyuncu verisini tüm uygulamaya sağlar
    ChangeNotifierProvider(
      create: (_) => OyuncuDurumu(),
      child: const KartSavasiApp(),
    ),
  );
}

// -----------------------------------------------------------------------------
// KÖK UYGULAMA
// -----------------------------------------------------------------------------
class KartSavasiApp extends StatelessWidget {
  const KartSavasiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kart Savaşı',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.koyuTema,
      initialRoute: AppRoutes.anaMenu,
      routes: {
        AppRoutes.anaMenu: (_) => const MainMenuScreen(),
        AppRoutes.savas: (_) => const _BosEkran(baslik: 'Savaş Arenası'),
        AppRoutes.deste: (_) => const _BosEkran(baslik: 'Deste'),
        AppRoutes.magaza: (_) => const _BosEkran(baslik: 'Mağaza'),
        AppRoutes.gorevler: (_) => const _BosEkran(baslik: 'Görevler'),
        AppRoutes.ayarlar: (_) => const _BosEkran(baslik: 'Ayarlar'),
      },
    );
  }
}

// Geçici yer tutucu ekran. Sonraki adımlarda gerçek ekranlarla değiştirilecek.
class _BosEkran extends StatelessWidget {
  final String baslik;
  const _BosEkran({required this.baslik});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(baslik)),
      body: Center(
        child: Text(
          baslik,
          style: const TextStyle(fontSize: 28, color: AppTheme.vurgu),
        ),
      ),
    );
  }
}
