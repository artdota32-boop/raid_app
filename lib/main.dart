import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snapframes/snapframes.dart';
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
  Uint8List? _frameBytes;
  String _status = 'Выбери видео';

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _videoFile = File(picked.path);
        _status = 'Видео выбрано, вырезаю кадр...';
        _frameBytes = null;
      });
      await _extractFrame();
    }
  }

  Future<void> _extractFrame() async {
    if (_videoFile == null) return;
    try {
      final req = SnapRequest(
        source: _videoFile!.path,
        timestampMs: 2000, // кадр на 2-й секунде
        format: SnapImageFormat.jpg,
        quality: 90,
      );
      final bytes = await getFrameBytes(req);
      setState(() {
        _frameBytes = bytes;
        _status = bytes != null ? 'Кадр вырезан!' : 'Не удалось вырезать кадр';
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
              if (_frameBytes != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.memory(
                    _frameBytes!,
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
