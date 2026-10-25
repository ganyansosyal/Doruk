import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF0B1226);
  static const card = Color(0xFF16204A);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF8B5CF6);
  static const pink = Color(0xFFEC4899);
  static const green = Color(0xFF22C55E);
  static const gold = Color(0xFFFFC107);
  static const dim = Color(0xFF9AA4C0);
}

const mainGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [C.blue, C.purple],
);

const bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF0B1226), Color(0xFF1B1450)],
);

// Yumusak sayfa gecisi: solarak ve hafif yukari kayarak
Route<T> softRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, a, b) => page,
    transitionsBuilder: (context, a, b, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
