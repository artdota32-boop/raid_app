import 'dart:ui' as ui;
import 'package:paddle_ocr_native/paddle_ocr_native.dart' as pn;

/// v3.4.0 — parser под paddle_ocr_native (PP-OCRv6)
class ArtifactParser {
  static const double yThreshold = 15.0;
  static const double xGapThreshold = 25.0;
  static const double xSplit = 130.0;
  static const double yMaxForSet = 200.0;
  static const double yMinForStats = 400.0;
  static const double xMaxForSet = 400.0;

  static const Map<String, String> latinToCyrillic = {
    'M': 'М', 'e': 'е', 'E': 'Е', 'T': 'Т',
    'y': 'у', 'x': 'х', 'c': 'с', 'p': 'р',
    'A': 'А', 'B': 'В', 'H': 'Н', 'K': 'К',
    'O': 'О', 'P': 'Р', 'C': 'С', 'k': 'к',
    'o': 'о', 'a': 'а', 't': 'т', 'r': 'р',
    'n': 'п', 'u': 'и',
  };

  static const List<List<String>> replacementPairs = [
    ['cYYlowb', 'Скр'],
    ['cYlowb', 'Скр'],
    ['cnmaYlowb', 'Скр'],
    ['cnmYlowb', 'Скр'],
    ['cmYlowb', 'Скр'],
    ['cmnlowbl', 'Скр'],
    ['cnmlowbl', 'Скр'],
    ['caYlowbl', 'Скр'],
    ['cYlow', 'Скр'],
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
    ['A (1', 'Атк(1)'],
    ['A (', 'Атк('],
    ['Урит. шw', 'Крит. ш'],
    ['Урит. ш', 'Крит. ш'],
    ['Урит. ш(1', 'Крит. ш(1)'],
    ['Крит. ш(1', 'Крит. ш(1)'],
    ['Крит. у(1', 'Крит. ур(1)'],
    ['Крит. (1w', 'Крит. ш(1)'],
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
    'Щит', 'Кольцо', 'Амулет', 'Знамя',
    'Chestplate', 'Weapon', 'Helmet', 'Gloves', 'Boots',
    'Shield', 'Ring', 'Amulet', 'Banner',
  ];

  static const List<String> rarities = [
    'Легендарный', 'Эпический', 'Редкий', 'Обычный', 'Мифический',
    'Legendary', 'Epic', 'Rare', 'Common', 'Mythical',
  ];

  static const List<String> statNames = [
    'Метк', 'Крит. ш', 'Крит. ур', 'Атк', 'Здр', 'Скр', 'Зщт', 'Сопр',
    'ACC', 'C.RATE', 'C.RAT', 'C. RATE', 'C. RAT', 'C RATE', 'CRATE',
    'C.DMG', 'C. DMG', 'C DMG', 'CDMG',
    'ATK', 'HP', 'SPD', 'DEF', 'RES',
  ];

  static String _latinToCyr(String text) {
    String result = text;
    latinToCyrillic.forEach((lat, cyr) {
      result = result.replaceAll(lat, cyr);
    });
    return result;
  }

  static String _applyReplacements(String text) {
    String result = text;
    for (final pair in replacementPairs) {
      result = result.replaceAll(pair[0], pair[1]);
    }
    result = result.replaceAll(RegExp(r'(?<![А-Яа-яЁё])Ат(?![А-Яа-яЁё])'), 'Атк');
    return result;
  }

  static String _cleanText(String text) {
    return _applyReplacements(text).trim();
  }

  static String _stripGlyphMarkers(String text) {
    return text.replaceAll(RegExp(r'\(\d+\)?'), '').trim();
  }

  static double _minX(pn.OcrResult r) {
    if (r.points.isEmpty) return 0;
    return r.points.map((p) => p.x.toDouble()).reduce((a, b) => a < b ? a : b);
  }

  static double _maxX(pn.OcrResult r) {
    if (r.points.isEmpty) return 0;
    return r.points.map((p) => p.x.toDouble()).reduce((a, b) => a > b ? a : b);
  }

  static double _minY(pn.OcrResult r) {
    if (r.points.isEmpty) return 0;
    return r.points.map((p) => p.y.toDouble()).reduce((a, b) => a < b ? a : b);
  }

  static double _maxY(pn.OcrResult r) {
    if (r.points.isEmpty) return 0;
    return r.points.map((p) => p.y.toDouble()).reduce((a, b) => a > b ? a : b);
  }

  static double _centerY(pn.OcrResult r) => (_minY(r) + _maxY(r)) / 2;
  static double _centerX(pn.OcrResult r) => (_minX(r) + _maxX(r)) / 2;

  static String? _findStatName(pn.OcrResult r) {
    final text = _cleanText(r.text);
    if (text.isEmpty) return null;
    final cleaned = _stripGlyphMarkers(text);
    if (cleaned.isEmpty) return null;

    String norm(String s) =>
        s.replaceAll(RegExp(r'[\s\.]'), '').toUpperCase();

    final normalized = norm(cleaned);

    for (final stat in statNames) {
      if (normalized.contains(norm(stat))) return stat;
    }
    return null;
  }

  static bool _hasPercent(pn.OcrResult r) {
    final t = _cleanText(r.text);
    return t.contains('%') || t.endsWith(',');
  }

  static int? _extractNumber(pn.OcrResult r) {
    String text = _cleanText(r.text);
    text = text.replaceAll(RegExp(r'\(\d+\)?'), ' ');
    text = text.replaceAll(RegExp(r'\d+\)'), ' ');
    text = text.replaceAll(RegExp(r'\(\d+'), ' ');
    text = text.trim();
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

  static List<int> _extractAllNumbers(pn.OcrResult r) {
    String text = _cleanText(r.text);
    text = text.replaceAll(RegExp(r'\(\d+\)?'), ' ');
    text = text.trim();
    if (text.isEmpty) return [];

    final matches = RegExp(r'\d+').allMatches(text).toList();
    final result = <int>[];
    for (final m in matches) {
      final val = int.tryParse(m.group(0) ?? '');
      if (val != null && val >= 10) result.add(val);
    }
    return result;
  }

  static bool _isStatWithNumber(String text) {
    final cleaned = _cleanText(text);
    for (final stat in statNames) {
      if (cleaned.startsWith(stat)) {
        final rest = cleaned.substring(stat.length).trim();
        final stripped = rest.replaceAll(RegExp(r'\(\d+\)?'), '').trim();
        if (RegExp(r'^\d+$').hasMatch(stripped)) {
          final num = int.tryParse(stripped);
          if (num != null && num <= 9) return false;
          return true;
        }
      }
    }
    return false;
  }

  static bool _isStatWithTwoNumbers(String text) {
    final cleaned = _cleanText(text);
    for (final stat in statNames) {
      final pattern = RegExp('${RegExp.escape(stat)}[\\s\\d]+');
      if (pattern.hasMatch(cleaned)) {
        final matches = RegExp(r'\d+').allMatches(cleaned).toList();
        if (matches.length >= 2) return true;
      }
    }
    return false;
  }

  static void _parseStats(
    List<pn.OcrResult> mainBlocks,
    Map<String, List<int>> statsOut,
    Map<String, List<int>> percentOut,
    Map<String, List<int>> dopStatsOut,
    List<String> debugOut,
  ) {
    debugOut.add('[PARSER] _parseStats START, mainBlocks=${mainBlocks.length}');

    final leftBlocks = <pn.OcrResult>[];
    final rightBlocks = <pn.OcrResult>[];

    for (int idx = 0; idx < mainBlocks.length; idx++) {
      final r = mainBlocks[idx];
      if (r.points.isEmpty) continue;
      final cy = _centerY(r);
      final cx = _centerX(r);
      final text = _cleanText(r.text);

      if (cy > yMinForStats) continue;

      if (_isStatWithTwoNumbers(r.text)) {
        final nums = _extractAllNumbers(r);
        final statName = _findStatName(r);
        if (statName != null && nums.length >= 2) {
          debugOut.add('[ITER] #$idx → TWO-NUM: $statName = ${nums[0]} (dop=${nums[1]})');
          statsOut.putIfAbsent(statName, () => []).add(nums[0]);
          dopStatsOut.putIfAbsent(statName, () => []).add(nums[1]);
          continue;
        }
      }

      // === ПРОВЕРКА: доп-стат от звёзд формата "N NAME VALUE" (напр. "3 ATK 11") ===
      final starDopRe = RegExp(r'^([1-6])\s+([A-Z][A-Z.\s]*?)\s+(\d+)$');
      final starDopMatch = starDopRe.firstMatch(text.trim());
      if (starDopMatch != null) {
        final stars = int.tryParse(starDopMatch.group(1) ?? '');
        final dopName = starDopMatch.group(2)?.trim() ?? '';
        final dopVal = int.tryParse(starDopMatch.group(3) ?? '');
        if (stars != null && dopName.isNotEmpty && dopVal != null) {
          debugOut.add('[ITER] #$idx → STAR-DOP $dopName = $dopVal (stars=$stars)');
          dopStatsOut.putIfAbsent(dopName, () => []).add(dopVal);
          continue;
        }
      }

      final statName = _findStatName(r);

      // === ПРОВЕРКА: главный стат (DEF 143, ATK 143) — верхняя зона справа ===
      final isMainStatZone = cy < 220.0 && cx > 180.0;
      if (isMainStatZone && statName != null && _isStatWithNumber(r.text)) {
        final val = _extractNumber(r);
        if (val != null) {
          debugOut.add('[ITER] #$idx → MAIN-STAT $statName = $val');
          statsOut.putIfAbsent(statName, () => []).add(val);
          continue;
        }
      }

      if (statName != null && cx >= xSplit && _isStatWithNumber(r.text)) {
        final val = _extractNumber(r);
        if (val != null) {
          debugOut.add('[ITER] #$idx → DOP-STAT $statName = $val');
          if (statName == 'Метк' || statName == 'ACC') {
            dopStatsOut.putIfAbsent(statName, () => []).add(val);
          } else {
            statsOut.putIfAbsent(statName, () => []).add(val);
          }
        }
        continue;
      }

      if (_isStatWithNumber(r.text) && cx < xSplit) {
        leftBlocks.add(r);
        continue;
      }

      if (statName != null && cx < xSplit) {
        leftBlocks.add(r);
        continue;
      }
      if (cx >= xSplit && RegExp(r'\d').hasMatch(text)) {
        rightBlocks.add(r);
      }
    }

    debugOut.add('[PARSER] leftBlocks=${leftBlocks.length} rightBlocks=${rightBlocks.length}');

    for (final left in leftBlocks) {
      final statName = _findStatName(left);
      if (statName == null) continue;
      final leftY = _centerY(left);

      final selfValue = _extractNumber(left);
      if (_isStatWithNumber(left.text) && selfValue != null) {
        debugOut.add('[PARSER] MATCH (self): $statName = $selfValue');
        final list = statsOut.putIfAbsent(statName, () => []);
        if (!list.contains(selfValue)) list.add(selfValue);
        continue;
      }

      pn.OcrResult? bestNum;
      double bestDist = double.infinity;
      for (final right in rightBlocks) {
        final dy = (_centerY(right) - leftY).abs();
        if (dy < yThreshold && dy < bestDist) {
          bestNum = right;
          bestDist = dy;
        }
      }

      if (bestNum == null) {
        debugOut.add('[PARSER] NO MATCH for $statName');
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
    List<pn.OcrResult> mainBlocks, {
    List<pn.OcrResult> rightBlocks = const [],
    List<pn.OcrResult> iconBlocks = const [],
  }) {
    final result = <String, dynamic>{
      'set': null,
      'type': null,
      'rarity': null,
      'level': null,
      'stats': <String, List<int>>{},
      'stats_percent': <String, List<int>>{},
      'glyphs': <String, List<int>>{},
      'dop_stats': <String, List<int>>{},
      'set_bonus': null,
      'worn': null,
      'debug': <String>[],
    };

    try {
      final stats = result['stats'] as Map<String, List<int>>;
      final percents = result['stats_percent'] as Map<String, List<int>>;
      final dopStats = result['dop_stats'] as Map<String, List<int>>;
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
      if (wornMatch != null) {
        result['worn'] = wornMatch.group(1);
      } else {
        final wornEn = RegExp(r'(\d+/\d+)\s*Artifacts Equipped').firstMatch(allText);
        if (wornEn != null) result['worn'] = wornEn.group(1);
      }

      final bonusRu = RegExp(r'Комплект[:\s]*(\d+)\s*шт').firstMatch(allText);
      if (bonusRu != null) {
        result['set_bonus'] = '${bonusRu.group(1)} шт.';
      } else {
        final bonusEn = RegExp(r'New Bonus for every (\w+)').firstMatch(allText);
        if (bonusEn != null) {
          result['set_bonus'] = bonusEn.group(1);
        }
      }

      pn.OcrResult? topBlock;
      double minY = double.infinity;
      for (final r in mainBlocks) {
        if (r.points.isEmpty) continue;
        final cy = _centerY(r);
        final cx = _centerX(r);
        if (cy > yMaxForSet) continue;
        if (cx > xMaxForSet) continue;
        final text = _cleanText(r.text);
        if (text.length < 5) continue;
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
        String setName = _cleanText(topBlock.text);
        setName = setName.replaceFirst(
          RegExp(r'^\s*(Set|Сет)\s*[:\.]?\s*', caseSensitive: false), '');
        setName = setName.trim();
        result['set'] = setName.isEmpty ? null : setName;
      }

      _parseStats(mainBlocks, stats, percents, dopStats, debug);

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
