import 'package:flutter/material.dart';
import '../core/theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('DORUK', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: kAccent)),
      );
}
