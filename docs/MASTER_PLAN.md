# Мастер-план gamesCheck

> **Единый источник правды для агентов.** Всегда читай перед задачей.

**Обновление:** 2026-03-01 | [DATA_DIAGRAM](DATA_DIAGRAM.md) | [QUICK_REF](QUICK_REF.md)

---

## ⛔ Правила (ОБЯЗАТЕЛЬНО)

1. **Читай MASTER_PLAN.md** в начале каждого запроса
2. **При изменении данных** — обновляй `docs/DATA_DIAGRAM.md` (entity, атрибуты, CloudKit, flow)
3. **При завершении задач** — обновляй этот файл (статус, дата)
4. **Не создавай новые .md** без явного разрешения. Обновляй существующие.
5. **CloudKit:** Small diffs → компиляция → проверка в Dashboard → следующий шаг

---

## Архитектура

**CloudKit = Source of Truth.** Core Data = локальный кэш. Pull из CloudKit полностью перезаписывает локальное.

**Public DB:** Game, GameWithPlayer, PlayerAlias, PlayerProfile, PlayerClaim, User  
**Private DB:** (PlayerProfile — частично Public после миграции)

---

## Текущий статус

**Рефакторинг ✅** (2026-03-01): print→debugLog (240+ замен), Persistence.swift разбит на 5 extension-файлов, крупные Views разбиты на компоненты (12 новых файлов), accessibility identifiers (32 штуки), Page Objects (5 страниц), unit-тесты (PendingSyncTracker, DeepLink, DataImportService), XCUITest сценарии, CI/CD (GitHub Actions), Cursor rules (5 файлов).

**Фаза 3 ✅** (2026-02-22): Витрины (smartSync, checksum), Push (CKSubscription), Игроки (isPublic, PlayersTabView), SuperAdmin (PlayerPublicProfileView), AppNotification, rebuildAllGameSummaries, pending claims fix.

**История:** Фаза 2 (Materialized Views, пагинация, Background Fetch) ✅ | PlayerProfile в Public DB ✅ | CloudKit Source of Truth ✅

---

## Правила при работе с CloudKit

- После изменения схемы → Dashboard → проверить record type / индекс
- После push → Dashboard → найти запись
- После pull → проверить Core Data (Debug или логи)
- Один метод/шаг за раз, не батчить изменения

---

## Структура проекта

- **Persistence**: `Persistence.swift` (core) + `Persistence+User.swift`, `Persistence+Game.swift`, `Persistence+PlayerProfile.swift`, `Persistence+PlayerAlias.swift`, `Persistence+PlayerClaim.swift`
- **Логирование**: `debugLog()` из `DebugLogger.swift` — все логи только в DEBUG
- **UI-компоненты**: `CasinoBackgroundModifier`, `CurrencyFormatting`, `PokerUIHelpers`, `PokerCardViews`
- **Тесты**: Swift Testing (unit) + XCTest (UI), моки в `FishAndChipsTests/Mocks/`, Page Objects в `FishAndChipsUITests/Pages/`
- **CI/CD**: `.github/workflows/ci.yml`
- **Cursor rules**: `.cursor/rules/` (5 файлов: swiftui-views, cloudkit-sync, core-data, testing, code-style)

---

## Ссылки

- CloudKit: `CloudKitService.swift`, `CloudKitSyncService.swift`
- Витрины: `MaterializedViewsService.swift`, `CloudKitMaterializedViews.swift`
- [DATA_DIAGRAM.md](DATA_DIAGRAM.md) | [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)

---

## Чеклист для агента

- [ ] Прочитал MASTER_PLAN.md
- [ ] Не создаю MD без разрешения
- [ ] Обновляю DATA_DIAGRAM при изменении данных
- [ ] Small diffs + проверка CloudKit
