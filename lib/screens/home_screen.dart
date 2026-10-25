import 'package:flutter/material.dart';
import '../theme.dart';
import 'gallery_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _soon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name yakında')),
    );
  }

  @override
  Widget build(BuildContext context) {
    void openGallery() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GalleryScreen()),
      );
    }

    final tiles = <_Tile>[
      _Tile(Icons.image_outlined, 'Fotoğraf\nDüzenle', openGallery),
      _Tile(Icons.videocam_outlined, 'Video\nDüzenle', openGallery),
      _Tile(Icons.text_fields, 'Metin\nEkle', null),
      _Tile(Icons.dashboard_customize_outlined, 'Şablonlar', null),
      _Tile(Icons.photo_camera_outlined, 'Kamera', null),
      _Tile(Icons.photo_library_outlined, 'Galeri', openGallery),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('EditPro',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              Icon(Icons.workspace_premium, color: AppColors.gold, size: 30),
            ],
          ),
          const SizedBox(height: 16),
          _banner(context),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final t in tiles)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: t.onTap ?? () => _soon(context, t.label.replaceAll('\n', ' ')),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.icon, size: 28, color: AppColors.purple),
                        const SizedBox(height: 8),
                        Text(t.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Son Projeler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text('Tümünü Gör  >',
                  style: TextStyle(fontSize: 12, color: AppColors.textDim)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: _Thumb('00:32', Color(0xFFFF7A59))),
              SizedBox(width: 12),
              Expanded(child: _Thumb('00:18', Color(0xFF8B5CF6))),
              SizedBox(width: 12),
              Expanded(child: _Thumb('00:45', Color(0xFF14B8A6))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF6D4AFF), Color(0xFFFF7A59)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fotoğraf ve Videolarını\nDüzenle, Hikayeni Anlat',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => _soon(context, 'Yeni proje'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF3B3BD8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Yeni Proje Oluştur'),
          ),
        ],
      ),
    );
  }
}

class _Tile {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  _Tile(this.icon, this.label, this.onTap);
}

class _Thumb extends StatelessWidget {
  final String time;
  final Color color;
  const _Thumb(this.time, this.color);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.8,
      child: Container(
        padding: const EdgeInsets.all(8),
        alignment: Alignment.bottomLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, AppColors.card],
          ),
        ),
        child: Text(time, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}
