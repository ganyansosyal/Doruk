import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

class Level {
  final String name;
  final int pairs;
  final int cols;
  const Level(this.name, this.pairs, this.cols);
}

const levels = [
  Level('Kolay', 6, 3),
  Level('Orta', 8, 4),
  Level('Zor', 10, 4),
  Level('Çok Zor', 12, 4),
];

const _emojis = [
  '🐶', '🐱', '🦊', '🐼', '🐸', '🦁', '🐵', '🐙', '🦄',
  '🍕', '🍓', '🚀', '⚽', '🎸', '🌈', '🍩', '🐢', '🦋',
];

class GameScreen extends StatefulWidget {
  final Level level;
  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<String> _faces;
  late List<bool> _up;
  late List<bool> _done;
  int _first = -1;
  bool _lock = false;
  bool _won = false;
  int _moves = 0;
  int _matched = 0;
  Timer? _timer;
  final _secs = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _secs.dispose();
    super.dispose();
  }

  void _newGame() {
    _timer?.cancel();
    _timer = null;
    final rnd = math.Random();
    final pool = List<String>.from(_emojis)..shuffle(rnd);
    final picked = pool.take(widget.level.pairs).toList();
    _faces = [...picked, ...picked]..shuffle(rnd);
    _up = List<bool>.filled(_faces.length, false);
    _done = List<bool>.filled(_faces.length, false);
    _first = -1;
    _lock = false;
    _won = false;
    _moves = 0;
    _matched = 0;
    _secs.value = 0;
  }

  void _tap(int i) {
    if (_lock || _up[i] || _done[i]) return;
    HapticFeedback.selectionClick();
    _timer ??=
        Timer.periodic(const Duration(seconds: 1), (_) => _secs.value++);
    setState(() => _up[i] = true);
    if (_first < 0) {
      _first = i;
      return;
    }
    final a = _first;
    _first = -1;
    setState(() => _moves++);
    if (_faces[a] == _faces[i]) {
      HapticFeedback.mediumImpact();
      setState(() {
        _done[a] = true;
        _done[i] = true;
        _matched++;
      });
      if (_matched == widget.level.pairs) {
        _timer?.cancel();
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _won = true);
        });
      }
    } else {
      _lock = true;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _up[a] = false;
          _up[i] = false;
          _lock = false;
        });
      });
    }
  }

  String _time(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  Widget _chip(IconData icon, Widget text) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: C.dim),
          const SizedBox(width: 6),
          text,
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          Text(widget.level.name,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const Spacer(),
          _chip(
            Icons.touch_app_rounded,
            Text('$_moves',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          _chip(
            Icons.timer_outlined,
            ValueListenableBuilder<int>(
              valueListenable: _secs,
              builder: (context, s, _) => Text(_time(s),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            onPressed: () => setState(_newGame),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    final cols = widget.level.cols;
    final total = _faces.length;
    final rows = (total / cols).ceil();
    const gap = 10.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: LayoutBuilder(
        builder: (context, box) {
          final cellW = (box.maxWidth - gap * (cols - 1)) / cols;
          final cellH = (box.maxHeight - gap * (rows - 1)) / rows;
          final ratio = (cellW / cellH).clamp(0.6, 1.1).toDouble();
          return Center(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: total,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: ratio,
              ),
              itemBuilder: (context, i) => MemoryCard(
                face: _faces[i],
                up: _up[i],
                done: _done[i],
                onTap: () => _tap(i),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _winOverlay() {
    final ratio = _moves / widget.level.pairs;
    final stars = ratio <= 1.6 ? 3 : (ratio <= 2.4 ? 2 : 1);
    return Positioned.fill(
      child: Container(
        color: const Color(0xCC0B1226),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Color(0x668B5CF6), blurRadius: 30),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                const Text('Tebrikler!',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int s = 0; s < 3; s++)
                      Icon(Icons.star_rounded,
                          size: 40, color: s < stars ? C.gold : C.dim),
                  ],
                ),
                const SizedBox(height: 12),
                Text('$_moves hamle  •  ${_time(_secs.value)}',
                    style: const TextStyle(color: C.dim, fontSize: 15)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => setState(_newGame),
                  child: Container(
                    width: 200,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: mainGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('Tekrar oyna',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Menü'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _header(),
                  Expanded(child: _grid()),
                ],
              ),
              if (_won) _winOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoryCard extends StatelessWidget {
  final String face;
  final bool up;
  final bool done;
  final VoidCallback onTap;

  const MemoryCard({
    super.key,
    required this.face,
    required this.up,
    required this.done,
    required this.onTap,
  });

  Widget _back() {
    return Container(
      decoration: BoxDecoration(
        gradient: mainGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33FFFFFF), width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Text('?',
          style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0x99FFFFFF))),
    );
  }

  Widget _front(double size) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: done ? C.green : Colors.white, width: done ? 3 : 1),
        boxShadow: done
            ? const [BoxShadow(color: Color(0x9922C55E), blurRadius: 16)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(face, style: TextStyle(fontSize: size * 0.48)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = math.min(box.maxWidth, box.maxHeight);
          return AnimatedScale(
            scale: done ? 0.93 : 1.0,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: up ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOut,
              builder: (context, v, _) {
                final showFront = v > 0.5;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(v * math.pi),
                  child: showFront
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: _front(size),
                        )
                      : _back(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
