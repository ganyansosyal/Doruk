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
  const _CropItem(this.name, this.ratio);
}

const List<_CropItem> _crops = [
  _CropItem('Orijinal', null),
  _CropItem('1:1', 1),
  _CropItem('4:3', 4 / 3),
  _CropItem('3:4', 3 / 4),
  _CropItem('16:9', 16 / 9),
  _CropItem('9:16', 9 / 16),
];

class EditPhotoScreen extends StatefulWidget {
  final String path;
  const EditPhotoScreen({super.key, required this.path});

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  int _filter = 0;
  int _mode = 0; // 0 filtre, 1 ayarlar, 2 kırp
  int _crop = 0;
  bool _saving = false;
  final GlobalKey _key = GlobalKey();
  int _turns = 0;
  double _brightness = 0;
  double _contrast = 1;

  List<double> get _adjust {
    final c = _contrast;
    final o = _brightness + 128 * (1 - c);
    return [
      c, 0, 0, 0, o,
      0, c, 0, 0, o,
      0, 0, c, 0, o,
      0, 0, 0, 1, 0,
    ];
  }

  Widget _canvas() {
    final photo = ColorFiltered(
      colorFilter: ColorFilter.matrix(_adjust),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(photoFilters[_filter].matrix),
        child: Image.file(File(widget.path), cacheWidth: 1600),
      ),
    );
    final rotated = RotatedBox(quarterTurns: _turns, child: photo);
    final ratio = _crops[_crop].ratio;
    if (ratio == null) return rotated;
    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRect(
        child: FittedBox(fit: BoxFit.cover, child: rotated),
      ),
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
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
              onTap: () => setState(() => _crop = i),
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

  Widget _adjustPanel() {
    return SizedBox(
      height: 110,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              const SizedBox(width: 80, child: Text('Parlaklık')),
              Expanded(
                child: Slider(
                  value: _brightness,
                  min: -60,
                  max: 60,
                  activeColor: AppColors.blue,
                  onChanged: (v) => setState(() => _brightness = v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 16),
              const SizedBox(width: 80, child: Text('Kontrast')),
              Expanded(
                child: Slider(
                  value: _contrast,
                  min: 0.5,
                  max: 1.5,
                  activeColor: AppColors.blue,
                  onChanged: (v) => setState(() => _contrast = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap, bool active) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: active ? AppColors.blue : Colors.white),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? AppColors.blue : Colors.white)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: Center(
                child: RepaintBoundary(key: _key, child: _canvas()),
              ),
            ),
            _mode == 0
                ? _filterStrip()
                : _mode == 1
                    ? _adjustPanel()
                    : _cropStrip(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _tool(Icons.crop, 'Kırp',
                    () => setState(() => _mode = 2), _mode == 2),
                _tool(Icons.rotate_right, 'Döndür',
                    () => setState(() => _turns = (_turns + 1) % 4), false),
                _tool(Icons.filter_vintage_outlined, 'Filtre',
                    () => setState(() => _mode = 0), _mode == 0),
                _tool(Icons.tune, 'Ayarlar',
                    () => setState(() => _mode = 1), _mode == 1),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
