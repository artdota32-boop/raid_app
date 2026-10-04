import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snapframes/snapframes.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_paddle_ocr_v5/flutter_paddle_ocr_v5.dart';
import 'dart:io';
import 'dart:typed_data';

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
  Uint8List? _croppedBytes;
  String _status = 'Выбери видео';
  String _ocrText = '';

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _videoFile = File(picked.path);
        _status = 'Видео выбрано, вырезаю кадр...';
        _croppedBytes = null;
        _ocrText = '';
      });
      await _extractFrame();
    }
  }

  Future<void> _extractFrame() async {
    if (_videoFile == null) return;
    try {
      final req = SnapRequest(
        source: _videoFile!.path,
        timestampMs: 2000,
        format: SnapImageFormat.jpg,
        quality: 90,
      );
      final bytes = await getFrameBytes(req);
      if (bytes == null) {
        setState(() => _status = 'Не удалось вырезать кадр');
        return;
      }
      final cropped = _cropBottomLeft(bytes);
      setState(() {
        _croppedBytes = cropped;
        _status = 'Кадр обрезан! Запускаю OCR...';
      });
      await _runOcr(cropped);
    } catch (e) {
      setState(() => _status = 'Ошибка: $e');
    }
  }

  Uint8List? _cropBottomLeft(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final xStart = 70;
    final yStart = 360;
    final xEnd = 460;
    final yEnd = 760;

    final cropped = img.copyCrop(
      decoded,
      x: xStart,
      y: yStart,
      width: xEnd - xStart,
      height: yEnd - yStart,
    );

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  Future<void> _runOcr(Uint8List? cropped) async {
    if (cropped == null) return;
    try {
      final ocr = await PaddleOcr.create(
        source: ModelSource.filePaths(
          det: '/absolute/path/det.onnx',
          rec: '/absolute/path/rec.onnx',
          dict: '/absolute/path/dict.txt',
        ),
      );

      final results = await ocr.recognize(cropped);
      final text = results.map((r) => r.text).join('\n');

      setState(() {
        _ocrText = text;
        _status = 'OCR завершён!';
      });
    } catch (e) {
      setState(() => _status = 'Ошибка OCR: $e');
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
              if (_croppedBytes != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.memory(_croppedBytes!, width: 200),
                ),
              if (_ocrText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _ocrText,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
