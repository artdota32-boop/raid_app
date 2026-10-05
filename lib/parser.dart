import 'package:flutter_paddle_ocr_v5/flutter_paddle_ocr_v5.dart';
import 'dart:ui';

/// v3.3 — фиксы: replacements, игнор (), stats_percent
class ArtifactParser {
  static const double yThreshold = 15.0;
  static const double xGapThreshold = 25.0;
  static const double xSplit = 130.0;

  // ===== СЛОВАРЬ ЗАМЕН OCR (РАСШИРЕННЫЙ) =====
  static const Map<String, String> replacements = {
    // Скр
    'cYlwb': 'Скр',
    'cYlob': 'Зщт',
    'cowb': 'Зщт',
    'cYYlowb': 'Скр',
    'сYlwb': 'Скр',
    'сYlob': 'Зщт',
    'сYwb': 'Скр',
    'cYwb': 'Скр',
    'cYlowb': 'Скр',
    'Скb': 'Скр',
    'Ск(': 'Скр',
    'Скb(': 'Скр',
    'Скp': 'Скр',
    'Скв': 'Скр',
    // Здр
    '3др': 'Здр',
    '3др(': 'Здр(',
    'Здр(1w': 'Здр(1)',
    'Здр(1': 'Здр(1)',
    // Метк
    'Метв': 'Метк',
    'МеТ': 'Метк',
    'Метw': 'Метк',
    'Метv': 'Метк',
    'Мет(': 'Метк(',
    'Мет': 'Метк',
    // Атк
    'АТк': 'Атк',
    'Ат (1': 'Атк(1)',
    'Атк(1w': 'Атк(1)',
    'Атк1': 'Атк',
    'Атк(': 'Атк(',
    // Крит
    'сКрит': 'Крит',
    'Крит. ш(1': 'Крит. ш(1)',
    'Крит. (1': 'Крит. ш(1)',
    'Крит. (': 'Крит. ш(',
    'Крит. у(1': 'Крит. ур(1)',
    'Крит. у': 'Крит. ур',
    // Прочее
    'Суровостьw': 'Суровость',
    'Небеснаяскорость': 'Небесная скорость',
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

  /// Ищет название стата. Возвращает null, если блок содержит '(' (метка)
  static String? _findStatName(OcrResult r) {
    final text = _cleanText(r.text);
    if (text.isEmpty) return null;
    // Блок с '(' — это метка типа Здр(1), Атк(2) — не считаем за основной стат
    if (text.contains('(')) return null;
    for (final stat in statNames) {
      if (text.contains(stat)) return stat;
    }
    return null;
  }

  /// Проверяет, есть ли в блоке %
  static bool _hasPercent(OcrResult r) {
    return r.text.contains('%') || _cleanText(r.text).contains('%');
  }

  /// Извлекает число из блока
  static int? _extractNumber(OcrResult r) {
    final text = _cleanText(r.text);
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
  ) {
    final leftBlocks = <OcrResult>[];
    final rightBlocks = <OcrResult>[];

    for (final r in mainBlocks) {
      if (r.points.isEmpty) continue;
      final cx = (_minX(r) + _maxX(r)) / 2;
      final text = _cleanText(r.text);

      final statName = _findStatName(r);
      if (statName != null && cx < xSplit) {
        leftBlocks.add(r);
        continue;
      }
      if (cx >= xSplit && RegExp(r'\d').hasMatch(text)) {
        rightBlocks.add(r);
      }
    }

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

      if (bestNum == null) continue;
      final value = _extractNumber(bestNum);
      if (value == null) continue;

      if (_hasPercent(bestNum)) {
        final list = percentOut.putIfAbsent(statName, () => []);
        if (!list.contains(value)) list.add(value);
      } else {
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
      'stats_percent': <String, List<int>>{},
      'glyphs': <String, List<int>>{},
      'set_bonus': null,
      'worn': null,
    };

    try {
      final stats = result['stats'] as Map<String, List<int>>;
      final percents = result['stats_percent'] as Map<String, List<int>>;

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

      // Сет — первый блок, если не тип/редкость
      if (mainBlocks.isNotEmpty) {
        final first = _cleanText(mainBlocks.first.text);
        if (first.isNotEmpty && !types.contains(first) && !rarities.contains(first)) {
          result['set'] = first;
        }
      }

      // СТАТЫ — главная логика
      _parseStats(mainBlocks, stats, percents);

      // УРОВЕНЬ из ICON
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
