import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import 'edit_photo_screen.dart';
import 'edit_video_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  final List<XFile> _videos = [];
  int _tab = 0;

  Future<void> _pick() async {
    if (_tab == 0) {
      final files = await _picker.pickMultiImage();
      if (files.isNotEmpty) setState(() => _photos.addAll(files));
    } else {
      final f = await _picker.pickVideo(source: ImageSource.gallery);
      if (f != null) setState(() => _videos.add(f));
    }
  }

  void _open(XFile file) {
    if (_tab == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EditPhotoScreen(path: file.path)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EditVideoScreen(path: file.path)),
      );
    }
  }

  Widget _tabButton(String text, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? null : AppColors.card,
            gradient: selected ? appGradient : null,
          ),
          child: Text(text,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _tab == 0 ? _photos : _videos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Galeri'),
        backgroundColor: AppColors.bg,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _tabButton('Fotoğraflar', 0),
                  const SizedBox(width: 12),
                  _tabButton('Videolar', 1),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('Henüz seçilmedi',
                            style: TextStyle(color: AppColors.textDim)),
                      )
                    : GridView.builder(
                        itemCount: items.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemBuilder: (context, i) {
                          final file = items[i];
                          return GestureDetector(
                            onTap: () => _open(file),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _tab == 0
                                  ? Image.file(File(file.path),
                                      fit: BoxFit.cover, cacheWidth: 300)
                                  : Container(
                                      color: AppColors.card,
                                      child: const Icon(
                                          Icons.play_circle_outline,
                                          size: 40,
                                          color: AppColors.purple),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_tab == 0 ? 'Fotoğraf seç' : 'Video seç'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
