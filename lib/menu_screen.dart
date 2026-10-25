import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'theme.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  Widget _floatingCard(String emoji, double angle, double dir) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_float.value) - 0.5;
        return Transform.translate(
          offset: Offset(0, t * 18 * dir),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: Container(
        width: 78,
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x668B5CF6), blurRadius: 24),
          ],
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 38)),
      ),
    );
  }

  Widget _appear(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + index * 130),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 40), child: c),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _floatingCard('🐶', -0.18, 1),
                    const SizedBox(width: 14),
                    _floatingCard('🚀', 0.0, -1),
                    const SizedBox(width: 14),
                    _floatingCard('🍕', 0.18, 1),
                  ],
                ),
                const SizedBox(height: 36),
                _appear(
                  0,
                  const Text(
                    'Hafıza Kartları',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                _appear(
                  1,
                  const Text(
                    'Eşleri bul, hafızanı test et',
                    style: TextStyle(fontSize: 15, color: C.dim),
                  ),
                ),
                const SizedBox(height: 32),
                for (int i = 0; i < levels.length; i++)
                  _appear(
                    i + 2,
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _LevelButton(
                        level: levels[i],
                        onTap: () => Navigator.push(
                            context, softRoute(GameScreen(level: levels[i]))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelButton extends StatefulWidget {
  final Level level;
  final VoidCallback onTap;
  const _LevelButton({required this.level, required this.onTap});

  @override
  State<_LevelButton> createState() => _LevelButtonState();
}

class _LevelButtonState extends State<_LevelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.level;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            gradient: mainGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Color(0x553B82F6), blurRadius: 18),
            ],
          ),
          child: Row(
            children: [
              Text(l.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${l.pairs} çift',
                  style: const TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
