import 'dart:io';
import 'package:flutter/material.dart';
import '../theme.dart';

class _FilterItem {
  final String name;
  final List<double> matrix;
  const _FilterItem(this.name, this.matrix);
}

List<double> _saturation(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return [
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

final List<_FilterItem> _filters = [
  const _FilterItem('Orijinal', [
    1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0,
  ]),
  _FilterItem('Siyah Beyaz', _saturation(0)),
  const _FilterItem('Sıcak', [
    1.1, 0, 0, 0, 10, 0, 1, 0, 0, 0, 0, 0, 0.9, 0, -10, 0, 0, 0, 1, 0,
  ]),
  const _FilterItem('Soğuk', [
    0.9, 0, 0, 0, -10, 0, 1, 0, 0, 0, 0, 0, 1.1, 0, 10, 0, 0, 0, 1, 0,
  ]),
  const _FilterItem('Retro', [
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  _FilterItem('Canlı', _saturation(1.6)),
];

class EditPhotoScreen extends StatefulWidget {
  final String path;
  const EditPhotoScreen({super.key, required this.path});

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  int _filter = 0;
  int _mode = 0; // 0 filtre, 1 ayarlar
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

  Widget _photo() {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_adjust),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(_filters[_filter].matrix),
        child: Image.file(File(widget.path), fit: BoxFit.contain),
      ),
    );
  }

  Widget _filterStrip() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
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
                      colorFilter: ColorFilter.matrix(_filters[i].matrix),
                      child: Image.file(File(widget.path),
                          fit: BoxFit.cover, cacheWidth: 150),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_filters[i].name, style: const TextStyle(fontSize: 11)),
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kaydetme yakında')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: RotatedBox(quarterTurns: _turns, child: _photo()),
              ),
            ),
            _mode == 0 ? _filterStrip() : _adjustPanel(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
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
