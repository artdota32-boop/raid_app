import 'package:flutter_paddle_ocr_v5/flutter_paddle_ocr_v5.dart';
import 'dart:ui';

/// v3.1 — фиксы: краши, двойная склейка, мусор, глифы
class ArtifactParser {
  static const double yThreshold = 12.0;
  static const double xGapThreshold = 20.0;

  static const Map<String, String> replacements = {
    'cYlwb': 'Скр',
    'cYlob': 'Зщт',
    'cowb': 'Зщт',
    'cYYlowb': 'Скр',
    'сYlwb': 'Скр',
    'сYlob': 'Зщт',
    'Суровостьw': 'Суровость',
    'Небеснаяскорость': 'Небесная скорость',
    'Метв': 'Метк',
    'Мет': 'Метк',
    '3др': 'Здр',
    'Здр(1w': 'Здр(1)',
    'Здр(1': 'Здр(1)',
    'Ат (1': 'Атк(1)',
    'Атк(1w': 'Атк(1)',
    'Атк1': 'Атк',
    'сКрит': 'Крит',
    'сУwb': 'Скр',
    'ИТ.Ш': '',
    'ИТЛ': '',
  };

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

  // ===== ЗАЩИТА ОТ ПУСТЫХ POINTS =====
  static String _cleanText(String text) {
    String clean = text;
    replacements.forEach((old, newVal) {
      clean = clean.replaceAll(old, newVal);
    });
    return clean.trim();
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

  static List<List<OcrResult>> _groupByRows(List<OcrResult> blocks) {
    final valid = blocks.where((b) => b.points.isNotEmpty).toList();
    if (valid.isEmpty) return [];

    final sorted = List<OcrResult>.from(valid)
      ..sort((a, b) => _centerY(a).compareTo(_centerY(b)));

    final rows = <List<OcrResult>>[];
    for (final r in sorted) {
      if (rows.isEmpty) {
        rows.add([r]);
        continue;
      }
      final lastRow = rows.last;
      final lastY = lastRow.map(_centerY).reduce((a, b) => a + b) / lastRow.length;
      if ((_centerY(r) - lastY).abs() < yThreshold) {
        lastRow.add(r);
      } else {
        rows.add([r]);
      }
    }
    return rows;
  }

  static String _mergeRow(List<OcrResult> row) {
    final sorted = List<OcrResult>.from(row)
      ..sort((a, b) => _minX(a).compareTo(_minX(b)));

    final buf = StringBuffer();
    double? prevMaxX;
    for (final r in sorted) {
      final text = _cleanText(r.text);
      if (text.isEmpty) continue;

      if (prevMaxX != null) {
        final gap = _minX(r) - prevMaxX;
        buf.write(gap < xGapThreshold ? '' : ' ');
      }
      buf.write(text);
      prevMaxX = _maxX(r);
    }
    return buf.toString().trim();
  }

  /// Извлекает числа, отсеивая мусор (значения < 10 в скобках, остатки)
  static int? _extractNumber(String line) {
    final matches = RegExp(r'\d+').allMatches(line).toList();
    if (matches.isEmpty) return null;

    // Ищем самое длинное число (скорее всего, реальное значение)
    int? best;
    for (final m in matches) {
      final val = int.tryParse(m.group(0) ?? '');
      if (val == null) continue;
      // Отсеиваем мусор: числа 1-9 внутри скобок типа (2), (1)
      if (val < 10) continue;
      if (best == null || val > best) best = val;
    }
    // Если все мелкие — вернём первое валидное (для случаев "Крит. ш 5%")
    if (best == null) {
      for (final m in matches) {
        final val = int.tryParse(m.group(0) ?? '');
        if (val != null && val > 0) return val;
      }
    }
    return best;
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
      'glyphs': <String, List<int>>{},
      'set_bonus': null,
      'worn': null,
    };

    try {
      final rows = _groupByRows(mainBlocks);
      final rowTexts = rows.map(_mergeRow).toList();

      for (final line in rowTexts) {
        if (line.isEmpty) continue;

        for (final t in types) {
          if (line.contains(t)) result['type'] = t;
        }
        for (final r in rarities) {
          if (line.contains(r)) result['rarity'] = r;
        }

        final lvlMatch = RegExp(r'\+(\d{1,2})').firstMatch(line);
        if (lvlMatch != null) {
          final lvl = int.tryParse(lvlMatch.group(1) ?? '');
          if (lvl != null && [4, 8, 12, 16].contains(lvl)) {
            result['level'] = lvl;
          }
        }

        final wornMatch = RegExp(r'Надето[:\s]*(\d+/\d+)').firstMatch(line);
        if (wornMatch != null) result['worn'] = wornMatch.group(1);

        final bonusMatch = RegExp(r'Комплект[:\s]*(\d+)\s*шт').firstMatch(line);
        if (bonusMatch != null) {
          result['set_bonus'] = '${bonusMatch.group(1)} шт.';
        }
      }

      if (rowTexts.isNotEmpty) {
        final first = _cleanText(rowTexts.first);
        if (first.isNotEmpty && result['set'] == null) result['set'] = first;
      }

      // СТАТЫ — без двойной склейки
      for (final line in rowTexts) {
        for (final stat in statNames) {
          if (!line.contains(stat)) continue;
          // Извлекаем число после названия стата
          final m = RegExp('${RegExp.escape(stat)}[^\\d]{0,8}(\\d{1,5})')
              .firstMatch(line);
          if (m != null) {
            final val = int.tryParse(m.group(1) ?? '');
            if (val != null && val >= 10) {
              final list = (result['stats'] as Map<String, List<int>>)
                  .putIfAbsent(stat, () => []);
              if (!list.contains(val)) list.add(val);
            }
          }
          break;
        }
      }

      // Если стат не нашёлся по регекспу — пробуем _extractNumber
      if ((result['stats'] as Map).isEmpty) {
        for (final line in rowTexts) {
          for (final stat in statNames) {
            if (!line.contains(stat)) continue;
            final val = _extractNumber(line);
            if (val != null) {
              (result['stats'] as Map<String, List<int>>)
                  .putIfAbsent(stat, () => []).add(val);
            }
            break;
          }
        }
      }

      // ГЛИФЫ — только RIGHT-кроп, строгое совпадение
      if (rightBlocks.isNotEmpty) {
        final rightRows = _groupByRows(rightBlocks);
        for (final row in rightRows) {
          final line = _mergeRow(row);
          for (final stat in statNames) {
            if (!line.contains(stat)) continue;
            final m = RegExp('${RegExp.escape(stat)}[^\\d]{0,8}(\\d{1,5})')
                .firstMatch(line);
            if (m != null) {
              final val = int.tryParse(m.group(1) ?? '');
              if (val != null && val >= 10) {
                final list = (result['glyphs'] as Map<String, List<int>>)
                    .putIfAbsent(stat, () => []);
                if (!list.contains(val)) list.add(val);
              }
            }
            break;
          }
        }
      }

      // УРОВЕНЬ — fallback из ICON
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
