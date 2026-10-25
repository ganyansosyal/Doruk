import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import '../theme.dart';

class _Cap {
  String text;
  int start; // milisaniye
  int end;
  _Cap(this.text, this.start, this.end);
}

int _cl(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

String _fmt(int ms) {
  final m = ms ~/ 60000;
  final s = (ms % 60000) / 1000;
  return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
}

class EditVideoScreen extends StatefulWidget {
  final String path;
  const EditVideoScreen({super.key, required this.path});

  @override
  State<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends State<EditVideoScreen> {
  late final VideoPlayerController _c;
  final List<_Cap> _caps = [];
  final _pos = ValueNotifier<int>(0);
  final _playing = ValueNotifier<bool>(false);
  final _rev = ValueNotifier<int>(0); // liste değişti
  final _ovr = ValueNotifier<int>(0); // yazı metni değişti
  final _tc = TextEditingController();
  bool _ready = false;
  bool _error = false;
  bool _dragging = false;
  int _sel = -1;
  static const _ch = MethodChannel('editpro/video');
  final _exp = ValueNotifier<int>(0); // 0 yok, 1 kalite, 2 kaydediyor, 3 bitti
  final _prog = ValueNotifier<double>(0);
  final _qual = ValueNotifier<int>(720);
  final _enh = ValueNotifier<bool>(true);
  String _msg = '';

  int get _dur => _c.value.duration.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.file(File(widget.path));
    _c.initialize().then((_) {
      if (!mounted) return;
      _c.addListener(_onTick);
      setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _error = true);
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    _pos.dispose();
    _playing.dispose();
    _rev.dispose();
    _ovr.dispose();
    _tc.dispose();
    _exp.dispose();
    _prog.dispose();
    _qual.dispose();
    _enh.dispose();
    _ch.setMethodCallHandler(null);
    super.dispose();
  }

  void _onTick() {
    final v = _c.value;
    _playing.value = v.isPlaying;
    if (_dragging) return;
    final p = v.position.inMilliseconds;
    if ((p - _pos.value).abs() >= 100) _pos.value = p;
  }

  void _seek(int ms) {
    ms = _cl(ms, 0, _dur);
    _pos.value = ms;
    _c.seekTo(Duration(milliseconds: ms));
  }

  void _toggle() {
    if (_c.value.isPlaying) {
      _c.pause();
    } else {
      _c.play();
    }
  }

  void _select(int i) {
    _sel = i;
    if (i >= 0) {
      _tc.text = _caps[i].text;
      _seek(_caps[i].start);
    }
    _rev.value++;
  }

  void _add() {
    int start = _caps.isEmpty ? _pos.value : _caps.last.end;
    start = _cl(start, 0, _dur > 600 ? _dur - 500 : 0);
    int end = _cl(start + 2000, 0, _dur);
    if (end <= start) end = start + 500;
    _caps.add(_Cap('', start, end));
    _select(_caps.length - 1);
  }

  void _delete(int i) {
    _caps.removeAt(i);
    _sel = -1;
    _rev.value++;
    _ovr.value++;
  }

  void _setStart(int i, int v) {
    final c = _caps[i];
    c.start = _cl(v, 0, c.end - 100);
    _seek(c.start);
    _rev.value++;
    _ovr.value++;
  }

  void _setEnd(int i, int v) {
    final c = _caps[i];
    final old = c.end;
    c.end = _cl(v, c.start + 100, _dur);
    if (i + 1 < _caps.length) {
      final n = _caps[i + 1];
      if (n.start == old || n.start < c.end) {
        n.start = c.end;
        if (n.end <= n.start) n.end = _cl(n.start + 1000, 0, _dur);
      }
    }
    _seek(c.end);
    _rev.value++;
    _ovr.value++;
  }

  String _activeText(int ms) {
    for (final c in _caps) {
      if (c.text.isNotEmpty && ms >= c.start && ms < c.end) return c.text;
    }
    return '';
  }

  Future<void> _startExport() async {
    _c.pause();
    _prog.value = 0;
    _exp.value = 2;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        _prog.value = (call.arguments as num).toDouble();
      }
    });
    try {
      final out = await _ch.invokeMethod<String>('export', {
        'path': widget.path,
        'height': _qual.value,
        'enhance': _enh.value,
        'caps': [
          for (final c in _caps)
            if (c.text.trim().isNotEmpty)
              {'text': c.text.trim(), 'start': c.start, 'end': c.end}
        ],
      });
      await Gal.putVideo(out!, album: 'EditPro');
      try {
        File(out).deleteSync();
      } catch (_) {}
      _msg = 'Galeriye kaydedildi (EditPro albümü)';
    } catch (e) {
      _msg = 'Hata: $e';
    }
    if (mounted) _exp.value = 3;
  }

  Widget _qChip(String label, int h) {
    return ValueListenableBuilder<int>(
      valueListenable: _qual,
      builder: (context, q, _) {
        final sel = q == h;
        return GestureDetector(
          onTap: () => _qual.value = h,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: sel ? null : AppColors.bg,
              gradient: sel ? appGradient : null,
            ),
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }

  Widget _exportPanel(int s) {
    Widget body;
    if (s == 1) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Video Kalitesi',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _qChip('720p', 720),
              const SizedBox(width: 8),
              _qChip('1080p', 1080),
              const SizedBox(width: 8),
              _qChip('2K', 1440),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: _enh,
            builder: (context, on, _) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _enh.value = !on,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(on ? Icons.check_box : Icons.check_box_outline_blank,
                      color: on ? AppColors.blue : AppColors.textDim),
                  const SizedBox(width: 8),
                  const Text('HD iyileştirme (renk + netlik)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'MP4. Video seçtiğin çözünürlüğe büyütülür. 2K’yı her telefon desteklemeyebilir.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _exp.value = 0,
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _startExport,
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: appGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Kaydet',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (s == 2) {
      body = ValueListenableBuilder<double>(
        valueListenable: _prog,
        builder: (context, p, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Kaydediliyor...',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: p / 100,
              color: AppColors.blue,
              backgroundColor: AppColors.bg,
            ),
            const SizedBox(height: 8),
            Text('%${p.toInt()}',
                style: const TextStyle(color: AppColors.textDim)),
            const SizedBox(height: 4),
            const Text('Ekranı kapatma, bekle.',
                style: TextStyle(fontSize: 12, color: AppColors.textDim)),
          ],
        ),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_msg, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => _exp.value = 0,
            child: const Text('Tamam'),
          ),
        ],
      );
    }
    return Positioned.fill(
      child: Container(
        color: const Color(0xE60B1226),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _video(double maxH) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: AspectRatio(
          aspectRatio: _c.value.aspectRatio,
          child: GestureDetector(
            onTap: _toggle,
            child: LayoutBuilder(builder: (context, box) {
              final fs = box.maxWidth * 0.05;
              return Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayer(_c),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: box.maxHeight * 0.06,
                    child: IgnorePointer(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _pos,
                        builder: (context, ms, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable: _ovr,
                            builder: (context, _, __) {
                              final t = _activeText(ms);
                              if (t.isEmpty) return const SizedBox();
                              return Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0x99000000),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: fs,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _playing,
            builder: (context, p, _) => IconButton(
              onPressed: _toggle,
              icon: Icon(p ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 32),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _pos,
              builder: (context, ms, _) => Slider(
                value: _cl(ms, 0, _dur).toDouble(),
                max: _dur > 0 ? _dur.toDouble() : 1,
                activeColor: AppColors.blue,
                onChangeStart: (_) => _dragging = true,
                onChanged: (v) => _pos.value = v.toInt(),
                onChangeEnd: (v) {
                  _dragging = false;
                  _seek(v.toInt());
                },
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _pos,
            builder: (context, ms, _) => Text(
              '${_fmt(ms)} / ${_fmt(_dur)}',
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textDim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeRow(String label, int ms, void Function(int) set) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textDim)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => set(ms - 100),
          icon: const Icon(Icons.remove_circle_outline, size: 22),
        ),
        Text(_fmt(ms),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => set(ms + 100),
          icon: const Icon(Icons.add_circle_outline, size: 22),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => set(_c.value.position.inMilliseconds),
          child: const Text('Şimdi'),
        ),
      ],
    );
  }

  Widget _item(int i) {
    final c = _caps[i];
    final selected = i == _sel;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: selected ? AppColors.blue : AppColors.card, width: 1.5),
      ),
      child: selected
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _tc,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Konuşulan yazıyı yaz...',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    c.text = v;
                    _ovr.value++;
                  },
                ),
                const Divider(height: 12),
                _timeRow('Başla', c.start, (v) => _setStart(i, v)),
                _timeRow('Bitiş', c.end, (v) => _setEnd(i, v)),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _delete(i),
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.redAccent),
                      label: const Text('Sil',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        _select(-1);
                      },
                      child: const Text('Tamam'),
                    ),
                  ],
                ),
              ],
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _select(i),
              child: Row(
                children: [
                  Text('${i + 1}',
                      style: const TextStyle(
                          color: AppColors.purple,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Text('${_fmt(c.start)} - ${_fmt(c.end)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textDim)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.text.isEmpty ? '(boş)' : c.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _list() {
    return ValueListenableBuilder<int>(
      valueListenable: _rev,
      builder: (context, _, __) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text('Yazılar (${_caps.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _add,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: appGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('+ Satır ekle',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _caps.isEmpty
                  ? const Center(
                      child: Text('Henüz yazı yok.\n"Satır ekle"ye dokun.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textDim)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _caps.length,
                      itemBuilder: (context, i) => _item(i),
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yazı Ekle'),
        backgroundColor: AppColors.bg,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              _c.pause();
              _exp.value = 1;
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: SafeArea(
        child: _error
            ? const Center(child: Text('Video açılamadı'))
            : !_ready
                ? const Center(child: CircularProgressIndicator())
                : ValueListenableBuilder<int>(
                    valueListenable: _exp,
                    builder: (context, s, _) => Stack(
                      children: [
                        Column(
                          children: [
                            _video(h * 0.34),
                            _controls(),
                            Expanded(child: _list()),
                          ],
                        ),
                        if (s > 0) _exportPanel(s),
                      ],
                    ),
                  ),
      ),
    );
  }
}
