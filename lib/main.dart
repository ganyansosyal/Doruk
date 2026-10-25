import 'package:flutter/material.dart';
import 'menu_screen.dart';
import 'theme.dart';

void main() {
  runApp(const HafizaApp());
}

class HafizaApp extends StatelessWidget {
  const HafizaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hafıza Kartları',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: C.bg,
      ),
      home: const MenuScreen(),
    );
  }
}
