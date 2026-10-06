import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snapframes/snapframes.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_paddle_ocr_v5/flutter_paddle_ocr_v5.dart';
import 'parser.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
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

  Future<String> _copyAssetToFile(String assetPath, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    return file.path;
  }

  void _dprint(String line) {
    debugPrint(line);
    _debugBuffer.add(line);
    if (_debugBuffer.length > 300) _debugBuffer.removeAt(0);
  }

  void _debugPrintBlock(String tag, int i, OcrResult r) {
    if (r.points.isEmpty) {
      _dprint('=== $tag #$i | text="${r.text}" | POINTS EMPTY ===');
      return;
    }
    final xs = r.points.map((p) => p.dx).toList();
    final ys = r.points.map((p) => p.dy).toList();
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    _dprint('=== $tag #$i | text="${r.text}" | conf=${r.confidence.toStringAsFixed(2)} | x[${minX.toStringAsFixed(0)}..${maxX.toStringAsFixed(0)}] y[${minY.toStringAsFixed(0)}..${maxY.toStringAsFixed(0)}] | center=(${cx.toStringAsFixed(0)},${cy.toStringAsFixed(0)}) ===');
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
    final cropped = img.copyCrop(decoded,
        x: 113, y: 490, width: 214 - 113, height: 540 - 490);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  Uint8List? _cropRightPart(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final cropped = img.copyCrop(decoded,
        x: 252, y: 445, width: 380 - 252, height: 488 - 445);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  Uint8List? _cropBottomLeft(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final cropped = img.copyCrop(decoded,
        x: 70, y: 360, width: 480 - 70, height: 760 - 360);
    final resized = img.copyResize(cropped, width: cropped.width * 2);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 95));
  }

  Future<void> _runOcr(Uint8List? cropped, Uint8List? rightPart, Uint8List? iconPart) async {
    if (cropped == null) return;
    try {
      final detPath = await _copyAssetToFile('assets/models/det.onnx', 'det.onnx');
      final recPath = await _copyAssetToFile('assets/models/rec.onnx', 'rec.onnx');
      final dictPath = await _copyAssetToFile('assets/models/dict.txt', 'dict.txt');

      final ocr = await PaddleOcr.create(
        source: ModelSource.filePaths(det: detPath, rec: recPath, dict: dictPath),
      );

      final results = await ocr.recognize(cropped);
      final rightResults = rightPart != null ? await ocr.recognize(rightPart) : <OcrResult>[];
      final iconResults = iconPart != null ? await ocr.recognize(iconPart) : <OcrResult>[];

      final sorted = List<OcrResult>.from(results);
      final rightSorted = List<OcrResult>.from(rightResults);

      _dprint('########## OCR DEBUG START ##########');
      _dprint('--- MAIN blocks: ${sorted.length} ---');
      for (int i = 0; i < sorted.length; i++) _debugPrintBlock('MAIN', i, sorted[i]);
      _dprint('########## OCR DEBUG END ##########');

      final parsed = ArtifactParser.parse(
        sorted,
        rightBlocks: rightSorted,
        iconBlocks: iconResults,
      );

      _dprint('########## PARSER DEBUG START ##########');
      final debugList = parsed['debug'] as List<String>?;
      if (debugList != null) {
        for (final d in debugList) {
          _dprint(d);
        }
      }
      _dprint('########## PARSER DEBUG END ##########');

      final text = sorted.map((r) => r.text).join("\n") +
          "\n" +
          rightSorted.map((r) => r.text).join("\n") +
          "\n" +
          iconResults.map((r) => r.text).join("\n");

      final parsedPretty = '''
Сет: ${parsed['set'] ?? '?'}
Тип: ${parsed['type'] ?? '?'}
Редкость: ${parsed['rarity'] ?? '?'}
Уровень: ${parsed['level'] ?? '?'}
Статы: ${parsed['stats']}
Проценты: ${parsed['stats_percent'] ?? {}}
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
              if (_ocrText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Сырой текст:\n$_ocrText',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              if (_debugLog.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black12,
                    child: Text(
                      'DEBUG LOG:\n$_debugLog',
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
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
