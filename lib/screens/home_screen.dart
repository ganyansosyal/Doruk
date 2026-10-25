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
      _Tile(Icons.image, 'Fotoğraf\nDüzenle', openGallery,
          const Color(0xFFEC4899), const Color(0xFF8B5CF6)),
      _Tile(Icons.videocam, 'Video\nDüzenle', openGallery,
          const Color(0xFFF43F5E), const Color(0xFFD946EF)),
      _Tile(Icons.text_fields, 'Metin\nEkle', null,
          const Color(0xFF14B8A6), const Color(0xFF64748B)),
      _Tile(Icons.dashboard_customize, 'Şablonlar', null,
          const Color(0xFFEC4899), const Color(0xFF6366F1)),
      _Tile(Icons.photo_camera, 'Kamera', null,
          const Color(0xFF94A3B8), const Color(0xFF64748B)),
      _Tile(Icons.photo_library, 'Galeri', openGallery,
          const Color(0xFF10B981), const Color(0xFF14B8A6)),
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
                  onTap: t.onTap ??
                      () => _soon(context, t.label.replaceAll('\n', ' ')),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [t.c1, t.c2],
                            ),
                          ),
                          child: Icon(t.icon, size: 26, color: Colors.white),
                        ),
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
              Expanded(child: _Thumb('00:32', 'assets/proje1.jpg')),
              SizedBox(width: 12),
              Expanded(child: _Thumb('00:18', 'assets/proje2.jpg')),
              SizedBox(width: 12),
              Expanded(child: _Thumb('00:45', 'assets/proje3.jpg')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/banner.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              cacheWidth: 800,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF6D4AFF),
                    Color(0xCC6D4AFF),
                    Color(0x006D4AFF),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
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
                    elevation: 0,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF3B3BD8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Yeni Proje Oluştur'),
                ),
              ],
            ),
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
  final Color c1;
  final Color c2;
  _Tile(this.icon, this.label, this.onTap, this.c1, this.c2);
}

class _Thumb extends StatelessWidget {
  final String time;
  final String asset;
  const _Thumb(this.time, this.asset);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover, cacheWidth: 300),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xAA000000)],
                  stops: [0.6, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Text(time, style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
