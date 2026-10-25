import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/market_page.dart';
import '../pages/doviz_page.dart';
import '../pages/placeholder_page.dart';
import '../pages/analiz_page.dart';
import '../pages/rsi_page.dart';
import '../pages/hacim_page.dart';
import '../pages/fibo_page.dart';
import '../pages/sinyal_page.dart';
import '../pages/whale_page.dart';
import '../pages/ceviri_page.dart';
import '../pages/deprem_page.dart';
import '../pages/takvim_page.dart';
import '../pages/nabiz_page.dart';
import '../pages/login_page.dart';
import '../services/auth_service.dart';
import '../widgets/kredi_kapisi.dart';
import '../widgets/kredi_rozeti.dart';

/// Eski web uygulamasındaki activePage değerleri → başlık (Daha Fazla menüsü bunu listeler)
const modules = <String, String>{
  'analiz': 'Analiz',
  'ceviri': 'Çeviri',
  'cuzdan': 'Cüzdan',
  'deprem': 'Deprem',
  'fibo': 'Fibonacci',
  'futures': 'Futures',
  'hacim': 'Hacim',
  'nabiz': 'Nabız',
  'notes': 'Notlar',
  'rsi': 'RSI',
  'sentinel': 'Sentinel',
  'sinyal': 'Sinyal',
  'takvim': 'Takvim',
  'whale': 'Whale',
};

/// Yazılan sayfalar buraya eklenir; eklenmeyenler "Yakında" gösterir.
final Map<String, Widget Function()> _pages = {
  'analiz': () => const AnalizPage(),
  'rsi': () => const RsiPage(),
  'hacim': () => const HacimPage(),
  'fibo': () => const FiboPage(),
  'sinyal': () => const SinyalPage(),
  'whale': () => const WhalePage(),
  'ceviri': () => const CeviriPage(),
  'deprem': () => const DepremPage(),
  'takvim': () => const TakvimPage(),
  'nabiz': () => const NabizPage(),
};

class _Shell extends StatelessWidget {
  final Widget child;
  final String location;
  const _Shell({required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    final anaSayfa = location == '/';
    // Alt menü yok: ana sayfa modül ızgarası. Geri tuşu alt sayfalardan ana sayfaya döner.
    return PopScope(
      canPop: anaSayfa,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            anaSayfa ? const AnaBaslik() : const KrediSeridi(),
            Expanded(child: child),
          ]),
        ),
        floatingActionButton: const SohbetButonu(),
      ),
    );
  }
}

final appRouter = GoRouter(
  refreshListenable: AuthService.user,
  redirect: (context, state) {
    final girdi = AuthService.user.value != null;
    final loginde = state.uri.path == '/login';
    if (!girdi && !loginde) return '/login';
    if (girdi && loginde) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
    ShellRoute(
      builder: (c, s, child) => _Shell(child: child, location: s.uri.path),
      routes: [
        GoRoute(path: '/', builder: (c, s) => const HomePage()),
        GoRoute(path: '/market', builder: (c, s) => const MarketPage()),
        GoRoute(path: '/doviz', builder: (c, s) => KrediKapisi(sayfa: 'doviz', builder: () => Scaffold(
              appBar: AppBar(title: const Text('Döviz Çevir'), leading: BackButton(onPressed: () => c.go('/'))),
              body: const DovizPage(),
            ))),
        GoRoute(path: '/more', redirect: (c, s) => '/'),
        for (final e in modules.entries)
          GoRoute(
            path: '/${e.key}',
            builder: (c, s) => KrediKapisi(
              sayfa: e.key,
              builder: () => _pages[e.key]?.call() ?? PlaceholderPage(title: e.value),
            ),
          ),
      ],
    ),
  ],
);
