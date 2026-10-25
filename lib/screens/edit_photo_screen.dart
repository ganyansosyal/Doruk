import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
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

class _FrameItem {
  final String name;
  final Color color;
  final double pad; // kısa kenarın oranı
  final bool square; // 1:1 Instagram tarzı
  const _FrameItem(this.name, this.color, this.pad, this.square);
}

const List<_FrameItem> _frames = [
  _FrameItem('Yok', Colors.white, 0, false),
  _FrameItem('İnce beyaz', Colors.white, 0.02, false),
  _FrameItem('Kalın beyaz', Colors.white, 0.06, false),
  _FrameItem('Siyah', Colors.black, 0.04, false),
  _FrameItem('1:1 Beyaz', Colors.white, 0.04, true),
  _FrameItem('1:1 Siyah', Colors.black, 0.04, true),
];

const List<String> _fontNames = ['Normal', 'Serif', 'Mono', 'El yazısı'];
const List<String?> _fontFamilies = [null, 'serif', 'monospace', 'cursive'];

const List<Color> _palette = [
  Colors.white,
  Colors.black,
  Color(0xFFFFC107),
  Color(0xFFEF4444),
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
];

// Fotoğrafın üstündeki bir yazı. x, y: 0..1 arası konum.
class _TextItem {
  final String text;
  final Color color;
  final int font;
  final double x;
  final double y;
  final double size; // genişliğin oranı
  const _TextItem({
    required this.text,
    this.color = Colors.white,
    this.font = 0,
    this.x = 0.5,
    this.y = 0.5,
    this.size = 0.08,
  });

  _TextItem copyWith({
    String? text,
    Color? color,
    int? font,
    double? x,
    double? y,
    double? size,
  }) {
    return _TextItem(
      text: text ?? this.text,
      color: color ?? this.color,
      font: font ?? this.font,
      x: x ?? this.x,
      y: y ?? this.y,
      size: size ?? this.size,
    );
  }
}

// Tüm ayarlar tek yerde. 0 = değişiklik yok.
class _Adj {
  final double bright; // -100..100
  final double contrast; // -100..100
  final double sat; // -100..100
  final double warm; // -100..100
  final double vignette; // 0..100
  final double sharp; // 0..100 keskinlik
  final double shadow; // -100..100 gölge
  final double highlight; // -100..100 parlak alan
  final double fi; // 0..100 filtre yoğunluğu
  final double blur; // 0..100
  final double focus; // 0..100 (odak alanı büyüklüğü)
  final double fx; // -1..1 odak noktası
  final double fy; // -1..1
  final double angle; // -15..15 derece (açı düzeltme)
  final bool auto; // portre: kişiyi otomatik bul
  const _Adj({
    this.bright = 0,
    this.contrast = 0,
    this.sat = 0,
    this.warm = 0,
    this.vignette = 0,
    this.sharp = 0,
    this.shadow = 0,
    this.highlight = 0,
    this.fi = 100,
    this.blur = 0,
    this.focus = 50,
    this.fx = 0,
    this.fy = 0,
    this.angle = 0,
    this.auto = false,
  });

  _Adj copyWith({
    double? bright,
    double? contrast,
    double? sat,
    double? warm,
    double? vignette,
    double? sharp,
    double? shadow,
    double? highlight,
    double? fi,
    double? blur,
    double? focus,
    double? fx,
    double? fy,
    double? angle,
    bool? auto,
  }) {
    return _Adj(
      bright: bright ?? this.bright,
      contrast: contrast ?? this.contrast,
      sat: sat ?? this.sat,
      warm: warm ?? this.warm,
      vignette: vignette ?? this.vignette,
      sharp: sharp ?? this.sharp,
      shadow: shadow ?? this.shadow,
      highlight: highlight ?? this.highlight,
      fi: fi ?? this.fi,
      blur: blur ?? this.blur,
      focus: focus ?? this.focus,
      fx: fx ?? this.fx,
      fy: fy ?? this.fy,
      angle: angle ?? this.angle,
      auto: auto ?? this.auto,
    );
  }
}

const List<String> _emojis = [
  '😀', '😂', '😍', '🥰', '😎', '🤩', '😭', '😡', '👍', '👏',
  '🙏', '💪', '🔥', '✨', '⭐', '❤️', '💜', '💙', '🎉', '🎈',
  '🌸', '🌈', '☀️', '🌙', '🍕', '🎵', '📸', '👑', '💎', '🦋',
];

// Parmakla çizilen bir çizgi. Noktalar 0..1 arası.
class _Stroke {
  final List<Offset> pts;
  final Color color;
  final double width; // genişliğin oranı
  _Stroke(this.pts, this.color, this.width);
}

class _StrokePainter extends CustomPainter {
  final List<_Stroke> Function() get;
  _StrokePainter(this.get, Listenable tick) : super(repaint: tick);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in get()) {
      final w = s.width * size.width;
      if (s.pts.length == 1) {
        canvas.drawCircle(
          Offset(s.pts[0].dx * size.width, s.pts[0].dy * size.height),
          w / 2,
          Paint()..color = s.color,
        );
        continue;
      }
      final path = Path()
        ..moveTo(s.pts[0].dx * size.width, s.pts[0].dy * size.height);
      for (var i = 1; i < s.pts.length; i++) {
        path.lineTo(s.pts[i].dx * size.width, s.pts[i].dy * size.height);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = w,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) => true;
}

// Geri al / ileri al için tüm durumun kopyası.
class _Snap {
  final _Adj adj;
  final int filter;
  final int turns;
  final int crop;
  final int frame;
  final Rect cropN;
  final double? lock;
  final bool fh;
  final bool fv;
  final List<_TextItem> texts;
  final List<_Stroke> strokes;
  const _Snap(this.adj, this.filter, this.turns, this.crop, this.frame,
      this.cropN, this.lock, this.fh, this.fv, this.texts, this.strokes);
}

const List<double> _idM = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

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

// Keskinlik + gölge + parlak alan. Arka planda (isolate) çalışır.
// a: [rgba bytes, genişlik, yükseklik, keskinlik, gölge, parlak alan]
Uint8List _process(List<Object> a) {
  final src = a[0] as Uint8List;
  final w = a[1] as int;
  final h = a[2] as int;
  final k = (a[3] as double) / 100;
  final sh = (a[4] as double) / 100;
  final hi = (a[5] as double) / 100;
  final out = Uint8List(src.length);
  final stride = w * 4;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * stride + x * 4;
      final inner = k > 0 && x > 0 && y > 0 && x < w - 1 && y < h - 1;
      final lum =
          (src[i] * 0.2126 + src[i + 1] * 0.7152 + src[i + 2] * 0.0722) / 255;
      final ds = 1 - lum;
      final add = sh * ds * ds * 70 + hi * lum * lum * 70;
      for (var c = 0; c < 3; c++) {
        var v = src[i + c].toDouble();
        if (inner) {
          v = v * (1 + 4 * k) -
              k *
                  (src[i + c - 4] +
                      src[i + c + 4] +
                      src[i + c - stride] +
                      src[i + c + stride]);
        }
        v += add;
        out[i + c] = v < 0 ? 0 : (v > 255 ? 255 : v.round());
      }
      out[i + 3] = src[i + 3];
    }
  }
  return out;
}

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
      canvas.drawCircle(c, 11, dot);
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
  // 0 filtre, 1 ayarlar, 2 kırp, 3 portre, 4 çerçeve, 5 yazı
  int _mode = 0;
  int _crop = 0;
  int _frame = 0;
  bool _saving = false;
  int _turns = 0;
  bool _fh = false; // ayna (yatay çevir)
  bool _fv = false; // dikey çevir
  final GlobalKey _key = GlobalKey();
  final ValueNotifier<_Adj> _adj = ValueNotifier<_Adj>(const _Adj());
  final ValueNotifier<Rect> _cropN = ValueNotifier<Rect>(_fullRect);
  final ValueNotifier<List<_TextItem>> _txt =
      ValueNotifier<List<_TextItem>>(const <_TextItem>[]);
  final ValueNotifier<bool> _orig = ValueNotifier<bool>(false);
  final ValueNotifier<int> _histV = ValueNotifier<int>(0);
  final TextEditingController _tc = TextEditingController();
  final List<_Snap> _undo = [];
  final List<_Snap> _redo = [];
  int _sel = -1; // seçili yazı / çıkartma
  List<_Stroke> _strokes = <_Stroke>[];
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  final ValueNotifier<double> _penW = ValueNotifier<double>(0.012);
  Color _penColor = Colors.white;
  ui.Image? _mask; // kişi maskesi (alfa = kişi olasılığı)
  bool _segBusy = false;
  double? _aspect; // fotoğrafın en/boy oranı (döndürmeden)
  double? _lock; // kırpma oranı kilidi (null = serbest)
  Size? _boxSize;
  int _drag = -1;
  bool _built = false;

  // Keskinlik / gölge / parlak alan için işlenmiş önizleme
  ui.Image? _procImg;
  Uint8List? _base;
  int _bw = 0;
  int _bh = 0;
  int _procId = 0;

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
    _txt.dispose();
    _orig.dispose();
    _histV.dispose();
    _tick.dispose();
    _penW.dispose();
    _tc.dispose();
    super.dispose();
  }

  // ---- Geri al / ileri al ----
  _Snap _snap() => _Snap(_adj.value, _filter, _turns, _crop, _frame,
      _cropN.value, _lock, _fh, _fv, _txt.value, List<_Stroke>.of(_strokes));

  void _checkpoint() {
    _undo.add(_snap());
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
    _histV.value++;
  }

  void _restore(_Snap s) {
    setState(() {
      _filter = s.filter;
      _turns = s.turns;
      _crop = s.crop;
      _frame = s.frame;
      _lock = s.lock;
      _fh = s.fh;
      _fv = s.fv;
      _sel = -1;
      _strokes = List<_Stroke>.of(s.strokes);
    });
    _tick.value++;
    _adj.value = s.adj;
    _cropN.value = s.cropN;
    _txt.value = s.texts;
    _tc.clear();
    _runProc();
  }

  void _undoDo() {
    if (_undo.isEmpty) return;
    _redo.add(_snap());
    _restore(_undo.removeLast());
    _histV.value++;
  }

  void _redoDo() {
    if (_redo.isEmpty) return;
    _undo.add(_snap());
    _restore(_redo.removeLast());
    _histV.value++;
  }

  // ---- Keskinlik / gölge / parlak alan işleme ----
  Future<void> _runProc() async {
    final a = _adj.value;
    final id = ++_procId;
    if (a.sharp == 0 && a.shadow == 0 && a.highlight == 0) {
      if (_procImg != null && mounted) setState(() => _procImg = null);
      return;
    }
    try {
      if (_base == null) {
        final bytes = await File(widget.path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
        final frame = await codec.getNextFrame();
        final img = frame.image;
        final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        _bw = img.width;
        _bh = img.height;
        img.dispose();
        codec.dispose();
        _base = data!.buffer.asUint8List();
      }
      final out = await compute(_process, <Object>[
        _base!,
        _bw,
        _bh,
        a.sharp,
        a.shadow,
        a.highlight,
      ]);
      if (id != _procId || !mounted) return;
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(
          out, _bw, _bh, ui.PixelFormat.rgba8888, c.complete);
      final im = await c.future;
      if (id != _procId || !mounted) return;
      setState(() => _procImg = im);
    } catch (e) {
      // işleme başarısız olursa orijinal görüntü kalır
    }
  }

  // Filtre (yoğunluğa göre) + ayarlar tek renk matrisinde birleşir.
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
    final f = photoFilters[_filter].matrix;
    final t = a.fi / 100;
    final fm = List<double>.generate(20, (i) => _idM[i] + (f[i] - _idM[i]) * t);
    return _mulM(cb, _mulM(s, _mulM(temp, fm)));
  }

  Widget _framed(_Adj a, int cacheW, Rect r, BoxConstraints cons,
      {bool person = false}) {
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
    final proc = _procImg;
    final bw = odd ? ih : iw;
    final bh = odd ? iw : ih;
    Widget mk(int cw) => proc != null
        ? RawImage(image: proc, width: bw, height: bh, fit: BoxFit.fill)
        : Image.file(
            File(widget.path),
            cacheWidth: cw,
            width: bw,
            height: bh,
            fit: BoxFit.fill,
          );
    final mask = _mask;
    Widget img;
    if (person && mask != null && a.blur > 0) {
      final sigma = a.blur / 100 * 14;
      img = Stack(
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
                sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror),
            child: mk(600),
          ),
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) {
              final m = Float64List(16);
              m[0] = rect.width / mask.width;
              m[5] = rect.height / mask.height;
              m[10] = 1;
              m[15] = 1;
              return ui.ImageShader(
                mask,
                TileMode.clamp,
                TileMode.clamp,
                m,
                filterQuality: FilterQuality.medium,
              );
            },
            child: mk(cacheW),
          ),
        ],
      );
    } else {
      img = mk(cacheW);
    }
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
    final fr = _frames[_frame];
    final short =
        cons.maxWidth < cons.maxHeight ? cons.maxWidth : cons.maxHeight;
    final pad = fr.pad * short;
    final BoxConstraints inner = fr.square
        ? BoxConstraints.loose(Size(short - 2 * pad, short - 2 * pad))
        : cons.deflate(EdgeInsets.all(pad));
    final sharpW = _cl(1600 / r.width, 1600, 3000).round();
    Widget content;
    if (a.blur > 0 && a.auto && _mask != null) {
      content = _framed(a, sharpW, r, inner, person: true);
    } else if (a.blur > 0) {
      final sigma = a.blur / 100 * 14;
      final radius = 0.15 + a.focus / 100 * 0.6;
      content = Stack(
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
                sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror),
            child: _framed(a, 600, r, inner),
          ),
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => RadialGradient(
              center: Alignment(a.fx, a.fy),
              radius: radius,
              colors: const [Colors.black, Colors.black, Color(0x00000000)],
              stops: const [0.0, 0.6, 1.0],
            ).createShader(rect),
            child: _framed(a, sharpW, r, inner),
          ),
        ],
      );
    } else {
      content = _framed(a, sharpW, r, inner);
    }
    final ra = _rotAspect;
    if (a.angle != 0 && ra != null) {
      final rad = a.angle * math.pi / 180;
      final ar = r.width * ra / r.height;
      final big = ar > 1 ? ar : 1 / ar;
      final sc = math.cos(rad).abs() + math.sin(rad).abs() * big;
      content = ClipRect(
        child: Transform.rotate(
          angle: rad,
          child: Transform.scale(scale: sc, child: content),
        ),
      );
    }
    if (_fh || _fv) {
      content = Transform.flip(flipX: _fh, flipY: _fv, child: content);
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
    if (fr.pad > 0) {
      if (fr.square) {
        content = Container(
          width: short,
          height: short,
          color: fr.color,
          alignment: Alignment.center,
          child: content,
        );
      } else {
        content = Container(
          color: fr.color,
          padding: EdgeInsets.all(pad),
          child: content,
        );
      }
    }
    if (_mode == 7 || _strokes.isNotEmpty) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _StrokePainter(() => _strokes, _tick)),
            ),
          ),
        ],
      );
    }
    final texts = _txt.value;
    if (texts.isNotEmpty) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, bc) {
                  return Stack(
                    children: [
                      for (final t in texts)
                        if (t.text.isNotEmpty)
                          Align(
                            alignment: Alignment(t.x * 2 - 1, t.y * 2 - 1),
                            child: Text(
                              t.text,
                              style: TextStyle(
                                color: t.color,
                                fontFamily: _fontFamilies[t.font],
                                fontSize: t.size * bc.maxWidth,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                    ],
                  );
                },
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

  void _moveText(Offset p) {
    final size = _key.currentContext?.size;
    if (size == null || size.width == 0 || size.height == 0) return;
    final list = _txt.value;
    if (_sel < 0 || _sel >= list.length) return;
    final x = _cl(p.dx / size.width, 0, 1);
    final y = _cl(p.dy / size.height, 0, 1);
    final l = List<_TextItem>.of(list);
    l[_sel] = l[_sel].copyWith(x: x, y: y);
    _txt.value = l;
  }

  // ---- Kırpma ----
  void _pickCrop(int i) {
    final item = _crops[i];
    final A = _rotAspect;
    _checkpoint();
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
      if ((corners[i] - p).distance < 56) {
        _drag = i;
        _checkpoint();
        return;
      }
    }
    final px = Rect.fromLTRB(r.left * s.width, r.top * s.height,
        r.right * s.width, r.bottom * s.height);
    if (px.contains(p)) {
      _drag = 4;
      _checkpoint();
    }
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
        final void Function(Offset)? tap = _mode == 3
            ? (_adj.value.auto ? null : _setFocus)
            : (_mode == 5 || _mode == 6 ? _moveText : null);
        final bool draw = _mode == 7;
        return GestureDetector(
          onTapDown: tap == null
              ? null
              : (d) {
                  _checkpoint();
                  tap(d.localPosition);
                },
          onPanStart: draw
              ? _drawStart
              : (tap == null ? null : (DragStartDetails d) => _checkpoint()),
          onPanUpdate: draw
              ? _drawMove
              : (tap == null
                  ? null
                  : (DragUpdateDetails d) => tap(d.localPosition)),
          child: RepaintBoundary(
            key: _key,
            child: ListenableBuilder(
              listenable: Listenable.merge([_adj, _txt, _orig]),
              builder: (context, _) {
                if (_orig.value) {
                  return Image.file(File(widget.path), cacheWidth: 1600);
                }
                return _composed(_adj.value, cons);
              },
            ),
          ),
        );
      },
    );
  }

  void _resetAll() {
    _checkpoint();
    setState(() {
      _adj.value = const _Adj();
      _filter = 0;
      _crop = 0;
      _frame = 0;
      _turns = 0;
      _fh = false;
      _fv = false;
      _lock = null;
      _sel = -1;
      _cropN.value = _fullRect;
      _txt.value = const <_TextItem>[];
      _strokes = <_Stroke>[];
    });
    _tick.value++;
    _tc.clear();
    _runProc();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_key.currentContext == null || _mode == 2) {
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

  // Yatay kaydırmalı seçenek düğmeleri (kırp, çerçeve, yazı tipi...).
  Widget _chips(List<String> names, int selected, ValueChanged<int> onTap,
      {double height = 110}) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: names.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final isSel = i == selected;
          return Center(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSel ? null : AppColors.card,
                  gradient: isSel ? appGradient : null,
                ),
                child: Text(names[i]),
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
            onTap: () {
              if (i == _filter) return;
              _checkpoint();
              setState(() => _filter = i);
            },
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

  // Filtre şeridi + filtre yoğunluğu (%0-100)
  Widget _filterPanel() {
    return SizedBox(
      height: 156,
      child: Column(
        children: [
          _filterStrip(),
          if (_filter != 0)
            ValueListenableBuilder<_Adj>(
              valueListenable: _adj,
              builder: (context, a, _) => _row(
                label: 'Yoğunluk',
                value: a.fi,
                min: 0,
                max: 100,
                zero: 100,
                centered: false,
                onStart: _checkpoint,
                onChanged: (v) => _adj.value = _adj.value.copyWith(fi: v),
              ),
            )
          else
            const SizedBox(height: 44),
        ],
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
    VoidCallback? onStart,
    VoidCallback? onEnd,
    double snap = 4,
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
                    value: _cl(value, min, max),
                    min: min,
                    max: max,
                    onChangeStart: (_) => onStart?.call(),
                    onChangeEnd: (_) => onEnd?.call(),
                    onChanged: (v) {
                      var r = v.roundToDouble();
                      if ((r - zero).abs() < snap) r = zero;
                      onChanged(r);
                    },
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              onStart?.call();
              onChanged(zero);
              onEnd?.call();
            },
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

  Widget _adjRow(
    String label,
    double value,
    double min,
    _Adj Function(_Adj a, double v) set, {
    bool centered = true,
    bool proc = false,
    double max = 100,
    double snap = 4,
  }) {
    return _row(
      label: label,
      value: value,
      min: min,
      max: max,
      zero: 0,
      snap: snap,
      centered: centered,
      onStart: _checkpoint,
      onEnd: proc ? _runProc : null,
      onChanged: (v) => _adj.value = set(_adj.value, v),
    );
  }

  Widget _adjustPanel() {
    return SizedBox(
      height: 188,
      child: ValueListenableBuilder<_Adj>(
        valueListenable: _adj,
        builder: (context, a, _) {
          return ListView(
            children: [
              _adjRow('Açı', a.angle, -15, (x, v) => x.copyWith(angle: v),
                  max: 15, snap: 1),
              _adjRow('Parlaklık', a.bright, -100,
                  (x, v) => x.copyWith(bright: v)),
              _adjRow('Kontrast', a.contrast, -100,
                  (x, v) => x.copyWith(contrast: v)),
              _adjRow('Doygunluk', a.sat, -100, (x, v) => x.copyWith(sat: v)),
              _adjRow('Sıcaklık', a.warm, -100, (x, v) => x.copyWith(warm: v)),
              _adjRow('Gölge', a.shadow, -100,
                  (x, v) => x.copyWith(shadow: v),
                  proc: true),
              _adjRow('Parlak alan', a.highlight, -100,
                  (x, v) => x.copyWith(highlight: v),
                  proc: true),
              _adjRow('Keskinlik', a.sharp, 0,
                  (x, v) => x.copyWith(sharp: v),
                  centered: false, proc: true),
              _adjRow('Vinyet', a.vignette, 0,
                  (x, v) => x.copyWith(vignette: v),
                  centered: false),
            ],
          );
        },
      ),
    );
  }

  // Kişiyi ML Kit ile bulup maske çıkarır.
  Future<void> _segment() async {
    setState(() => _segBusy = true);
    var ok = false;
    var stage = 'baslangic';
    var err = 'maske bos geldi';
    try {
      stage = 'dosya okuma';
      final bytes = await File(widget.path).readAsBytes();
      stage = 'kucultme';
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 640);
      final fr = await codec.getNextFrame();
      final small = fr.image;
      stage = 'png';
      final png = await small.toByteData(format: ui.ImageByteFormat.png);
      small.dispose();
      codec.dispose();
      stage = 'gecici dosya';
      final f = File('${Directory.systemTemp.path}/seg.png');
      await f.writeAsBytes(png!.buffer.asUint8List());
      SegmentationMask? m;
      stage = 'ML Kit';
      // Olmazsa farklı ayarlarla tekrar dene
      for (final cfg in const [
        [SegmenterMode.single, false],
        [SegmenterMode.single, true],
        [SegmenterMode.stream, true],
      ]) {
        try {
          final seg = SelfieSegmenter(
            mode: cfg[0] as SegmenterMode,
            enableRawSizeMask: cfg[1] as bool,
          );
          m = await seg.processImage(InputImage.fromFilePath(f.path));
          await seg.close();
          if (m != null) break;
        } catch (e) {
          err = 'ML Kit hatasi: $e';
        }
      }
      if (m != null && m.confidences.length != m.width * m.height) {
        err = 'maske boyutu ${m.confidences.length} / ${m.width}x${m.height}';
      }
      if (m != null && m.confidences.length == m.width * m.height) {
        stage = 'maske resmi';
        final px = Uint8List(m.width * m.height * 4);
        for (var i = 0; i < m.confidences.length; i++) {
          final t = ((m.confidences[i] - 0.3) / 0.4).clamp(0.0, 1.0).toDouble();
          px[i * 4] = 255;
          px[i * 4 + 1] = 255;
          px[i * 4 + 2] = 255;
          px[i * 4 + 3] = (t * t * (3 - 2 * t) * 255).round();
        }
        final c = Completer<ui.Image>();
        ui.decodeImageFromPixels(
            px, m.width, m.height, ui.PixelFormat.rgba8888, c.complete);
        final im = await c.future;
        if (mounted) _mask = im;
        ok = true;
      }
    } catch (e) {
      ok = false;
      err = '$e';
    }
    if (!mounted) return;
    if (!ok) {
      _adj.value = _adj.value.copyWith(auto: false);
      final msg = 'Aşama: $stage\n$err';
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kişi bulunamadı'),
          content: SelectableText(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
    setState(() => _segBusy = false);
  }

  Widget _portraitPanel() {
    return SizedBox(
      height: 200,
      child: ValueListenableBuilder<_Adj>(
        valueListenable: _adj,
        builder: (context, a, _) {
          final hint = !a.auto
              ? 'Fotoğrafa dokun veya sürükle: odak noktası'
              : (_segBusy
                  ? 'Kişi aranıyor...'
                  : 'Kişi otomatik bulundu, arka plan bulanıklaşır');
          return Column(
            children: [
              _chips(
                const ['Elle odak', 'Otomatik (kişi)'],
                a.auto ? 1 : 0,
                (i) {
                  _checkpoint();
                  if (i == 1) {
                    _adj.value = _adj.value
                        .copyWith(auto: true, blur: a.blur == 0 ? 50 : a.blur);
                    if (_mask == null && !_segBusy) _segment();
                  } else {
                    _adj.value = _adj.value.copyWith(auto: false);
                  }
                },
                height: 56,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hint,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textDim),
                  ),
                ),
              ),
              _row(
                label: 'Bulanıklık',
                value: a.blur,
                min: 0,
                max: 100,
                zero: 0,
                centered: false,
                onStart: _checkpoint,
                onChanged: (v) => _adj.value = _adj.value.copyWith(blur: v),
              ),
              if (!a.auto)
                _row(
                  label: 'Odak alanı',
                  value: a.focus,
                  min: 0,
                  max: 100,
                  zero: 50,
                  centered: false,
                  onStart: _checkpoint,
                  onChanged: (v) => _adj.value = _adj.value.copyWith(focus: v),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _framePanel() {
    return _chips(
      [for (final f in _frames) f.name],
      _frame,
      (i) {
        if (i == _frame) return;
        _checkpoint();
        setState(() => _frame = i);
      },
      height: 110,
    );
  }

  // ---- Yazı ekle ----
  void _upd(_TextItem Function(_TextItem) f) {
    final list = _txt.value;
    if (_sel < 0 || _sel >= list.length) return;
    final l = List<_TextItem>.of(list);
    l[_sel] = f(l[_sel]);
    _txt.value = l;
  }

  void _addText() {
    _checkpoint();
    final l = List<_TextItem>.of(_txt.value)..add(const _TextItem(text: 'Yazı'));
    _txt.value = l;
    _tc.text = 'Yazı';
    setState(() => _sel = l.length - 1);
  }

  // Yazıyı pencerede düzenle (klavye ekranı kaydırmasın diye)
  Future<void> _editTextDialog() async {
    final list = _txt.value;
    if (_sel < 0 || _sel >= list.length) return;
    _checkpoint();
    final c = TextEditingController(text: list[_sel].text);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yazı'),
        content: TextField(
          controller: c,
          autofocus: true,
          onChanged: (v) => _upd((t) => t.copyWith(text: v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
    final l = _txt.value;
    if (_sel >= 0 && _sel < l.length) _tc.text = l[_sel].text;
  }

  void _deleteText() {
    final list = _txt.value;
    if (_sel < 0 || _sel >= list.length) return;
    _checkpoint();
    final l = List<_TextItem>.of(list)..removeAt(_sel);
    _txt.value = l;
    _tc.clear();
    setState(() => _sel = -1);
  }

  Widget _textPanel() {
    return SizedBox(
      height: 236,
      child: ValueListenableBuilder<List<_TextItem>>(
        valueListenable: _txt,
        builder: (context, list, _) {
          final has = _sel >= 0 && _sel < list.length;
          final cur = has ? list[_sel] : null;
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tc,
                        enabled: has,
                        readOnly: true,
                        onTap: _editTextDialog,
                        decoration: InputDecoration(
                          hintText: has ? 'Yazıyı değiştirmek için dokun' : 'Önce Ekle\'ye bas',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _addText,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: appGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Ekle'),
                      ),
                    ),
                    if (has)
                      GestureDetector(
                        onTap: _deleteText,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.delete_outline),
                        ),
                      ),
                  ],
                ),
              ),
              if (list.isNotEmpty)
                _chips(
                  [for (final t in list) t.text.isEmpty ? '(boş)' : t.text],
                  _sel,
                  (i) {
                    _tc.text = list[i].text;
                    setState(() => _sel = i);
                  },
                  height: 44,
                ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _palette.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final c = _palette[i];
                    final isSel = cur != null && cur.color == c;
                    return Center(
                      child: GestureDetector(
                        onTap: () {
                          if (!has) return;
                          _checkpoint();
                          _upd((t) => t.copyWith(color: c));
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? AppColors.blue : Colors.white24,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _chips(
                _fontNames,
                cur?.font ?? -1,
                (i) {
                  if (!has) return;
                  _checkpoint();
                  _upd((t) => t.copyWith(font: i));
                },
                height: 48,
              ),
              _row(
                label: 'Boyut',
                value: (cur?.size ?? 0.08) * 100,
                min: 3,
                max: 25,
                zero: -1000,
                centered: false,
                onStart: _checkpoint,
                onChanged: (v) => _upd((t) => t.copyWith(size: v / 100)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---- Çıkartma / emoji ----
  void _addSticker(String e) {
    _checkpoint();
    final l = List<_TextItem>.of(_txt.value)
      ..add(_TextItem(text: e, size: 0.2));
    _txt.value = l;
    setState(() => _sel = l.length - 1);
  }

  Widget _stickerPanel() {
    return SizedBox(
      height: 232,
      child: ValueListenableBuilder<List<_TextItem>>(
        valueListenable: _txt,
        builder: (context, list, _) {
          final has = _sel >= 0 && _sel < list.length;
          final cur = has ? list[_sel] : null;
          return ListView(
            children: [
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _emojis.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _addSticker(_emojis[i]),
                    child: Center(
                      child:
                          Text(_emojis[i], style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
              ),
              if (list.isNotEmpty)
                _chips(
                  [for (final t in list) t.text.isEmpty ? '(boş)' : t.text],
                  _sel,
                  (i) => setState(() => _sel = i),
                  height: 48,
                ),
              _row(
                label: 'Boyut',
                value: (cur?.size ?? 0.2) * 100,
                min: 4,
                max: 50,
                zero: -1000,
                centered: false,
                onStart: _checkpoint,
                onChanged: (v) => _upd((t) => t.copyWith(size: v / 100)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Seçili olanın yerini değiştirmek için fotoğrafa dokun veya sürükle',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textDim),
                      ),
                    ),
                    if (has)
                      GestureDetector(
                        onTap: _deleteText,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.delete_outline),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---- Çizim ----
  Offset? _norm(Offset p) {
    final size = _key.currentContext?.size;
    if (size == null || size.width == 0 || size.height == 0) return null;
    return Offset(p.dx / size.width, p.dy / size.height);
  }

  void _drawStart(DragStartDetails d) {
    final n = _norm(d.localPosition);
    if (n == null) return;
    _checkpoint();
    _strokes.add(_Stroke([n], _penColor, _penW.value));
    _tick.value++;
  }

  void _drawMove(DragUpdateDetails d) {
    final n = _norm(d.localPosition);
    if (n == null || _strokes.isEmpty) return;
    _strokes.last.pts.add(n);
    _tick.value++;
  }

  void _clearStrokes() {
    if (_strokes.isEmpty) return;
    _checkpoint();
    setState(() => _strokes = <_Stroke>[]);
    _tick.value++;
  }

  Widget _drawPanel() {
    return SizedBox(
      height: 176,
      child: ValueListenableBuilder<double>(
        valueListenable: _penW,
        builder: (context, w, _) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Fotoğraf üstüne parmakla çiz',
                  style: TextStyle(fontSize: 12, color: AppColors.textDim),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _palette.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final c = _palette[i];
                    return Center(
                      child: GestureDetector(
                        onTap: () => setState(() => _penColor = c),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _penColor == c
                                  ? AppColors.blue
                                  : Colors.white24,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _row(
                label: 'Kalınlık',
                value: w * 500,
                min: 1,
                max: 20,
                zero: -1000,
                centered: false,
                onChanged: (v) => _penW.value = v / 500,
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _clearStrokes,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 6),
                      Text('Çizimleri temizle', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _panel() {
    switch (_mode) {
      case 0:
        return _filterPanel();
      case 1:
        return _adjustPanel();
      case 2:
        return _chips([for (final c in _crops) c.name], _crop, _pickCrop);
      case 3:
        return _portraitPanel();
      case 4:
        return _framePanel();
      case 5:
        return _textPanel();
      case 6:
        return _stickerPanel();
      default:
        return _drawPanel();
    }
  }

  Widget _hbtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: onTap == null ? Colors.white24 : Colors.white),
      ),
    );
  }

  // Geri al, ileri al, önce/sonra (basılı tut)
  Widget _historyBar() {
    return SizedBox(
      height: 44,
      child: ValueListenableBuilder<int>(
        valueListenable: _histV,
        builder: (context, _, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _hbtn(Icons.undo, _undo.isNotEmpty ? _undoDo : null),
              _hbtn(Icons.redo, _redo.isNotEmpty ? _redoDo : null),
              const SizedBox(width: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _orig.value = true,
                onTapUp: (_) => _orig.value = false,
                onTapCancel: () => _orig.value = false,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.compare, size: 22),
                      SizedBox(width: 6),
                      Text('Önce/Sonra', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap, bool active) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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

  void _setMode(int m) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (m == 5) {
      final l = _txt.value;
      _tc.text = (_sel >= 0 && _sel < l.length) ? l[_sel].text : '';
    }
    setState(() => _mode = m);
  }

  Widget _toolRow() {
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _tool(Icons.crop, 'Kırp', () => _setMode(2), _mode == 2),
          _tool(Icons.rotate_right, 'Döndür', () {
            _checkpoint();
            setState(() {
              _turns = (_turns + 1) % 4;
              _cropN.value = _fullRect;
              _crop = 0;
              _lock = null;
            });
          }, false),
          _tool(Icons.flip, 'Ayna', () {
            _checkpoint();
            setState(() => _fh = !_fh);
          }, _fh),
          _tool(Icons.swap_vert, 'Çevir', () {
            _checkpoint();
            setState(() => _fv = !_fv);
          }, _fv),
          _tool(Icons.filter_vintage_outlined, 'Filtre', () => _setMode(0),
              _mode == 0),
          _tool(Icons.tune, 'Ayarlar', () => _setMode(1), _mode == 1),
          _tool(Icons.blur_on, 'Portre', () => _setMode(3), _mode == 3),
          _tool(Icons.text_fields, 'Yazı', () => _setMode(5), _mode == 5),
          _tool(Icons.emoji_emotions_outlined, 'Çıkartma', () => _setMode(6),
              _mode == 6),
          _tool(Icons.brush, 'Çizim', () => _setMode(7), _mode == 7),
          _tool(Icons.filter_frames_outlined, 'Çerçeve', () => _setMode(4),
              _mode == 4),
          _tool(Icons.restart_alt, 'Sıfırla', _resetAll, false),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _built = true;
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
            _historyBar(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(_mode == 2 ? 20 : 0),
                  child: _canvasArea(),
                ),
              ),
            ),
            _panel(),
            _toolRow(),
          ],
        ),
      ),
    );
  }
}
