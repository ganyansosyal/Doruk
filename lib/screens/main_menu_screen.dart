// lib/screens/main_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart'; // AppRoutes, AppTheme, OyuncuDurumu

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1750), Color(0xFF120A24)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const _UstBar(),
              const Spacer(),
              const _Baslik(),
              const SizedBox(height: 40),
              _SavasButonu(
                onTap: () => Navigator.pushNamed(context, AppRoutes.savas),
              ),
              const Spacer(),
              const _AltMenu(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Üst bar: seviye, altın, elmas
class _UstBar extends StatelessWidget {
  const _UstBar();

  @override
  Widget build(BuildContext context) {
    final oyuncu = context.watch<OyuncuDurumu>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _Sayac(
            ikon: Icons.shield,
            renk: AppTheme.ikincil,
            metin: 'Sv. ${oyuncu.seviye}',
          ),
          const Spacer(),
          _Sayac(
            ikon: Icons.monetization_on,
            renk: AppTheme.vurgu,
            metin: '${oyuncu.altin}',
          ),
          const SizedBox(width: 8),
          _Sayac(
            ikon: Icons.diamond,
            renk: Colors.cyanAccent,
            metin: '${oyuncu.elmas}',
          ),
        ],
      ),
    );
  }
}

class _Sayac extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final String metin;
  const _Sayac({required this.ikon, required this.renk, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, color: renk, size: 20),
          const SizedBox(width: 6),
          Text(metin,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'KART\nSAVAŞI',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 48,
        height: 1.1,
        fontWeight: FontWeight.w900,
        color: AppTheme.vurgu,
        letterSpacing: 4,
      ),
    );
  }
}

// Büyük SAVAŞA BAŞLA butonu
class _SavasButonu extends StatelessWidget {
  final VoidCallback onTap;
  const _SavasButonu({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6F00), Color(0xFFFFC107)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Text(
          'SAVAŞA BAŞLA',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

// Alt menü: Deste, Mağaza, Görevler, Ayarlar
class _AltMenu extends StatelessWidget {
  const _AltMenu();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _AltButon(
            ikon: Icons.style, etiket: 'Deste', rota: AppRoutes.deste),
        _AltButon(
            ikon: Icons.storefront, etiket: 'Mağaza', rota: AppRoutes.magaza),
        _AltButon(
            ikon: Icons.assignment, etiket: 'Görevler', rota: AppRoutes.gorevler),
        _AltButon(
            ikon: Icons.settings, etiket: 'Ayarlar', rota: AppRoutes.ayarlar),
      ],
    );
  }
}

class _AltButon extends StatelessWidget {
  final IconData ikon;
  final String etiket;
  final String rota;
  const _AltButon(
      {required this.ikon, required this.etiket, required this.rota});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, rota),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(ikon, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(etiket, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
