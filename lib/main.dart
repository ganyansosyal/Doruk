import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const EditProApp());
}

class EditProApp extends StatelessWidget {
  const EditProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EditPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B1226),
      ),
      home: const SplashScreen(),
    );
  }
}
