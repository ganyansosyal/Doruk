import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/market_page.dart';
import '../pages/doviz_page.dart';
import '../pages/more_page.dart';
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
};

class _Shell extends StatelessWidget {
  final Widget child;
  final String location;
  const _Shell({required this.child, required this.location});

  static const _tabs = ['/', '/market', '/doviz', '/more'];

  @override
  Widget build(BuildContext context) {
    var idx = _tabs.indexOf(location);
    if (idx < 0) idx = 3;
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Ana Sayfa'),
          NavigationDestination(icon: Icon(Icons.candlestick_chart_outlined), label: 'Market'),
          NavigationDestination(icon: Icon(Icons.currency_exchange), label: 'Döviz'),
          NavigationDestination(icon: Icon(Icons.apps), label: 'Daha Fazla'),
        ],
      ),
    );
  }
}

final appRouter = GoRouter(
  routes: [
    ShellRoute(
      builder: (c, s, child) => _Shell(child: child, location: s.uri.path),
      routes: [
        GoRoute(path: '/', builder: (c, s) => const HomePage()),
        GoRoute(path: '/market', builder: (c, s) => const MarketPage()),
        GoRoute(path: '/doviz', builder: (c, s) => const DovizPage()),
        GoRoute(path: '/more', builder: (c, s) => const MorePage()),
        for (final e in modules.entries)
          GoRoute(
            path: '/${e.key}',
            builder: (c, s) => _pages[e.key]?.call() ?? PlaceholderPage(title: e.value),
          ),
      ],
    ),
  ],
);
