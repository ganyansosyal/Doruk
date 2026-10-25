import 'package:flutter/material.dart';

const kBg = Color(0xFF040810);
const kCard = Color(0xFF0D1829);
const kAccent = Color(0xFF00D4FF);
const kAccent2 = Color(0xFF00FFCC);
const kText = Color(0xFFE8F0FF);
const kTextDim = Color(0xFF7AA0C4);
const kUp = Color(0xFF00E676);
const kDown = Color(0xFFFF5252);

final ThemeData dorukTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(primary: kAccent, secondary: kAccent2, surface: kCard),
  appBarTheme: const AppBarTheme(backgroundColor: kBg, elevation: 0, centerTitle: true),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: const Color(0xFF060A16),
    indicatorColor: kAccent.withOpacity(0.18),
  ),
  cardTheme: CardTheme(
    color: kCard,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  useMaterial3: true,
);
