import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snapframes/snapframes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:paddle_ocr_native/paddle_ocr_native.dart' as pn;
import 'parser.dart';
import 'repl_screen.dart';
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
  SharedPreferences? _prefsCache;

  @override
  void initState() {
    super.initState();
    ArtifactParser.loadPrefs();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _prefsCache = p);
    });
  }
  File? _videoFile;
  Uint8List? _croppedBytes;
  Uint8List? _iconBytes;
  Uint8List? _lastFrame;
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
      _lastFrame = bytes;
      final cropped = await _cropBottomLeft(bytes);
      final rightPart = _cropRightPart(bytes);
      final iconPart = _cropIcon(bytes);
      setState(() {
        _croppedBytes = cropped;
        _iconBytes = iconPart;
        _status = 'Кадр обрезан! Запускаю OCR...';
      });
      await _runOcr(cropped, rightPart, iconPart);
    } catch (e) {
      setState(() => _status = 'Ошибка: $e');
    }
  }

  Future<String> parseCurrent() async {
    if (_lastFrame == null) return 'ERR: нет кадра';
    final cropped = await _cropBottomLeft(_lastFrame!);
    if (cropped == null) return 'ERR: кроп не удался';
    final rightPart = _cropRightPart(_lastFrame!);
    final iconPart = _cropIcon(_lastFrame!);
    final ocr = pn.PaddleOcr();
    await ocr.init(
      config: const pn.PaddleOcrConfig(),
      engine: const pn.EngineConfig(numThreads: 4),
    );
    final croppedFile = await _saveBytesToFile(cropped, 'repl_main.jpg');
    final rightFile = rightPart != null ? await _saveBytesToFile(rightPart, 'repl_right.jpg') : null;
    final iconFile = iconPart != null ? await _saveBytesToFile(iconPart, 'repl_icon.jpg') : null;
    final run = await ocr.recognize(croppedFile.path);
    final rightRun = rightFile != null ? await ocr.recognize(rightFile.path) : null;
    final iconRun = iconFile != null ? await ocr.recognize(iconFile.path) : null;
    await ocr.dispose();
    final results = run.results;
    final rightResults = rightRun?.results ?? <pn.OcrResult>[];
    final iconResults = iconRun?.results ?? <pn.OcrResult>[];
    // 🔥 Авто-ранг через color-анализ
      final detectedRank = iconPart != null ? _detectRank(iconPart) : null;
      _dprint("[RANK] detected = $detectedRank");
      final parsed = ArtifactParser.parse(results, rightBlocks: rightResults, iconBlocks: iconResults);
      if (detectedRank != null) parsed['rank'] = detectedRank;
    return 'MAIN: ${parsed['stats']}\nDOP: ${parsed['dop_stats']}';
  }


  Uint8List? _cropRightPart(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final cropped = img.copyCrop(decoded, x: 252, y: 445, width: 380 - 252, height: 488 - 445);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  Uint8List? _cropIcon(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final iconX = _prefsCache?.getInt('icon_x') ?? 90;
    final iconY = _prefsCache?.getInt('icon_y') ?? 388;
    final iconW = _prefsCache?.getInt('icon_w') ?? 90;
    final iconH = _prefsCache?.getInt('icon_h') ?? 35;
    final cropped = img.copyCrop(decoded, x: iconX, y: iconY, width: iconW, height: iconH);
    debugPrint("[ICON] x=$iconX y=$iconY w=$iconW h=$iconH");
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  /// 🔥 Color-анализ звёзд → ранг (1-6★)
  int? _detectRank(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final iconX = _prefsCache?.getInt('icon_x') ?? 90;
    final iconY = _prefsCache?.getInt('icon_y') ?? 388;
    final iconW = _prefsCache?.getInt('icon_w') ?? 90;
    final iconH = _prefsCache?.getInt('icon_h') ?? 35;
    final cropped = img.copyCrop(decoded, x: iconX, y: iconY, width: iconW, height: iconH);
    
    // 🔥 Пороги из prefs
    final lumThreshold = _prefsCache?.getInt('rank_lum') ?? 40;
    final minCount = _prefsCache?.getInt('rank_min_count') ?? 10;

    // Считаем средний цвет только ярких пикселей (звёзды)
    int rSum = 0, gSum = 0, bSum = 0, count = 0;
    for (int y = 0; y < cropped.height; y++) {
      for (int x = 0; x < cropped.width; x++) {
        final p = cropped.getPixel(x, y);
        final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
        final lum = (r + g + b) / 3;
        // Фильтр: только яркие пиксели (звёзды)
        if (lum > lumThreshold) {
          rSum += r; gSum += g; bSum += b; count++;
        }
      }
    }
    if (count < minCount) {
      _dprint("[RANK] ❌ count=$count < minCount=$minCount → null");
      return null;
    }
    final avgR = rSum / count;
    final avgG = gSum / count;
    final avgB = bSum / count;
    _dprint("[RANK] avg RGB = ($avgR, $avgG, $avgB), count=$count");
    _dprint("[RANK] lumThreshold=$lumThreshold, minCount=$minCount");
    
    // Маппинг цвет → ранг
    // Оранжевый/жёлтый → 5★ (R>G>B)
    // Красный → 6★ (R>>G,B)
    // Серый → 1★
    // Зелёный → 2★ (G>R,B)
    // Синий → 3★ (B>R,G)
    // Фиолетовый → 4★ (R и B > G)
    
    // 🔥 Пороги RGB из prefs
    final r6 = _prefsCache?.getInt('rank_red_r') ?? 200;
    final g6 = _prefsCache?.getInt('rank_red_g') ?? 100;
    final b6 = _prefsCache?.getInt('rank_red_b') ?? 100;

    final r5 = _prefsCache?.getInt('rank_orange_r') ?? 200;
    final g5 = _prefsCache?.getInt('rank_orange_g') ?? 130;
    final b5 = _prefsCache?.getInt('rank_orange_b') ?? 100;

    final r4 = _prefsCache?.getInt('rank_purple_r') ?? 150;
    final g4 = _prefsCache?.getInt('rank_purple_g') ?? 100;
    final b4 = _prefsCache?.getInt('rank_purple_b') ?? 150;

    final r1 = _prefsCache?.getInt('rank_gray_r') ?? 180;
    final g1 = _prefsCache?.getInt('rank_gray_g') ?? 180;
    final b1 = _prefsCache?.getInt('rank_gray_b') ?? 180;

    if (avgR > r6 && avgG < g6 && avgB < b6) return 6; // Красный
    if (avgR > r5 && avgG > g5 && avgB < b5) return 5; // Оранжевый
    if (avgR > r4 && avgB > b4 && avgG < g4) return 4; // Фиолетовый
    if (avgB > avgR && avgB > avgG) return 3; // Синий
    if (avgG > avgR && avgG > avgB) return 2; // Зелёный
    if (avgR > r1 && avgG > g1 && avgB > b1) return 1; // Серый
    _dprint("[RANK] ⚠️ Не попал в пороги → default 5");
    return 5;
  }

  Future<Uint8List?> _cropBottomLeft(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final cx = prefs.getInt("crop_x") ?? 50;
    final cy = prefs.getInt("crop_y") ?? 352;
    final cw = prefs.getInt("crop_w") ?? 470;
    final ch = prefs.getInt("crop_h") ?? 358;
    final cropped = img.copyCrop(decoded, x: cx, y: cy, width: cw, height: ch);
    debugPrint("[CROP] cx=$cx cy=$cy cw=$cw ch=$ch");
    final scale = prefs.getInt("crop_scale") ?? 3;
    final resized = img.copyResize(cropped, width: cropped.width * scale);
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
      // 🔥 Авто-ранг через color-анализ
      final detectedRank = iconPart != null ? _detectRank(iconPart) : null;
      _dprint("[RANK] detected = $detectedRank");
      final parsed = ArtifactParser.parse(results, rightBlocks: rightResults, iconBlocks: iconResults);
      if (detectedRank != null) parsed['rank'] = detectedRank;
      _dprint('########## PARSER DEBUG START ##########');
      final debugList = parsed['debug'] as List<String>?;
      if (debugList != null) {
        for (final d in debugList) _dprint(d);
      }
      _dprint('########## PARSER DEBUG END ##########');
      final text = results.map((r) => r.text).join("\n") + "\n" + rightResults.map((r) => r.text).join("\n");
      final rank = parsed['rank'] as int?;
      final rankStr = rank != null ? '$rank★' : '?★';
      final mainStats = parsed['stats'] as Map<String, List<int>>? ?? {};
      final mainPercent = parsed['stats_percent'] as Map<String, List<int>>? ?? {};
      final dopStats = parsed['dop_stats'] as Map<String, List<int>>? ?? {};
      final glyphs = parsed['glyphs'] as Map<String, List<int>>? ?? {};

      final mainLines = <String>[];
      mainPercent.forEach((k, v) => mainLines.add('   $k'.padRight(20) + '${v.first}%'));
      mainStats.forEach((k, v) => mainLines.add('   $k'.padRight(20) + '${v.first}'));

      final dopLines = <String>[];
      dopStats.forEach((k, v) => dopLines.add('   $k'.padRight(20) + '${v.first}'));

      final glyphLines = <String>[];
      glyphs.forEach((k, v) => glyphLines.add('   $k'.padRight(20) + '+${v.first}'));

      final parsedPretty = '''
🎯 ${parsed['set'] ?? '?'} (${parsed['type'] ?? '?'})
$rankStr ${parsed['rarity'] ?? '?'} | +${parsed['level'] ?? '?'}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💥 MAIN:
${mainLines.isEmpty ? '   —' : mainLines.join('\n')}
📊 DOP:
${dopLines.isEmpty ? '   —' : dopLines.join('\n')}
✨ Глифы:
${glyphLines.isEmpty ? '   —' : glyphLines.join('\n')}
📦 Бонус: ${parsed['set_bonus'] ?? '?'}
👤 Надето: ${parsed['worn'] ?? '?'}
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
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReplScreen(onParse: parseCurrent)),
                  );
                },
                icon: const Icon(Icons.terminal),
                label: const Text('REPL'),
              ),
              const SizedBox(height: 20),
              Text(_status, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              if (_croppedBytes != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.memory(_croppedBytes!, width: 200),
                ),
              if (_iconBytes != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('ICON CROP:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Image.memory(_iconBytes!, width: 150),
                    ],
                  ),
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
