# Мастер-план gamesCheck

> **Единый источник правды для агентов.** Всегда читай перед задачей.

**Обновление:** 2026-03-18 | [DATA_DIAGRAM](DATA_DIAGRAM.md) | [QUICK_REF](QUICK_REF.md)

---

## ⛔ Правила (ОБЯЗАТЕЛЬНО)

1. **Читай MASTER_PLAN.md** в начале каждого запроса
2. **При изменении данных** — обновляй `docs/DATA_DIAGRAM.md` (entity, атрибуты, schema, flow)
3. **При завершении задач** — обновляй этот файл (статус, дата)
4. **Не создавай новые .md** без явного разрешения. Обновляй существующие.
5. **Supabase:** Small diffs → компиляция → проверка в Dashboard → следующий шаг

---

## Архитектура

**МИГРАЦИЯ: CloudKit → Supabase (в процессе)**

**Supabase = Source of Truth (целевое).** Core Data = локальный кэш.  
**BackendSwitch** — feature flag для переключения CloudKit/Supabase.  
**SyncRouter** — единая точка доступа к sync (маршрутизирует вызовы в активный бэкенд).

**Supabase таблицы:** profiles (User+PlayerProfile), games, game_players, player_aliases, player_claims, billiard_batches, device_tokens  
**Materialized views (PostgreSQL):** game_summaries, user_statistics  
**RLS:** Row Level Security на всех таблицах  
**Realtime:** WebSocket подписки на games, claims, profiles

**CloudKit (legacy, до удаления):**  
Public DB: Game, GameWithPlayer, PlayerAlias, PlayerProfile, PlayerClaim, User

---

## Текущий статус

**Миграция CloudKit → Supabase ✅** (2026-03-18):
- ✅ Phase 0: SPM supabase-swift 2.41.1, SupabaseConfig, BackendServiceProtocol
- ✅ Phase 1: SQL schema (001_initial_schema.sql) — таблицы, RLS, triggers, materialized views
- ✅ Phase 2: DTO (SupabaseDTO.swift, SupabaseModelConverters.swift)
- ✅ Phase 3: SupabaseAuthService (Supabase Auth, bcrypt)
- ✅ Phase 4: SupabaseService (CRUD обёртка, retry, ошибки)
- ✅ Phase 5: SupabaseSyncService (push/pull, smart sync, merge, pending)
- ✅ Phase 6: SupabaseRealtimeService (WebSocket подписки)
- ✅ Phase 7: SyncRouter + BackendSwitch (переключение бэкендов)
- ✅ Phase 8: Тесты (MockSupabaseService/Auth, DTO, Errors, BackendSwitch)
- ✅ Phase 9: DataMigrationToSupabase (клиентская миграция)
- ✅ Phase 10: DATA_DIAGRAM v3.0, Cursor rules
- ✅ Phase 11: Improvements (GDPR deletion, OfflineSyncQueue, Edge Function push, server validation)

**Предыдущие:** Push fix ✅ | Рефакторинг ✅ | Фаза 3 ✅ | Фаза 2 ✅

---

## Правила при работе с Supabase

- После изменения схемы → SQL migration файл → `supabase db push`
- Проверять RLS-политики после изменения таблиц
- Small diffs: один сервис/метод за раз, не батчить
- BackendSwitch.isSupabase — проверять перед sync вызовами

---

## Структура проекта

- **Persistence**: `Persistence.swift` (core) + `Persistence+*.swift` (5 extension-файлов)
- **Supabase**: `Services/Supabase/` — SupabaseConfig, SupabaseService, SupabaseAuthService, SupabaseSyncService, SupabaseRealtimeService, BackendSwitch+SyncRouter, DataMigrationToSupabase, OfflineSyncQueue, AccountDeletionService
- **Supabase Models**: `Models/Supabase/` — SupabaseDTO, SupabaseModelConverters
- **Supabase SQL**: `supabase/migrations/` — 001_initial_schema.sql, 002_improvements.sql
- **Edge Functions**: `supabase/functions/send-push/` — APNs push-уведомления
- **CloudKit (legacy)**: `CloudKitService.swift`, `CloudKitSyncService.swift`, `CloudKitModels.swift`
- **Логирование**: `debugLog()` из `DebugLogger.swift` — все логи только в DEBUG
- **UI-компоненты**: `CasinoBackgroundModifier`, `CurrencyFormatting`, `PokerUIHelpers`, `PokerCardViews`
- **Тесты**: Swift Testing (unit) + XCTest (UI), моки в `FishAndChipsTests/Mocks/`
- **CI/CD**: `.github/workflows/ci.yml`

---

## Ссылки

- Supabase: `SupabaseService.swift`, `SupabaseSyncService.swift`, `SupabaseAuthService.swift`
- CloudKit (legacy): `CloudKitService.swift`, `CloudKitSyncService.swift`
- [DATA_DIAGRAM.md](DATA_DIAGRAM.md) | [Supabase Dashboard](https://supabase.com/dashboard)

---

## Чеклист для агента

- [ ] Прочитал MASTER_PLAN.md
- [ ] Не создаю MD без разрешения
- [ ] Обновляю DATA_DIAGRAM при изменении данных
- [ ] Small diffs + проверка в Supabase Dashboard
- [ ] Проверяю BackendSwitch при изменении sync-логики
