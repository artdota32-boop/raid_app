import 'package:flutter_paddle_ocr_v5/flutter_paddle_ocr_v5.dart';
import 'dart:ui';

/// v3.2 — связка «название + значение» по координатам
class ArtifactParser {
  static const double yThreshold = 15.0; // строки
  static const double xGapThreshold = 25.0; // склейка чисел
  static const double xSplit = 130.0; // граница: название (слева) / значение (справа)

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

  // ===== ВСПОМОГАТЕЛЬНЫЕ =====
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

  /// Ищет название стата в блоке
  static String? _findStatName(OcrResult r) {
    final text = _cleanText(r.text);
    if (text.isEmpty) return null;
    for (final stat in statNames) {
      if (text.contains(stat)) return stat;
    }
    return null;
  }

  /// Извлекает число из блока (или null)
  static int? _extractNumber(OcrResult r) {
    final text = _cleanText(r.text);
    if (text.isEmpty) return null;

    // Ищем все числа в блоке
    final matches = RegExp(r'\d+').allMatches(text).toList();
    if (matches.isEmpty) return null;

    // Ищем самое длинное число (реальное значение)
    int? best;
    for (final m in matches) {
      final val = int.tryParse(m.group(0) ?? '');
      if (val == null) continue;
      if (val < 10) continue; // мусор (номера в скобках)
      if (best == null || val > best) best = val;
    }
    if (best != null) return best;

    // Если только мелкие — вернуть первое > 0
    for (final m in matches) {
      final val = int.tryParse(m.group(0) ?? '');
      if (val != null && val > 0) return val;
    }
    return null;
  }

  /// ГЛАВНАЯ ЛОГИКА: парсит статы из MAIN-кропа,
  /// связывая название (слева) и значение (справа) по Y
  static void _parseStats(
    List<OcrResult> mainBlocks,
    Map<String, List<int>> statsOut,
    Map<String, List<int>> glyphsOut,
  ) {
    // 1. Разделяем блоки: названия статов (слева) и числа (справа)
    final leftBlocks = <OcrResult>[]; // названия
    final rightBlocks = <OcrResult>[]; // значения

    for (final r in mainBlocks) {
      if (r.points.isEmpty) continue;
      final cx = (_minX(r) + _maxX(r)) / 2;
      final text = _cleanText(r.text);

      // Название стата — левый край
      final statName = _findStatName(r);
      if (statName != null && cx < xSplit) {
        leftBlocks.add(r);
        continue;
      }

      // Число — правый край
      if (cx >= xSplit && RegExp(r'\d').hasMatch(text)) {
        rightBlocks.add(r);
      }
    }

    // 2. Для каждого названия ищем ближайшее число справа по Y
    for (final left in leftBlocks) {
      final statName = _findStatName(left);
      if (statName == null) continue;

      final leftY = _centerY(left);

      // Ищем блок-число, ближайший по Y (в пределах yThreshold)
      OcrResult? bestNum;
      double bestDist = double.infinity;
      for (final right in rightBlocks) {
        final dy = (_centerY(right) - leftY).abs();
        if (dy < yThreshold && dy < bestDist) {
          bestNum = right;
          bestDist = dy;
        }
      }

      int? value;
      if (bestNum != null) {
        value = _extractNumber(bestNum);
      }

      if (value != null) {
        final list = statsOut.putIfAbsent(statName, () => []);
        if (!list.contains(value)) list.add(value);
      }
    }
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
      final stats = result['stats'] as Map<String, List<int>>;
      final glyphs = result['glyphs'] as Map<String, List<int>>;

      // === СЕТ / ТИП / РЕДКОСТЬ / УРОВЕНЬ / НАДЕТО / БОНУС ===
      final allText = mainBlocks.map((r) => _cleanText(r.text)).join(' | ');

      for (final t in types) {
        if (allText.contains(t)) {
          result['type'] = t;
          break;
        }
      }
      for (final r in rarities) {
        if (allText.contains(r)) {
          result['rarity'] = r;
          break;
        }
      }

      // Уровень (из основного текста)
      final lvlMatch = RegExp(r'\+(\d{1,2})').firstMatch(allText);
      if (lvlMatch != null) {
        final lvl = int.tryParse(lvlMatch.group(1) ?? '');
        if (lvl != null && [4, 8, 12, 16].contains(lvl)) {
          result['level'] = lvl;
        }
      }

      // Надето
      final wornMatch = RegExp(r'Надето[:\s]*(\d+/\d+)').firstMatch(allText);
      if (wornMatch != null) result['worn'] = wornMatch.group(1);

      // Бонус сета
      final bonusMatch =
          RegExp(r'Комплект[:\s]*(\d+)\s*шт').firstMatch(allText);
      if (bonusMatch != null) {
        result['set_bonus'] = '${bonusMatch.group(1)} шт.';
      }

      // Сет — из первого блока, если есть
      if (mainBlocks.isNotEmpty) {
        final first = _cleanText(mainBlocks.first.text);
        if (first.isNotEmpty && !types.contains(first) &&
            !rarities.contains(first)) {
          result['set'] = first;
        }
      }

      // === СТАТЫ (главный фикс) ===
      _parseStats(mainBlocks, stats, glyphs);

      // === ГЛИФЫ из RIGHT-кропа ===
      if (rightBlocks.isNotEmpty) {
        _parseStats(rightBlocks, glyphs, glyphs);
      }

      // === УРОВЕНЬ из ICON-кропа ===
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
