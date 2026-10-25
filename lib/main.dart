import 'package:flutter/material.dart';
import 'core/firebase_init.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/credit_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  await AuthService.load(); // kayıtlı oturumu oku
  CreditService.baslat(); // kredi + günlük hediye
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
