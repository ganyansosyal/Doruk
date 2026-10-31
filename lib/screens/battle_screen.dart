// lib/screens/battle_screen.dart

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/battle_game.dart';
import '../main.dart'; // OyuncuDurumu

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late final BattleGame _oyun;

  @override
  void initState() {
    super.initState();
    _oyun = BattleGame(onGameEnd: _oyunBitti);
  }

  void _oyunBitti(bool kazandi) {
    if (!mounted) return;
    if (kazandi) {
      context.read<OyuncuDurumu>().altinEkle(kOdulAltin);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120A24),
      body: SafeArea(child: GameWidget(game: _oyun)),
    );
  }
}
