# 🎮 RAID SCANNER

**Версия:** v3.5.41
**Стек:** Flutter 3.47.6 + paddle_ocr_native (PP-OCRv6) + snapframes + shared_preferences + image + package_info_plus
**Игра:** Raid: Shadow Legends (EN)
**Авторы:** Артурик + Дип

## 📖 ВИКИПЕДИЯ

См. PROJECT_HISTORY.md — вся история.

## 🚀 СБОРКА APK

git add -A && git commit -m "message" && git push

GitHub Actions собирает APK (~6 мин). Версия в AppBar = номер сборки.

## 🎯 ТЕКУЩЕЕ СОСТОЯНИЕ

- Точность рангов: 8/10
- crop: 50, 352, 470, 358
- icon: 90, 388, 90, 35, scale=2
- rank_lum=100, rank_min_count=10
- star_lum=150, star_offset=30
- rank override: set rank 0-6

## 🧪 ТЕСТ

1. Открыть приложение
2. Выбрать видео → кадр
3. REPL → parse
4. UI + Debug Log

## 📁 СТРУКТУРА

- lib/main.dart — UI + OCR + override + версия
- lib/parser.dart — парсер
- lib/repl_screen.dart — REPL
- assets/sets.json — 36 сетов
- PROJECT_HISTORY.md — вся история

## 🎭 СТИЛЬ

- Артурик — идеи, тесты
- Дип — код, логика
- Кодовое слово: «братик»

v3.5.41 — 16.10.2026
