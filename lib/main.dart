import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snapframes/snapframes.dart';
import 'package:image/image.dart' as img;
import 'package:paddle_ocr_native/paddle_ocr_native.dart' as pn;
import 'parser.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

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
  String _parsedText = '';
  String _debugLog = '';
  final List<String> _debugBuffer = [];

  void _dprint(String line) {
    debugPrint(line);
    _debugBuffer.add(line);
    if (_debugBuffer.length > 3000) _debugBuffer.removeAt(0);
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _videoFile = File(picked.path);
        _status = 'Видео выбрано, вырезаю кадр...';
        _croppedBytes = null;
        _ocrText = '';
        _parsedText = '';
        _debugLog = '';
        _debugBuffer.clear();
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
      final rightPart = _cropRightPart(bytes);
      final iconPart = _cropIcon(bytes);
      setState(() {
        _croppedBytes = cropped;
        _status = 'Кадр обрезан! Запускаю OCR...';
      });
      await _runOcr(cropped, rightPart, iconPart);
    } catch (e) {
      setState(() => _status = 'Ошибка: $e');
    }
  }

  Uint8List? _cropIcon(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    // ФИКС v3.5.9: область уровня +12 (было x:113 y:490)
    final cropped = img.copyCrop(decoded, x: 30, y: 140, width: 180 - 30, height: 210 - 140);
    // ФИКС v3.5.9: увеличение ×3
    final resized = img.copyResize(cropped, width: cropped.width * 3);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 95));
  }

  Uint8List? _cropRightPart(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final cropped = img.copyCrop(decoded, x: 252, y: 445, width: 380 - 252, height: 488 - 445);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  Uint8List? _cropBottomLeft(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final cropped = img.copyCrop(decoded, x: 70, y: 360, width: 480 - 70, height: 760 - 360);
    final resized = img.copyResize(cropped, width: cropped.width * 2);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 95));
  }

  Future<File> _saveBytesToFile(Uint8List bytes, String name) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _runOcr(Uint8List? cropped, Uint8List? rightPart, Uint8List? iconPart) async {
    if (cropped == null) return;
    try {
      final ocr = pn.PaddleOcr();
      await ocr.init(
        config: const pn.PaddleOcrConfig(),
        engine: const pn.EngineConfig(numThreads: 4),
      );

      final croppedFile = await _saveBytesToFile(cropped, 'main_crop.jpg');
      final rightFile = rightPart != null ? await _saveBytesToFile(rightPart, 'right_crop.jpg') : null;
      final iconFile = iconPart != null ? await _saveBytesToFile(iconPart, 'icon_crop.jpg') : null;

      final run = await ocr.recognize(croppedFile.path);
      final rightRun = rightFile != null ? await ocr.recognize(rightFile.path) : null;
      final iconRun = iconFile != null ? await ocr.recognize(iconFile.path) : null;

      await ocr.dispose();

      final results = run.results;
      final rightResults = rightRun?.results ?? <pn.OcrResult>[];
      final iconResults = iconRun?.results ?? <pn.OcrResult>[];

      _dprint('########## OCR DEBUG START ##########');
      _dprint('--- MAIN blocks: ${results.length} ---');
      for (int i = 0; i < results.length; i++) _debugPrintBlock('MAIN', i, results[i]);
      _dprint('########## OCR DEBUG END ##########');
      _dprint('########## ICON DEBUG START ##########');
      _dprint('--- ICON blocks: ${iconResults.length} ---');
      for (int i = 0; i < iconResults.length; i++) _debugPrintBlock('ICON', i, iconResults[i]);
      _dprint('########## ICON DEBUG END ##########');

      final parsed = ArtifactParser.parse(results, rightBlocks: rightResults, iconBlocks: iconResults);

      _dprint('########## PARSER DEBUG START ##########');
      final debugList = parsed['debug'] as List<String>?;
      if (debugList != null) {
        for (final d in debugList) _dprint(d);
      }
      _dprint('########## PARSER DEBUG END ##########');

      final text = results.map((r) => r.text).join("\n") + "\n" + rightResults.map((r) => r.text).join("\n");

      final parsedPretty = '''
Сет: ${parsed['set'] ?? '?'}
Тип: ${parsed['type'] ?? '?'}
Редкость: ${parsed['rarity'] ?? '?'}
Уровень: ${parsed['level'] ?? '?'}
Статы: ${parsed['stats']}
Проценты: ${parsed['stats_percent'] ?? {}}
Доп-статы: ${parsed['dop_stats'] ?? {}}
Глифы: ${parsed['glyphs']}
Бонус сета: ${parsed['set_bonus'] ?? '?'}
Надето: ${parsed['worn'] ?? '?'}
''';

      setState(() {
        _ocrText = text;
        _parsedText = parsedPretty;
        _debugLog = _debugBuffer.join('\n');
        _status = 'OCR и парсинг завершены!';
      });
    } catch (e) {
      setState(() => _status = 'Ошибка OCR: $e');
    }
  }

  void _debugPrintBlock(String tag, int i, pn.OcrResult r) {
    if (r.points.isEmpty) {
      _dprint('=== $tag #$i | text="${r.text}" | POINTS EMPTY ===');
      return;
    }
    final xs = r.points.map((p) => p.x.toDouble()).toList();
    final ys = r.points.map((p) => p.y.toDouble()).toList();
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    _dprint('=== $tag #$i | text="${r.text}" | conf=${r.confidence.toStringAsFixed(2)} | x[${minX.toStringAsFixed(0)}..${maxX.toStringAsFixed(0)}] y[${minY.toStringAsFixed(0)}..${maxY.toStringAsFixed(0)}] ===');
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
              if (_parsedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_parsedText, style: const TextStyle(fontSize: 14)),
                ),
              if (_debugLog.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black12,
                    child: Text('DEBUG LOG:\n$_debugLog', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
