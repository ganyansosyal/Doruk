import 'package:flutter/material.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DorukApp());
}

class DorukApp extends StatelessWidget {
  const DorukApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Doruk',
        debugShowCheckedModeBanner: false,
        theme: dorukTheme,
        routerConfig: appRouter,
      );
}
