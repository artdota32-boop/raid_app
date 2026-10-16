# 📜 RAID SCANNER — PROJECT HISTORY (WIKI)

**Версия:** v3.5.41
**Дата:** 16.10.2026
**Стек:** Flutter 3.47.6 + paddle_ocr_native ^0.1.0 (PP-OCRv6) + snapframes ^0.0.1 + shared_preferences ^2.2.2 + image ^4.1.0 + package_info_plus ^8.0.0
**Игра:** Raid: Shadow Legends (EN), 720×1600
**Авторы:** Артурик + Дип

## 🎯 ЧТО ЗА ПРОЕКТ

Raid Scanner — мобильное приложение (Flutter):
1. Кадр из видео Raid: Shadow Legends
2. MAIN-кроп карточки артефакта
3. OCR (PP-OCRv6)
4. Парсинг (MAIN / DOP / глифы / уровни / ранги)
5. Вывод в UI
6. Override ранга (вручную через REPL)

## 📁 СТРУКТУРА

raid_app/
├── lib/
├── assets/
├── screenshots/
├── logs/
├── .github/workflows/build.yml
├── pubspec.yaml
├── PROJECT_HISTORY.md
└── README.md

## 🎯 АКТИВНЫЕ КООРДИНАТЫ (prefs)

| Ключ | Значение |
|---|---|
| crop_x | 50 |
| crop_y | 352 |
| crop_w | 470 |
| crop_h | 358 |
| crop_scale | 3 |
| icon_x | 90 |
| icon_y | 388 |
| icon_w | 90 |
| icon_h | 35 |
| icon_scale | 2 |
| isMainStatY1 | 160 |
| isMainStatY2 | 320 |
| setDescCy | 700 |
| rank_lum | 100 |
| rank_min_count | 10 |
| star_lum | 150 |
| star_offset | 30 |
| rank | 0 |

## 🔥 ИСТОРИЯ ВЕРСИЙ

### v3.0 — базовая (PP-OCRv6)
### v3.4.0 — парсер _parseStats, MAIN-кроп
### v3.5.5 — глифы (GLYPH-паттерн)
### v3.5.6 — DOP-статы
### v3.5.7 — TWO-STAT
### v3.5.8 — нормализация (_normForIsStat)
### v3.5.9 — MAIN-кроп расширен
### v3.5.10 — xSplit 130→250, isMainStatZone
### v3.5.11 — все параметры в prefs
### v3.5.12 — crop_y=352 (фикс уровня)
### v3.5.19 — новый UI + ранг
### v3.5.30 — ГИБРИД: color + счёт звёзд
### v3.5.34 — фикс двойного кропа
### v3.5.36 — 3 фикса + override
### v3.5.37 — override prefs
### v3.5.38 — override в _runOcr
### v3.5.39 — версия в UI (package_info_plus)
### v3.5.40 — авто-версия (GitHub run_number)
### v3.5.41 — УВЕЛИЧЕНИЕ ×2 + runLength 10 (ТЕКУЩАЯ)

## 🐛 БАГИ

| # | Баг | Причина | Фикс | Статус |
|---|---|---|---|---|
| 1 | MAIN→DOP | cy<220 устарело | isMainStatZone 160<cy<320 | ✅ |
| 2 | Стат без числа | _isStatWithNumber | fallback leftBlocks | ✅ |
| 3 | xSplit=130 режет | left cx=133-179 | xSplit=250 | ✅ |
| 4 | fuzzy на числах | levenshtein | regex ^[\d]+$ → null | ✅ |
| 5 | _isStatWithNumber FALSE | DEF/SPD без числа | fallback | ✅ |
| 6 | Описание сета | cy<550 | setDescCy=700 | ✅ |
| 7 | Тип из Set: X | contains | startsWith('Set:') | ⏳ |
| 8 | TWO-STAT | порядок | sort indexOf | ⏳ |
| 9 | Уровень ? | +12 не в кропе | crop_y=352 | ✅ |
| 10 | ATK 11 → 3ATK | OCR | гибрид crop_x=50 | ✅ |
| 11 | +16 → 4+16 | OCR | scale=3 | ✅ |
| 12 | C. DMG → C. DG | OCR | fallback | ✅ |
| 13 | (N) в extractNumber | regex | исключён \(.*?\) | ✅ |
| 14 | 6★ → 5★ | один цвет | гибрид счёт звёзд | 🟡 |
| 15 | 4★ → 3★ Epic | фиолет фон | g4+40 | 🟡 |
| 16 | Cruel 5★ → 6★ | JPG-шум | runLength 5→10 | 🟡 |
| 17 | Swift Parry 5★ → 4★ | empowerment | гибрид | 🟡 |

## 📊 ПРОГОН 10 ШМОТОК (v3.5.40)

| # | Шмотка | Реал | UI | Статус |
|---|---|---|---|---|
| 1 | Instinct | 5★ | 5★ | ✅ |
| 2 | Feral | 6★ | 6★ | ✅ |
| 3 | Protection | 5★ | 5★ | ✅ |
| 4 | Swift Parry | 5★ | 4★ | 🔴 |
| 5 | Cruel | 5★ | 6★ | 🔴 |
| 6 | Speed | 5★ | 5★ | ✅ |
| 7 | Relentless | 6★ | 6★ | ✅ |
| 8 | Stalwart | 6★ | 6★ | ✅ |
| 9 | Divine Life | 5★ | 5★ | ✅ |
| 10 | Perception | 6★ | 6★ | ✅ |

**8/10 — отлично!**

## ✅ РАБОТАЕТ

- ✅ Уровень (+8, +12, +16)
- ✅ MAIN-стат
- ✅ DOP (🟣 empowerment)
- ✅ Глифы N%+M% (с % для процентных)
- ✅ Проценты
- ✅ Тип, сет, редкость
- ✅ Бонус сета (36)
- ✅ REPL set/get/reset/parse
- ✅ Override ранга
- ✅ Версия в AppBar
- ✅ Авто-версия из GitHub
- ✅ Ранги 1★-6★ (8/10)

## ⚠️ НЕ РАБОТАЕТ

- 🟡 Swift Parry 5★ → 4★ (фиолет + Epic фон)
- 🟡 Cruel 5★ → 6★ (шум)

## 🎯 СЛЕДУЮЩИЕ ШАГИ

1. Тест #169 (×2 + runLength 10)
2. Если 10/10 — победа
3. Если нет — фикс
4. Затем — Batch
5. Потом — Оптимизатор
6. YOLO — если 8/10 мало

## 🎭 СТИЛЬ

- Обращение: Артурик / братик
- Тон: дружеский, живой, с юмором
- Формат: пункты, таблицы, эмодзи
- Без воды, по делу
- Кодовое слово: «братик»

## 💡 ФИЛОСОФИЯ

- По одному фиксу
- По одной шмотке
- Full log
- Git откат
- REPL эксперименты
- Версия в UI

**Последнее обновление:** v3.5.41
**Дата:** 16.10.2026
