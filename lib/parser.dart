import 'dart:ui' as ui;
import 'package:paddle_ocr_native/paddle_ocr_native.dart' as pn;

/// v3.4.0 — parser под paddle_ocr_native (PP-OCRv6)
class ArtifactParser {
  static const double yThreshold = 15.0;
  static const double xGapThreshold = 25.0;
  static const double xSplit = 250.0;
  // ФИКС v3.5.9-3: фильтры под новый MAIN-кроп (y:100..780)
  static const double yMaxForSet = 700.0;
  static const double yMinForStats = 900.0;
  static const double xMaxForSet = 700.0;

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
    'Gauntlets', 'Gauntlet',
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

  // ФИКС v3.5.8: FUZZY matching (расстояние Левенштейна)
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((v, e) => v < e ? v : e);
      }
      for (int k = 0; k <= b.length; k++) {
        prev[k] = curr[k];
      }
    }
    return prev[b.length];
  }

  // ФИКС v3.5.8: fuzzy поиск стата (расстояние ≤ 2)
  static String? _fuzzyFindStat(String normalized, [List<String>? debugOut]) {
    String? best;
    int bestDist = 3;  // порог ≤ 2
    for (final stat in statNames) {
      final statNorm = stat.replaceAll(RegExp(r'[\s\.]'), '').toUpperCase();
      final dist = _levenshtein(normalized, statNorm);
      if (dist < bestDist) {
        bestDist = dist;
        best = stat;
      }
    }
    if (best != null) {
      debugOut?.add('[FUZZY] "$normalized" → "$best" (dist=$bestDist)');
      return best;
    }
    return null;
  }

  static String? _findStatName(pn.OcrResult r, [List<String>? debugOut]) {
    final text = _cleanText(r.text);
    debugOut?.add('[FINDSTAT] input="$text"');
    if (text.isEmpty) { debugOut?.add('[FINDSTAT] → null (empty)'); return null; }
    final cleaned = _stripGlyphMarkers(text);
    if (cleaned.isEmpty) { debugOut?.add('[FINDSTAT] → null (cleaned empty)'); return null; }

    String norm(String s) => s
        // ФИКС v3.5.6: латинские с ударением → обычные
        // ФИКС v3.5.6: Á→A
        .replaceAll('Á', 'A').replaceAll('á', 'a')
        .replaceAll('É', 'E').replaceAll('é', 'e')
        .replaceAll('Í', 'I').replaceAll('í', 'i')
        .replaceAll('Ó', 'O').replaceAll('ó', 'o')
        .replaceAll('Ú', 'U').replaceAll('ú', 'u')
        // ФИКС v3.5.7: À→A (гравис)
        .replaceAll('À', 'A').replaceAll('à', 'a')
        .replaceAll('È', 'E').replaceAll('è', 'e')
        .replaceAll('Ì', 'I').replaceAll('ì', 'i')
        .replaceAll('Ò', 'O').replaceAll('ò', 'o')
        .replaceAll('Ù', 'U').replaceAll('ù', 'u')
        // Йотированные
        .replaceAll('Â', 'A').replaceAll('â', 'a')
        .replaceAll('Ê', 'E').replaceAll('ê', 'e')
        .replaceAll('Î', 'I').replaceAll('î', 'i')
        .replaceAll('Ô', 'O').replaceAll('ô', 'o')
        .replaceAll('Û', 'U').replaceAll('û', 'u')
        .replaceAll(RegExp(r'[\s\.]'), '').toUpperCase();

    final normalized = norm(cleaned);
    debugOut?.add('[FINDSTAT] cleaned="$cleaned" normalized="$normalized"');

    for (final stat in statNames) {
      final statNorm = norm(stat);
      if (normalized.contains(statNorm)) {
        debugOut?.add('[FINDSTAT] → MATCH "$stat" (statNorm="$statNorm")');
        return stat;
      }
    }
    // ФИКС v3.5.8: fuzzy fallback
    final fuzzy = _fuzzyFindStat(normalized, debugOut);
    if (fuzzy != null) {
      debugOut?.add('[FINDSTAT] → FUZZY "$fuzzy"');
      return fuzzy;
    }
    debugOut?.add('[FINDSTAT] → null (no match)');
    return null;
  }

  // ФИКС v3.5.8: нормализация для _isStatWithNumber
  static String _normForIsStat(String s) {
    return s
        .replaceAll('À', 'A').replaceAll('Á', 'A').replaceAll('Â', 'A')
        .replaceAll('È', 'E').replaceAll('É', 'E').replaceAll('Ê', 'E')
        .replaceAll('Ì', 'I').replaceAll('Í', 'I').replaceAll('Î', 'I')
        .replaceAll('Ò', 'O').replaceAll('Ó', 'O').replaceAll('Ô', 'O')
        .replaceAll('Ù', 'U').replaceAll('Ú', 'U').replaceAll('Û', 'U')
        .replaceAll('Ġ', 'G').replaceAll('ġ', 'g')
        .replaceAll(RegExp(r'[\s\.]'), '').toUpperCase();
  }

  static bool _hasPercent(pn.OcrResult r, [List<String>? debugOut]) {
    final t = _cleanText(r.text);
    final result = t.contains('%') || t.endsWith(',');
    debugOut?.add('[HASPERCENT] text="$t" → $result');
    return result;
  }

  static int? _extractNumber(pn.OcrResult r, [List<String>? debugOut]) {
    String text = _cleanText(r.text);
    final original = text;
    text = text.replaceAll(RegExp(r'\(\d+\)?'), ' ');
    text = text.replaceAll(RegExp(r'\d+\)'), ' ');
    text = text.replaceAll(RegExp(r'\(\d+'), ' ');
    text = text.trim();
    debugOut?.add('[EXTRACT] input="$original" cleaned="$text"');
    if (text.isEmpty) { debugOut?.add('[EXTRACT] → null (empty)'); return null; }

    final matches = RegExp(r'\d+').allMatches(text).toList();
    debugOut?.add('[EXTRACT] matches=${matches.map((m) => m.group(0)).toList()}');
    if (matches.isEmpty) { debugOut?.add('[EXTRACT] → null (no matches)'); return null; }

    int? best;
    for (final m in matches) {
      final val = int.tryParse(m.group(0) ?? '');
      if (val == null) continue;
      if (val < 10) continue;
      if (best == null || val > best) best = val;
    }
    if (best != null) { debugOut?.add('[EXTRACT] → best=$best'); return best; }
    for (final m in matches) {
      final val = int.tryParse(m.group(0) ?? '');
      if (val != null && val > 0) { debugOut?.add('[EXTRACT] → fallback=$val'); return val; }
    }
    debugOut?.add('[EXTRACT] → null');
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

  static bool _isStatWithNumber(String text, [List<String>? debugOut]) {
    final cleaned = _cleanText(text);
    debugOut?.add('[ISSTAT] input="$cleaned"');
    // ФИКС v3.5.8: нормализация для сравнения
    final normCleaned = _normForIsStat(cleaned);
    for (final stat in statNames) {
      final normStat = _normForIsStat(stat);
      if (normCleaned.startsWith(normStat)) {
        // ФИКС v3.5.8: rest берём из normCleaned (нормализовано)
        final rest = normCleaned.substring(normStat.length).trim();
        final stripped = rest.replaceAll(RegExp(r'\(\d+\)?'), '').trim();
        debugOut?.add('[ISSTAT]   stat="$stat" rest="$rest" stripped="$stripped"');
        if (RegExp(r'^\d+$').hasMatch(stripped)) {
          final num = int.tryParse(stripped);
          if (num != null && num <= 9) {
            debugOut?.add('[ISSTAT]   → false (num<=9: $num)');
            return false;
          }
          debugOut?.add('[ISSTAT]   → TRUE (num=$num)');
          return true;
        }
        // ФИКС v3.5.4: если осталась только скобка "(N)" без числа — валидный стат
        if (rest.isNotEmpty && RegExp(r'^\(\d+\)?$').hasMatch(rest)) {
          debugOut?.add('[ISSTAT]   → TRUE (glyph-only "$rest")');
          return true;
        }
        // ФИКС v3.5.5: число с процентом "33%" или "33%+4%" — валидный стат
        if (RegExp(r'^\d+\%').hasMatch(stripped)) {
          debugOut?.add('[ISSTAT]   → TRUE (percent "$stripped")');
          return true;
        }
      }
    }
    debugOut?.add('[ISSTAT] → false (no match)');
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

  // ФИКС v3.5.5-4: определение глифа "N%+M%" или "N+M"
  static bool _hasGlyphPattern(String text, [List<String>? debugOut]) {
    final t = _cleanText(text).trim();
    // Паттерн: число%+число% или число+число
    final re = RegExp(r'^(\d+%?)\+(\d+%?)$');
    final match = re.hasMatch(t);
    debugOut?.add('[GLYPH] check "$t" → $match');
    return match;
  }

  // ФИКС v3.5.5-4: извлечь базу и глиф
  static Map<String, int> _extractBaseAndGlyph(String text, [List<String>? debugOut]) {
    final t = _cleanText(text).trim();
    final re = RegExp(r'^(\d+)%?\+(\d+)%?$');
    final m = re.firstMatch(t);
    if (m == null) {
      debugOut?.add('[GLYPH] extract "$t" → null');
      return {};
    }
    final base = int.tryParse(m.group(1) ?? '');
    final glyph = int.tryParse(m.group(2) ?? '');
    debugOut?.add('[GLYPH] extract "$t" → base=$base glyph=$glyph');
    if (base == null || glyph == null) return {};
    return {'base': base, 'glyph': glyph};
  }

  static void _parseStats(
    List<pn.OcrResult> mainBlocks,
    Map<String, List<int>> statsOut,
    Map<String, List<int>> percentOut,
    Map<String, List<int>> dopStatsOut,
    Map<String, List<int>> glyphsOut,
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
        final statName = _findStatName(r, debugOut);
        if (statName != null && nums.length >= 2) {
          // ФИКС v3.5.7: если в блоке ДВА имени статов — разделить
          final cleanT = _cleanText(r.text).toUpperCase();
          final foundStats = <String>[];
          for (final s in statNames) {
            if (cleanT.contains(s.replaceAll('.', '').replaceAll(' ', '').toUpperCase())) {
              foundStats.add(s);
            }
          }
          if (foundStats.length >= 2) {
            // Два разных стата: первое → stats, второе → dop
            debugOut.add('[ITER] #$idx → TWO-STAT: ${foundStats[0]}=${nums[0]} ${foundStats[1]}=${nums[1]}');
            statsOut.putIfAbsent(foundStats[0], () => []).add(nums[0]);
            dopStatsOut.putIfAbsent(foundStats[1], () => []).add(nums[1]);
            continue;
          }
          // Иначе — обычный TWO-NUM (осн + доп того же стата)
          debugOut.add('[ITER] #$idx → TWO-NUM: $statName = ${nums[0]} (dop=${nums[1]})');
          statsOut.putIfAbsent(statName, () => []).add(nums[0]);
          dopStatsOut.putIfAbsent(statName, () => []).add(nums[1]);
          continue;
        }
      }

      debugOut.add('[ZONE] #$idx text="$text" cx=${cx.toStringAsFixed(0)} cy=${cy.toStringAsFixed(0)} statName=${_findStatName(r)}');

      // === ФИКС v3.5.5-4: глиф "N%+M%" или "N+M" ===
      if (_hasGlyphPattern(r.text, debugOut) && cx >= xSplit) {
        final pair = _extractBaseAndGlyph(r.text, debugOut);
        if (pair.isNotEmpty) {
          // Ищем имя стата по Y-совпадению в leftBlocks
          String? glyphStat;
          double bestDy = double.infinity;
          for (final lb in leftBlocks) {
            final dy = (_centerY(lb) - cy).abs();
            if (dy < yThreshold && dy < bestDy) {
              glyphStat = _findStatName(lb);
              bestDy = dy;
            }
          }
          if (glyphStat != null) {
            debugOut.add('[ITER] #$idx → GLYPH $glyphStat base=${pair['base']} glyph=${pair['glyph']}');
            final baseVal = pair['base']!;
            final glyphVal = pair['glyph']!;
            // База → stats/percent
            if (_hasPercent(r, debugOut)) {
              percentOut.putIfAbsent(glyphStat, () => []).add(baseVal);
            } else {
              statsOut.putIfAbsent(glyphStat, () => []).add(baseVal);
            }
            // Глиф → glyphsOut
            glyphsOut.putIfAbsent(glyphStat, () => []).add(glyphVal);
            continue;
          }
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
      final isMainStatZone = cy > 660.0 && cy < 745.0 && cx > 180.0 && cx < 500.0;
      if (isMainStatZone && statName != null && _isStatWithNumber(r.text, debugOut)) {
        final val = _extractNumber(r, debugOut);
        if (val != null) {
          // ФИКС v3.5.5-1b: если есть "%" → в percentOut
          if (_hasPercent(r, debugOut)) {
            debugOut.add('[ITER] #$idx → MAIN-STAT% $statName = $val [ZONE cx=$cx cy=$cy]');
            percentOut.putIfAbsent(statName, () => []).add(val);
          } else {
            debugOut.add('[ITER] #$idx → MAIN-STAT $statName = $val [ZONE cx=$cx cy=$cy]');
            statsOut.putIfAbsent(statName, () => []).add(val);
          }
          continue;
        }
      }

      if (statName != null && cx >= xSplit && _isStatWithNumber(r.text, debugOut)) {
        final val = _extractNumber(r, debugOut);
        if (val != null) {
          debugOut.add('[ITER] #$idx → DOP-STAT $statName = $val');
          // ФИКС v3.5.6: любой DOP-стат → в dopStatsOut
          dopStatsOut.putIfAbsent(statName, () => []).add(val);
          continue;
        }
        // ФИКС v3.5.5-2: glyph-only (C. DMG(1)) и cx < 350 → в leftBlocks
        if (val == null && cx < 350.0) {
          debugOut.add('[ITER] #$idx → LEFT-FALLBACK $statName (cx=$cx < 350)');
          leftBlocks.add(r);
          continue;
        }
        continue;
      }

      if (_isStatWithNumber(r.text, debugOut) && cx < xSplit) {
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

      final selfValue = _extractNumber(left, debugOut);
      if (_isStatWithNumber(left.text, debugOut) && selfValue != null) {
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

      final value = _extractNumber(bestNum, debugOut);
      if (value == null) continue;

      debugOut.add('[PARSER] MATCH: $statName = $value (from "${bestNum.text}" dy=$bestDist)');

      if (_hasPercent(bestNum, debugOut)) {
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
      final glyphs = result['glyphs'] as Map<String, List<int>>;
      final debug = result['debug'] as List<String>;

      final allText = mainBlocks.map((r) => _cleanText(r.text)).join(' | ');

      // ФИКС v3.5.9-4: тип ищем в зоне карточки (cy < 700 — под новый MAIN-кроп)
      for (final r in mainBlocks) {
        if (r.points.isEmpty) continue;
        final cy = _centerY(r);
        if (cy > 700) continue;
        final text = _cleanText(r.text);
        for (final t in types) {
          if (text.contains(t)) { result['type'] = t; break; }
        }
        if (result['type'] != null) break;
      }
      for (final r in rarities) {
        if (allText.contains(r)) { result['rarity'] = r; break; }
      }

      // ФИКС v3.5.5-3: OCR может дать "+1.2" вместо "+12" — убираем точки
      final cleanAllText = allText.replaceAll('.', '');
      final lvlMatch = RegExp(r'\+(\d{1,2})').firstMatch(cleanAllText);
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
        } else {
          final bonusPieces = RegExp(r'(\d+)\s+Artifacts per Set').firstMatch(allText);
          if (bonusPieces != null) {
            result['set_bonus'] = '${bonusPieces.group(1)} pcs';
          }
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

      _parseStats(mainBlocks, stats, percents, dopStats, glyphs, debug);

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
