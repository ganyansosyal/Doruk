import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import '../filters.dart';
import '../theme.dart';

class _CropItem {
  final String name;
  final double? ratio;
  final bool free;
  const _CropItem(this.name, this.ratio, [this.free = false]);
}

const List<_CropItem> _crops = [
  _CropItem('Orijinal', null),
  _CropItem('Serbest', null, true),
  _CropItem('1:1', 1),
  _CropItem('4:3', 4 / 3),
  _CropItem('3:4', 3 / 4),
  _CropItem('16:9', 16 / 9),
  _CropItem('9:16', 9 / 16),
];

// Tüm ayarlar tek yerde. 0 = değişiklik yok.
class _Adj {
  final double bright; // -100..100
  final double contrast; // -100..100
  final double sat; // -100..100
  final double warm; // -100..100
  final double vignette; // 0..100
  final double blur; // 0..100
  final double focus; // 0..100 (odak alanı büyüklüğü)
  final double fx; // -1..1 odak noktası
  final double fy; // -1..1
  const _Adj({
    this.bright = 0,
    this.contrast = 0,
    this.sat = 0,
    this.warm = 0,
    this.vignette = 0,
    this.blur = 0,
    this.focus = 50,
    this.fx = 0,
    this.fy = 0,
  });

  _Adj copyWith({
    double? bright,
    double? contrast,
    double? sat,
    double? warm,
    double? vignette,
    double? blur,
    double? focus,
    double? fx,
    double? fy,
  }) {
    return _Adj(
      bright: bright ?? this.bright,
      contrast: contrast ?? this.contrast,
      sat: sat ?? this.sat,
      warm: warm ?? this.warm,
      vignette: vignette ?? this.vignette,
      blur: blur ?? this.blur,
      focus: focus ?? this.focus,
      fx: fx ?? this.fx,
      fy: fy ?? this.fy,
    );
  }
}

List<double> _mulM(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var i = 0; i < 4; i++) {
    for (var j = 0; j < 5; j++) {
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[i * 5 + k] * b[k * 5 + j];
      }
      if (j == 4) v += a[i * 5 + 4];
      out[i * 5 + j] = v;
    }
  }
  return out;
}

List<double> _satM(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return [
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

double _cl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

const Rect _fullRect = Rect.fromLTRB(0, 0, 1, 1);

class _CropPainter extends CustomPainter {
  final ValueNotifier<Rect> n;
  _CropPainter(this.n) : super(repaint: n);

  @override
  void paint(Canvas canvas, Size size) {
    final r = n.value;
    final rect = Rect.fromLTRB(r.left * size.width, r.top * size.height,
        r.right * size.width, r.bottom * size.height);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(path, Paint()..color = const Color(0x99000000));
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, line);
    final grid = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
    final dot = Paint()..color = Colors.white;
    for (final c in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
      canvas.drawCircle(c, 9, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) => old.n != n;
}

class EditPhotoScreen extends StatefulWidget {
  final String path;
  const EditPhotoScreen({super.key, required this.path});

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  int _filter = 0;
  int _mode = 0; // 0 filtre, 1 ayarlar, 2 kırp, 3 portre
  int _crop = 0;
  bool _saving = false;
  int _turns = 0;
  final GlobalKey _key = GlobalKey();
  final ValueNotifier<_Adj> _adj = ValueNotifier<_Adj>(const _Adj());
  final ValueNotifier<Rect> _cropN = ValueNotifier<Rect>(_fullRect);
  double? _aspect; // fotoğrafın en/boy oranı (döndürmeden)
  double? _lock; // kırpma oranı kilidi (null = serbest)
  Size? _boxSize;
  int _drag = -1;
  bool _built = false;

  double? get _rotAspect {
    final a = _aspect;
    if (a == null) return null;
    return _turns.isOdd ? 1 / a : a;
  }

  @override
  void initState() {
    super.initState();
    final stream = ResizeImage(FileImage(File(widget.path)), width: 1600)
        .resolve(ImageConfiguration.empty);
    late ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      _aspect = info.image.width / info.image.height;
      if (_built && mounted) setState(() {});
      stream.removeListener(l);
    }, onError: (e, st) {});
    stream.addListener(l);
  }

  @override
  void dispose() {
    _adj.dispose();
    _cropN.dispose();
    super.dispose();
  }

  // Filtre + ayarlar tek renk matrisinde birleşir.
  List<double> _matrix(_Adj a) {
    final c = 1 + a.contrast / 200;
    final o = a.bright * 0.6 + 128 * (1 - c);
    final cb = <double>[
      c, 0, 0, 0, o,
      0, c, 0, 0, o,
      0, 0, c, 0, o,
      0, 0, 0, 1, 0,
    ];
    final w = a.warm * 0.0015;
    final temp = <double>[
      1 + w, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1 - w, 0, 0,
      0, 0, 0, 1, 0,
    ];
    final s = _satM(1 + a.sat / 100);
    return _mulM(cb, _mulM(s, _mulM(temp, photoFilters[_filter].matrix)));
  }

  Widget _framed(_Adj a, int cacheW, Rect r, BoxConstraints cons) {
    final matrix = ColorFilter.matrix(_matrix(a));
    final asp = _aspect;
    if (asp == null) {
      return ColorFiltered(
        colorFilter: matrix,
        child: RotatedBox(
          quarterTurns: _turns,
          child: Image.file(File(widget.path), cacheWidth: cacheW),
        ),
      );
    }
    final rotA = _turns.isOdd ? 1 / asp : asp;
    final ca = r.width * rotA / r.height;
    var dw = cons.maxWidth;
    var dh = dw / ca;
    if (dh > cons.maxHeight) {
      dh = cons.maxHeight;
      dw = dh * ca;
    }
    final iw = dw / r.width;
    final ih = dh / r.height;
    final odd = _turns.isOdd;
    final img = Image.file(
      File(widget.path),
      cacheWidth: cacheW,
      width: odd ? ih : iw,
      height: odd ? iw : ih,
      fit: BoxFit.fill,
    );
    return SizedBox(
      width: dw,
      height: dh,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: iw,
          maxWidth: iw,
          minHeight: ih,
          maxHeight: ih,
          child: Transform.translate(
            offset: Offset(-r.left * iw, -r.top * ih),
            child: ColorFiltered(
              colorFilter: matrix,
              child: RotatedBox(quarterTurns: _turns, child: img),
            ),
          ),
        ),
      ),
    );
  }

  Widget _composed(_Adj a, BoxConstraints cons) {
    final r = _cropN.value;
    final sharpW = _cl(1600 / r.width, 1600, 3000).round();
    Widget content;
    if (a.blur > 0) {
      final sigma = a.blur / 100 * 14;
      final radius = 0.15 + a.focus / 100 * 0.6;
      content = Stack(
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: _framed(a, 600, r, cons),
          ),
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => RadialGradient(
              center: Alignment(a.fx, a.fy),
              radius: radius,
              colors: const [Colors.black, Colors.black, Color(0x00000000)],
              stops: const [0.0, 0.6, 1.0],
            ).createShader(rect),
            child: _framed(a, sharpW, r, cons),
          ),
        ],
      );
    } else {
      content = _framed(a, sharpW, r, cons);
    }
    if (a.vignette > 0) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.95,
                    colors: [
                      const Color(0x00000000),
                      Color.fromRGBO(0, 0, 0, a.vignette / 100 * 0.85),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return content;
  }

  void _setFocus(Offset p) {
    final size = _key.currentContext?.size;
    if (size == null || size.width == 0 || size.height == 0) return;
    final x = _cl(p.dx / size.width * 2 - 1, -1, 1);
    final y = _cl(p.dy / size.height * 2 - 1, -1, 1);
    _adj.value = _adj.value.copyWith(fx: x, fy: y);
  }

  // ---- Kırpma ----
  void _pickCrop(int i) {
    final item = _crops[i];
    final A = _rotAspect;
    setState(() {
      _crop = i;
      if (item.name == 'Orijinal') {
        _lock = null;
        _cropN.value = _fullRect;
      } else if (item.free) {
        _lock = null;
      } else if (item.ratio != null && A != null) {
        final ratio = item.ratio!;
        _lock = ratio;
        double w;
        double h;
        if (ratio > A) {
          w = 1;
          h = A / ratio;
        } else {
          h = 1;
          w = ratio / A;
        }
        _cropN.value = Rect.fromLTWH((1 - w) / 2, (1 - h) / 2, w, h);
      }
    });
  }

  void _cropStart(DragStartDetails d) {
    final s = _boxSize;
    if (s == null) return;
    final r = _cropN.value;
    final p = d.localPosition;
    final corners = [
      Offset(r.left * s.width, r.top * s.height),
      Offset(r.right * s.width, r.top * s.height),
      Offset(r.left * s.width, r.bottom * s.height),
      Offset(r.right * s.width, r.bottom * s.height),
    ];
    _drag = -1;
    for (var i = 0; i < 4; i++) {
      if ((corners[i] - p).distance < 40) {
        _drag = i;
        return;
      }
    }
    final px = Rect.fromLTRB(r.left * s.width, r.top * s.height,
        r.right * s.width, r.bottom * s.height);
    if (px.contains(p)) _drag = 4;
  }

  void _cropMove(DragUpdateDetails d) {
    final s = _boxSize;
    if (s == null || _drag < 0) return;
    final dn = Offset(d.delta.dx / s.width, d.delta.dy / s.height);
    final r = _cropN.value;
    if (_drag == 4) {
      final dx = _cl(dn.dx, -r.left, 1 - r.right);
      final dy = _cl(dn.dy, -r.top, 1 - r.bottom);
      _cropN.value = r.shift(Offset(dx, dy));
      return;
    }
    final left = _drag == 0 || _drag == 2;
    final top = _drag == 0 || _drag == 1;
    final ax = left ? r.right : r.left;
    final ay = top ? r.bottom : r.top;
    final px = (left ? r.left : r.right) + dn.dx;
    final py = (top ? r.top : r.bottom) + dn.dy;
    final sx = px >= ax ? 1.0 : -1.0;
    final sy = py >= ay ? 1.0 : -1.0;
    final maxW = sx > 0 ? 1 - ax : ax;
    final maxH = sy > 0 ? 1 - ay : ay;
    const minS = 0.08;
    var w = (px - ax).abs();
    var h = (py - ay).abs();
    final lock = _lock;
    final A = _rotAspect;
    if (lock != null && A != null) {
      w = _cl(w, minS, maxW);
      h = w * A / lock;
      if (h > maxH) {
        h = maxH;
        w = h * lock / A;
      }
    } else {
      w = _cl(w, minS, maxW);
      h = _cl(h, minS, maxH);
    }
    final l = sx > 0 ? ax : ax - w;
    final t = sy > 0 ? ay : ay - h;
    _cropN.value = Rect.fromLTWH(l, t, w, h);
  }

  Widget _cropEditor(BoxConstraints cons) {
    final base = _framed(_adj.value, 1600, _fullRect, cons);
    return Stack(
      children: [
        base,
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, bc) {
              _boxSize = Size(bc.maxWidth, bc.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _cropStart,
                onPanUpdate: _cropMove,
                child: CustomPaint(
                  painter: _CropPainter(_cropN),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _canvasArea() {
    return LayoutBuilder(
      builder: (context, cons) {
        if (_mode == 2 && _aspect != null) return _cropEditor(cons);
        return GestureDetector(
          onTapDown: _mode == 3 ? (d) => _setFocus(d.localPosition) : null,
          onPanUpdate: _mode == 3 ? (d) => _setFocus(d.localPosition) : null,
          child: RepaintBoundary(
            key: _key,
            child: ValueListenableBuilder<_Adj>(
              valueListenable: _adj,
              builder: (context, a, _) => _composed(a, cons),
            ),
          ),
        );
      },
    );
  }

  void _resetAll() {
    setState(() {
      _adj.value = const _Adj();
      _filter = 0;
      _crop = 0;
      _turns = 0;
      _lock = null;
      _cropN.value = _fullRect;
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_key.currentContext == null) {
      setState(() => _mode = 0);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await Gal.putImageBytes(data!.buffer.asUint8List(), album: 'EditPro');
      _snack('Galeriye kaydedildi');
    } catch (e) {
      _snack('Kaydedilemedi');
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _cropStrip() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _crops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final selected = i == _crop;
          return Center(
            child: GestureDetector(
              onTap: () => _pickCrop(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: selected ? null : AppColors.card,
                  gradient: selected ? appGradient : null,
                ),
                child: Text(_crops[i].name),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterStrip() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: photoFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final selected = i == _filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = i),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(photoFilters[i].matrix),
                      child: Image.file(File(widget.path),
                          fit: BoxFit.cover, cacheWidth: 150),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(photoFilters[i].name, style: const TextStyle(fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }

  // Tek bir kaydırıcı satırı. Sayıya dokununca o ayar sıfırlanır.
  Widget _row({
    required String label,
    required double value,
    required double min,
    required double max,
    required double zero,
    required bool centered,
    required ValueChanged<double> onChanged,
  }) {
    final isZero = value.round() == zero.round();
    final sign = centered && value.round() > 0 ? '+' : '';
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(width: 84, child: Text(label)),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (centered)
                  Container(width: 2, height: 16, color: Colors.white54),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor:
                        centered ? const Color(0xFF2A3570) : AppColors.blue,
                    inactiveTrackColor: const Color(0xFF2A3570),
                    thumbColor: AppColors.blue,
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    onChanged: (v) {
                      var r = v.roundToDouble();
                      if ((r - zero).abs() < 4) r = zero;
                      onChanged(r);
                    },
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(zero),
            child: SizedBox(
              width: 52,
              child: Text(
                '$sign${value.round()}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isZero ? AppColors.textDim : AppColors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adjustPanel() {
    return SizedBox(
      height: 176,
      child: ValueListenableBuilder<_Adj>(
        valueListenable: _adj,
        builder: (context, a, _) {
          return ListView(
            children: [
              _row(
                label: 'Parlaklık',
                value: a.bright,
                min: -100,
                max: 100,
                zero: 0,
                centered: true,
                onChanged: (v) => _adj.value = a.copyWith(bright: v),
              ),
              _row(
                label: 'Kontrast',
                value: a.contrast,
                min: -100,
                max: 100,
                zero: 0,
                centered: true,
                onChanged: (v) => _adj.value = a.copyWith(contrast: v),
              ),
              _row(
                label: 'Doygunluk',
                value: a.sat,
                min: -100,
                max: 100,
                zero: 0,
                centered: true,
                onChanged: (v) => _adj.value = a.copyWith(sat: v),
              ),
              _row(
                label: 'Sıcaklık',
                value: a.warm,
                min: -100,
                max: 100,
                zero: 0,
                centered: true,
                onChanged: (v) => _adj.value = a.copyWith(warm: v),
              ),
              _row(
                label: 'Vinyet',
                value: a.vignette,
                min: 0,
                max: 100,
                zero: 0,
                centered: false,
                onChanged: (v) => _adj.value = a.copyWith(vignette: v),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _portraitPanel() {
    return SizedBox(
      height: 176,
      child: ValueListenableBuilder<_Adj>(
        valueListenable: _adj,
        builder: (context, a, _) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Fotoğrafa dokun veya sürükle: odak noktası',
                  style: TextStyle(fontSize: 12, color: AppColors.textDim),
                ),
              ),
              _row(
                label: 'Bulanıklık',
                value: a.blur,
                min: 0,
                max: 100,
                zero: 0,
                centered: false,
                onChanged: (v) => _adj.value = a.copyWith(blur: v),
              ),
              _row(
                label: 'Odak alanı',
                value: a.focus,
                min: 0,
                max: 100,
                zero: 50,
                centered: false,
                onChanged: (v) => _adj.value = a.copyWith(focus: v),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap, bool active) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: active ? AppColors.blue : Colors.white),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: active ? AppColors.blue : Colors.white)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _built = true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotoğraf Düzenle'),
        backgroundColor: AppColors.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(child: _canvasArea()),
            ),
            _mode == 0
                ? _filterStrip()
                : _mode == 1
                    ? _adjustPanel()
                    : _mode == 2
                        ? _cropStrip()
                        : _portraitPanel(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _tool(Icons.crop, 'Kırp',
                    () => setState(() => _mode = 2), _mode == 2),
                _tool(Icons.rotate_right, 'Döndür',
                    () => setState(() {
                          _turns = (_turns + 1) % 4;
                          _cropN.value = _fullRect;
                          _crop = 0;
                          _lock = null;
                        }),
                    false),
                _tool(Icons.filter_vintage_outlined, 'Filtre',
                    () => setState(() => _mode = 0), _mode == 0),
                _tool(Icons.tune, 'Ayarlar',
                    () => setState(() => _mode = 1), _mode == 1),
                _tool(Icons.blur_on, 'Portre',
                    () => setState(() => _mode = 3), _mode == 3),
                _tool(Icons.restart_alt, 'Sıfırla', _resetAll, false),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
