// Парсер сырого текста OCR для артефактов Raid
class ArtifactParser {
  static const Map<String, String> replacements = {
    'cYlwb': 'Скр',
    'cYlob': 'Зщт',
    'cowb': 'Зщт',
    'yyy': '',
    'уу': '',
    'Метв': 'Метк',
    'Мет': 'Метк',
    '3др': 'Здр',
    'Здр(1w': 'Здр(1)',
    'Здр(1': 'Здр(1)',
    'Ат (1': 'Атк(1)',
    'Атк(1w': 'Атк(1)',
    'сКрит': 'Крит',
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

  static Map<String, dynamic> parse(String rawText) {
    // Чистим текст
    String clean = rawText;
    replacements.forEach((old, newVal) {
      clean = clean.replaceAll(old, newVal);
    });

    final lines = clean
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

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

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Тип
      for (final t in types) {
        if (line.contains(t)) result['type'] = t;
      }

      // Редкость
      for (final r in rarities) {
        if (line.contains(r)) result['rarity'] = r;
      }

      // Уровень (+8, +12, +16)
      final levelMatch = RegExp(r'\+(\d{1,2})\b').firstMatch(line);
      if (levelMatch != null) {
        final lvl = int.tryParse(levelMatch.group(1) ?? '');
        if (lvl != null && [8, 12, 16].contains(lvl)) {
          result['level'] = lvl;
        }
      }

      // Надето
      final wornMatch = RegExp(r'Надето[:d\s]*(\d+/\d+)').firstMatch(line);
      if (wornMatch != null) {
        result['worn'] = wornMatch.group(1);
      }

      // Бонус сета
      final bonusMatch = RegExp(r'Комплект[:d\s]*(\d+)\s*шт').firstMatch(line);
      if (bonusMatch != null) {
        result['set_bonus'] = '${bonusMatch.group(1)} шт.';
      }

      // Статы + глифы
      for (final stat in statNames) {
        if (line.contains(stat) || line.startsWith(stat.substring(0, 3))) {
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1];
            final glyphMatch = RegExp(r'(\d+)[%]?\+?(\d+)').firstMatch(nextLine);
            final numMatch = RegExp(r'(\d+)').firstMatch(nextLine);

            if (glyphMatch != null) {
              final base = int.tryParse(glyphMatch.group(1) ?? '') ?? 0;
              final glyph = int.tryParse(glyphMatch.group(2) ?? '') ?? 0;
              (result['stats'] as Map<String, List<int>>).putIfAbsent(stat, () => []).add(base);
              (result['glyphs'] as Map<String, List<int>>).putIfAbsent(stat, () => []).add(glyph);
            } else if (numMatch != null) {
              final val = int.tryParse(numMatch.group(1) ?? '') ?? 0;
              if (val != 0) {
                (result['stats'] as Map<String, List<int>>).putIfAbsent(stat, () => []).add(val);
              }
            }
          }
          break;
        }
      }
    }

    if (lines.isNotEmpty) {
      result['set'] = lines[0];
    }

    return result;
  }
}
