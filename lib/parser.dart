import 'dart:ui';
import 'package:flutter_paddle_ocr_v5/flutter_paddle_ocr_v5.dart';

/// v3.3.15 — DEBUG: codeUnits для ВСЕХ блоков в цикле
class ArtifactParser {
  static const double yThreshold = 15.0;
  static const double xGapThreshold = 25.0;
  static const double xSplit = 130.0;
  static const double yMaxForSet = 200.0;
  static const double yMinForStats = 400.0;

  static const List<List<String>> replacementPairs = [
    ['cYYlowb', 'Скр'],
    ['cYlowb', 'Скр'],
    ['cnmYlowb', 'Скр'],
    ['calowb', 'Скр'],
    ['cYlwb', 'Скр'],
    ['cYlob', 'Зщт'],
    ['cYwb', 'Скр'],
    ['Скb(', 'Скр('],
    ['Скb', 'Скр'],
    ['Скp', 'Скр'],
    ['Скв', 'Скр'],
    ['Ск(', 'Скр('],
    ['Cwb', 'Скр'],
    ['cowb', 'Зщт'],
    ['3др', 'Здр'],
    ['3Д', 'Здр'],
    ['Здр(1w', 'Здр(1)'],
    ['Здр(1', 'Здр(1)'],
    ['Метw', 'Метк'],
    ['Метv', 'Метк'],
    ['Метв', 'Метк'],
    ['МеТ', 'Метк'],
    ['Мет(', 'Метк('],
    ['Атк(1w', 'Атк(1)'],
    ['Атк(1', 'Атк(1)'],
    ['Атк1', 'Атк'],
    ['АТк', 'Атк'],
    ['Ат 1', 'Атк 1'],
    ['Крит. ш(1', 'Крит. ш(1)'],
    ['Крит. у(1', 'Крит. ур(1)'],
    ['Крит. (1', 'Крит. ш(1)'],
    ['Крит. (', 'Крит. ш('],
    ['сКрит', 'Крит'],
    ['Суровостьw', 'Суровость'],
    ['Небеснаяскорость', 'Небесная скорость'],
    ['ИТ.Ш', ''],
    ['ИТЛ', ''],
  ];

  static const List<String> types = [
    'Доспех', 'Оружие', 'Шлем', 'Перчатки', 'Сапоги',
    'Щит', 'Кольцо', 'Амулет', 'Знамя'
  ];

  static const List<String> rarities = [
    'Легендарный', 'Эпический', 'Редкий', 'Обычный', 'Мифический'
  ];

  static const List<String> statNames = [
    'Метк', 'Крит. ш', 'Крит. ур', 'Атк', 'Здр', 'Скр', 'Зщт', 'Сопр'
  ];

  static String _applyReplacements(String text) {
    String result = text;
    for (final pair in replacementPairs) {
      result = result.replaceAll(pair[0], pair[1]);
    }
    result = result.replaceAll(RegExp(r'\bАт\b'), 'Атк');
    return result;
  }

  static String _cleanText(String text) {
    return _applyReplacements(text).trim();
  }

  static String _stripGlyphMarkers(String text) {
    return text.replaceAll(RegExp(r'\(\d+\)?'), '').trim();
  }

  static double _minX(OcrResult r) {
    if (r.points.isEmpty) return 0;
    return r.points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
  }

  static double _maxX(OcrResult r) {
    if (r.points.isEmpty) return 0;
    return r.points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
  }

  static double _minY(OcrResult r) {
    if (r.points.isEmpty) return 0;
    return r.points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
  }

  static double _maxY(OcrResult r) {
    if (r.points.isEmpty) return 0;
    return r.points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
  }

  static double _centerY(OcrResult r) => (_minY(r) + _maxY(r)) / 2;
  static double _centerX(OcrResult r) => (_minX(r) + _maxX(r)) / 2;

  static String? _findStatName(OcrResult r) {
    final text = _cleanText(r.text);
    if (text.isEmpty) return null;
    final cleaned = _stripGlyphMarkers(text);
    if (cleaned.isEmpty) return null;
    for (final stat in statNames) {
      if (cleaned.contains(stat)) return stat;
    }
    return null;
  }

  static bool _hasPercent(OcrResult r) {
    final t = _cleanText(r.text);
    return t.contains('%') || t.endsWith(',');
  }

  static int? _extractNumber(OcrResult r) {
    final text = _stripGlyphMarkers(_cleanText(r.text));
    if (text.isEmpty) return null;
    final matches = RegExp(r'\d+').allMatches(text).toList();
    if (matches.isEmpty) return null;
    int? best;
    for (final m in matches) {
      final val = int.tryParse(m.group(0) ?? '');
      if (val == null) continue;
      if (val < 10) continue;
      if (best == null || val > best) best = val;
    }
    if (best != null) return best;
    for (final m in matches) {
      final val = int.tryParse(m.group(0) ?? '');
      if (val != null && val > 0) return val;
    }
    return null;
  }

  static void _parseStats(
    List<OcrResult> mainBlocks,
    Map<String, List<int>> statsOut,
    Map<String, List<int>> percentOut,
    List<String> debugOut,
  ) {
    debugOut.add('[PARSER] _parseStats START, mainBlocks=${mainBlocks.length}');

    final leftBlocks = <OcrResult>[];
    final rightBlocks = <OcrResult>[];

    for (int idx = 0; idx < mainBlocks.length; idx++) {
      final r = mainBlocks[idx];
      if (r.points.isEmpty) {
        debugOut.add('[ITER] #$idx EMPTY POINTS raw="${r.text}"');
        continue;
      }
      final cy = _centerY(r);
      final cx = _centerX(r);
      final text = _cleanText(r.text);

      debugOut.add('[ITER] #$idx raw="${r.text}" clean="$text" cu=${r.text.codeUnits} cx=$cx cy=$cy');

      if (cy > yMinForStats) {
        debugOut.add('[ITER] #$idx SKIP (cy>$yMinForStats)');
        continue;
      }

      final statName = _findStatName(r);
      if (statName != null && cx < xSplit) {
        leftBlocks.add(r);
        debugOut.add('[ITER] #$idx → LEFT stat=$statName');
        continue;
      }
      if (cx >= xSplit && RegExp(r'\d').hasMatch(text)) {
        rightBlocks.add(r);
        debugOut.add('[ITER] #$idx → RIGHT');
      } else {
        debugOut.add('[ITER] #$idx → NEITHER (cx=$cx, text="$text")');
      }
    }

    debugOut.add('[PARSER] leftBlocks=${leftBlocks.length} rightBlocks=${rightBlocks.length}');

    for (final left in leftBlocks) {
      final statName = _findStatName(left);
      if (statName == null) continue;
      final leftY = _centerY(left);

      OcrResult? bestNum;
      double bestDist = double.infinity;
      for (final right in rightBlocks) {
        final dy = (_centerY(right) - leftY).abs();
        if (dy < yThreshold && dy < bestDist) {
          bestNum = right;
          bestDist = dy;
        }
      }

      if (bestNum == null) {
        debugOut.add('[PARSER] NO MATCH for $statName at cy=$leftY');
        continue;
      }

      final value = _extractNumber(bestNum);
      if (value == null) continue;

      debugOut.add('[PARSER] MATCH: $statName = $value (from "${bestNum.text}" dy=$bestDist)');

      if (_hasPercent(bestNum)) {
        final list = percentOut.putIfAbsent(statName, () => []);
        if (!list.contains(value)) list.add(value);
      } else {
        final list = statsOut.putIfAbsent(statName, () => []);
        if (!list.contains(value)) list.add(value);
      }
    }

    debugOut.add('[PARSER] _parseStats END');
  }

  static Map<String, dynamic> parse(
    List<OcrResult> mainBlocks, {
    List<OcrResult> rightBlocks = const [],
    List<OcrResult> iconBlocks = const [],
  }) {
    final result = <String, dynamic>{
      'set': null,
      'type': null,
      'rarity': null,
      'level': null,
      'stats': <String, List<int>>{},
      'stats_percent': <String, List<int>>{},
      'glyphs': <String, List<int>>{},
      'set_bonus': null,
      'worn': null,
      'debug': <String>[],
    };

    try {
      final stats = result['stats'] as Map<String, List<int>>;
      final percents = result['stats_percent'] as Map<String, List<int>>;
      final debug = result['debug'] as List<String>;

      final allText = mainBlocks.map((r) => _cleanText(r.text)).join(' | ');

      for (final t in types) {
        if (allText.contains(t)) { result['type'] = t; break; }
      }
      for (final r in rarities) {
        if (allText.contains(r)) { result['rarity'] = r; break; }
      }

      final lvlMatch = RegExp(r'\+(\d{1,2})').firstMatch(allText);
      if (lvlMatch != null) {
        final lvl = int.tryParse(lvlMatch.group(1) ?? '');
        if (lvl != null && [4, 8, 12, 16].contains(lvl)) {
          result['level'] = lvl;
        }
      }

      final wornMatch = RegExp(r'Надето[:\s]*(\d+/\d+)').firstMatch(allText);
      if (wornMatch != null) result['worn'] = wornMatch.group(1);

      final bonusMatch = RegExp(r'Комплект[:\s]*(\d+)\s*шт').firstMatch(allText);
      if (bonusMatch != null) {
        result['set_bonus'] = '${bonusMatch.group(1)} шт.';
      }

      OcrResult? topBlock;
      double minY = double.infinity;
      for (final r in mainBlocks) {
        if (r.points.isEmpty) continue;
        final cy = _centerY(r);
        if (cy > yMaxForSet) continue;
        final text = _cleanText(r.text);
        if (text.isEmpty) continue;
        if (types.contains(text)) continue;
        if (rarities.contains(text)) continue;
        if (text.contains('Улучшить') || text.contains('Надеть')) continue;
        if (cy < minY) {
          minY = cy;
          topBlock = r;
        }
      }
      if (topBlock != null) {
        result['set'] = _cleanText(topBlock.text);
      }

      _parseStats(mainBlocks, stats, percents, debug);

      if (result['level'] == null && iconBlocks.isNotEmpty) {
        for (final r in iconBlocks) {
          if (r.points.isEmpty) continue;
          final m = RegExp(r'\+?(\d{1,2})').firstMatch(_cleanText(r.text));
          if (m != null) {
            final lvl = int.tryParse(m.group(1) ?? '');
            if (lvl != null && [4, 8, 12, 16].contains(lvl)) {
              result['level'] = lvl;
              break;
            }
          }
        }
      }
    } catch (e) {
      result['error'] = 'parse error: $e';
    }

    return result;
  }
}
