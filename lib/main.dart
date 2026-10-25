import 'package:flutter/material.dart';
import 'core/firebase_init.dart';
import 'core/router.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
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
