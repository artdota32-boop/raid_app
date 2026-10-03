import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raid Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _videoFile;
  String? _thumbnailPath;
  String _status = 'Выбери видео';

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _videoFile = File(picked.path);
        _status = 'Видео выбрано, вырезаю кадр...';
        _thumbnailPath = null;
      });
      await _extractFrame();
    }
  }

  Future<void> _extractFrame() async {
    if (_videoFile == null) return;
    try {
      final thumbnailPath = await FcNativeVideoThumbnail()
          .getVideoThumbnail(
            srcFile: _videoFile!.path,
            destFile: '${_videoFile!.parent.path}/thumbnail.jpg',
            width: 1600,
            height: 720,
            timeMs: 2000,
            format: 'jpeg',
            quality: 90,
          );

      setState(() {
        _thumbnailPath = thumbnailPath;
        _status = thumbnailPath != null
            ? 'Кадр вырезан!'
            : 'Не удалось вырезать кадр';
      });
    } catch (e) {
      setState(() {
        _status = 'Ошибка: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raid Scanner')),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('Выбрать видео'),
              ),
              const SizedBox(height: 20),
              Text(_status, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              if (_thumbnailPath != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.file(
                    File(_thumbnailPath!),
                    width: 300,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
