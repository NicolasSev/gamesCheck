# FishChips Web — План реализации пользовательской веб-версии

> **Создано:** 2026-03-26 | На основе iOS Screen Map (Figma) + текущего web-admin  
> **Figma:**  
> - [Interactive Prototype (20 screens, clickable)](https://www.figma.com/design/LpguHhVtpfW8xo7Qz0TCc3) — основной прототип с casino-темой и prototype links  
> - [Screen Map + API Annotations](https://www.figma.com/design/LOP4UJR4tMlmFWMhWA4dwM) — карточки экранов с API/Data аннотациями  
> - [Navigation Flow (FigJam)](https://www.figma.com/online-whiteboard/create-diagram/622ce98e-e547-4682-9304-8b3f106b3a67) — диаграмма навигации  
> **Цель:** реализовать user-facing web-версию с тем же функционалом, что iOS-приложение

---

## Текущее состояние

### iOS App — 20 ключевых экранов (в Figma Prototype)

| Row | Экраны | Figma Prototype |
|-----|--------|----------------|
| Auth | SplashScreen, LoginView, RegistrationView, BiometricPromptView | ✅ 4 frames, clickable |
| Tabs | OverviewTabView, GamesListTabView, StatisticsTabView, PlayersTabView | ✅ 4 frames, tab switching |
| Detail | GameDetailView, BilliardGameDetailView, ProfileView, AddGameSheet | ✅ 4 frames |
| Claims | NotificationsView, PendingClaimsView, MyClaimsView, PlayerPublicProfileView | ✅ 4 frames |
| Extra | HandAddView, DebugView, ImportDataSheet, JoinGameByCodeSheet | ✅ 4 frames |

Каждый экран имеет:
- Wireframe UI (casino dark theme, Inter font)
- API & Data аннотацию рядом (синий блок)
- Prototype links на целевые экраны (кликабельные переходы)

### Web Admin (существующий) — 10 страниц
- /login — только super_admin
- /(admin)/page — Dashboard (RPC admin_dashboard_stats)
- /(admin)/games — список игр (read-only)
- /(admin)/games/[id] — деталь игры (read-only + soft delete)
- /(admin)/users — список пользователей
- /(admin)/users/[id] — деталь + редактирование флагов
- /(admin)/claims — модерация заявок
- /(admin)/analytics — глобальная аналитика
- /(admin)/push — массовые уведомления
- /(admin)/games/import — импорт текстом

### Что ОТСУТСТВУЕТ для user-facing web
- Регистрация и логин обычных пользователей
- Личный дашборд (баланс, статистика, последние игры)
- Создание и управление играми (CRUD)
- Управление игроками в игре (добавление, buyins, cashouts)
- Бильярдные игры (создание, партии)
- Личный профиль и настройки
- Система заявок (подача, просмотр, одобрение)
- Уведомления в реальном времени (Realtime)
- История покерных раздач

---

## Архитектура Web-версии

**Реализовано (2026-03-27):** пользовательский флоу под префиксом **`/app`** (группа `src/app/app/`). Логин приложения: `/login`, регистрация: `/register`, админ: `/admin/login`.

```
fishchips-web/
├── src/app/
│   ├── login/page.tsx          # Логин приложения (не только admin)
│   ├── register/page.tsx     # Регистрация
│   ├── admin/login/page.tsx   # Только super_admin → /
│   ├── app/                    # User app (URL /app/...)
│   │   ├── page.tsx            # Dashboard / Overview
│   │   ├── games/
│   │   │   ├── page.tsx        # Список игр (мои + публичные)
│   │   │   ├── new/page.tsx    # Создание игры
│   │   │   └── [id]/
│   │   │       ├── page.tsx    # Деталь игры
│   │   │       └── hands/page.tsx  # Покерные раздачи
│   │   ├── stats/page.tsx      # Личная статистика
│   │   ├── players/
│   │   │   ├── page.tsx        # Список игроков
│   │   │   └── [id]/page.tsx   # Публичный профиль
│   │   ├── profile/page.tsx    # Мой профиль + настройки
│   │   ├── claims/
│   │   │   ├── page.tsx        # Мои заявки
│   │   │   └── pending/page.tsx # Входящие заявки (как хост)
│   │   ├── notifications/page.tsx
│   │   ├── import/page.tsx
│   │   └── join/page.tsx
│   └── (admin)/                # Админка: /, /users, /games, …
│       └── ...
├── src/lib/
│   ├── supabase/client.ts      # Существующий
│   ├── supabase/server.ts      # Существующий
│   └── hooks/
│       ├── useAuth.ts          # Хук авторизации
│       ├── useRealtime.ts      # Supabase Realtime подписки
│       └── useGames.ts         # Хук для операций с играми
└── src/components/
    ├── user/                   # Компоненты пользователя
    └── shared/                 # Общие компоненты
```

### Ключевые решения
- **Маршруты:** публичные `/login`, `/register`; приложение `/app/*`; админка `(admin)` на корне `/`, …; вход админа `/admin/login`
- **anon key + RLS** для user-facing (не service_role)
- **Supabase Realtime** для live-обновлений (подписка на games, claims)
- **Без offline-sync** — web не нуждается в CloudKit/Core Data

---

## Фазы реализации

### Phase 0: Инфраструктура (1-2 дня)

| Задача | Файлы | Supabase |
|--------|-------|----------|
| Middleware для user auth | `src/middleware.ts` | `supabase.auth.getUser()` |
| Layout для `(user)` группы | `src/app/(user)/layout.tsx` | Session check |
| Хук `useAuth` | `src/lib/hooks/useAuth.ts` | `onAuthStateChange` |
| Навигация (sidebar/header) | `src/components/user/nav.tsx` | — |
| RLS проверка для anon key | — | Все таблицы |

**Тестовый критерий:** пользователь логинится, видит пустой дашборд, навигация работает.

---

### Phase 1: Auth + Profile (2-3 дня) — P0

| iOS Screen | Web Page | Supabase API | Приоритет |
|------------|----------|--------------|-----------|
| **LoginView** | `/login` (доработка) | `auth.signInWithPassword()` | P0 |
| **RegistrationView** | `/register` | `auth.signUp()` → trigger `handle_new_user()` создаёт profile | P0 |
| **ProfileView** | `/profile` | `profiles.select().eq(id, me)`, `profiles.update()` | P0 |

**Задачи для агента:**
1. Доработать `/login` — убрать проверку `is_super_admin`, добавить redirect в `(user)` или `(admin)` по флагу
2. Создать `/register` — форма: username, email, password; после успеха — redirect на dashboard
3. Создать `/profile` — отображение профиля, редактирование display_name, avatar_url, is_public; кнопка logout с подтверждением
4. Middleware: разделить маршруты `(admin)` (super_admin) и `(user)` (любой auth)

**API endpoints:**
```typescript
// Login
supabase.auth.signInWithPassword({ email, password })

// Register  
supabase.auth.signUp({ email, password, options: { data: { username } } })

// Get profile
supabase.from('profiles').select('*').eq('id', userId).single()

// Update profile
supabase.from('profiles').update({ display_name, avatar_url, is_public }).eq('id', userId)

// Logout
supabase.auth.signOut()
```

---

### Phase 2: Dashboard + Games List (3-4 дня) — P0

| iOS Screen | Web Page | Supabase API | Приоритет |
|------------|----------|--------------|-----------|
| **OverviewTabView** | `/(user)/page.tsx` | `profiles`, `games`, `user_statistics` view | P0 |
| **GamesListTabView** | `/(user)/games/page.tsx` | `games.select().order(date)`, `game_players` | P0 |

**Задачи для агента:**
1. Dashboard: баланс-карточка (из `user_statistics`), последние 10 игр, мини-статистика
2. Games list: список с фильтрами (тип, дата), поиск, календарь-виджет
3. Пагинация (cursor-based или offset)
4. Supabase Realtime подписка на новые игры

**API endpoints:**
```typescript
// Dashboard stats
supabase.from('user_statistics').select('*').eq('user_id', me).single()

// Recent games (creator or participant)  
supabase.from('games')
  .select('*, game_players!inner(player_profile_id)')
  .or(`creator_id.eq.${me},game_players.player_profile_id.eq.${me}`)
  .order('date', { ascending: false })
  .limit(20)

// Games list with filters
supabase.from('games')
  .select('*, game_players(count)')
  .order('date', { ascending: false })
  .range(offset, offset + limit)
```

---

### Phase 3: Game Detail + Player Management (4-5 дней) — P0

| iOS Screen | Web Page | Supabase API | Приоритет |
|------------|----------|--------------|-----------|
| **GameDetailView** | `/(user)/games/[id]` | `games`, `game_players`, `player_claims` | P0 |
| **AddGameSheet** | `/(user)/games/new` | `games.insert()`, `game_players.insert()` | P0 |
| **AddPlayerToGameSheet** | модалка в game detail | `game_players.insert()`, `profiles.select()` | P0 |

**Задачи для агента:**
1. Game detail: шапка игры, таблица игроков с buyins/cashouts, итоги, баланс-чек
2. Inline-редактирование buyins/cashouts (для хоста)
3. Создание игры: тип (Poker/Billiard), название, дата, публичность
4. Добавление игрока: поиск по профилям + добавление по имени (без профиля)
5. Удаление игрока (для хоста)
6. Share ссылка на игру (invite code)
7. Realtime: подписка на изменения game_players

**API endpoints:**
```typescript
// Game detail
supabase.from('games').select('*').eq('id', gameId).single()
supabase.from('game_players')
  .select('*, profiles(username, display_name, avatar_url)')
  .eq('game_id', gameId)

// Create game
supabase.from('games').insert({ game_type, name, date, is_public, creator_id })

// Add player
supabase.from('game_players').insert({ game_id, player_profile_id, player_name, buyin })

// Update buyin/cashout
supabase.from('game_players').update({ buyin, cashout }).eq('id', gpId)

// Delete player
supabase.from('game_players').delete().eq('id', gpId)

// Check balance
supabase.rpc('check_game_balance', { p_game_id: gameId })
```

---

### Phase 4: Players + Public Profiles (2-3 дня) — P0

| iOS Screen | Web Page | Supabase API | Приоритет |
|------------|----------|--------------|-----------|
| **PlayersTabView** | `/(user)/players` | `profiles` (is_public) | P0 |
| **PlayerPublicProfileView** | `/(user)/players/[id]` | `profiles`, `games`, `game_players` | P1 |

**Задачи для агента:**
1. Grid/list публичных игроков с аватарами
2. Поиск по имени
3. Публичный профиль: статистика игрока, последние игры, баланс
4. Ссылка «Посмотреть все игры с этим игроком»

**API endpoints:**
```typescript
// Public players
supabase.from('profiles').select('*').eq('is_public', true).order('username')

// Player profile + stats
supabase.from('profiles').select('*').eq('id', playerId).single()
supabase.from('game_players')
  .select('*, games(*)')
  .eq('player_profile_id', playerId)
  .order('created_at', { ascending: false })
```

---

### Phase 5: Statistics + Charts (2-3 дня) — P1

| iOS Screen | Web Page | Supabase API | Приоритет |
|------------|----------|--------------|-----------|
| **StatisticsTabView** | `/(user)/stats` | `user_statistics`, `game_summaries` | P1 |

**Задачи для агента:**
1. Grafik buyins over time (Recharts, уже есть в проекте)
2. Top records: лучшая/худшая игра, серии побед/поражений
3. Средний profit, win rate
4. Фильтры по периоду и типу игры
5. Pie-chart по типам игр

**API endpoints:**
```typescript
// Personal stats
supabase.from('user_statistics').select('*').eq('user_id', me).single()

// Games for chart data
supabase.from('game_players')
  .select('buyin, cashout, games(date, game_type)')
  .eq('player_profile_id', me)
  .order('created_at', { ascending: false })
```

---

### Phase 6: Claims System (2-3 дня) — P2

| iOS Screen | Web Page | Supabase API | Приоритет |
|------------|----------|--------------|-----------|
| **ClaimPlayerView** | модалка в game detail | `player_claims.insert()` | P2 |
| **MyClaimsView** | `/(user)/claims` | `player_claims.select(claimant_id=me)` | P2 |
| **PendingClaimsView** | `/(user)/claims/pending` | `player_claims.select(host_id=me)` | P2 |
| **JoinGameByCodeSheet** | модалка в claims | `games.select(invite_code)` | P2 |

**Задачи для агента:**
1. Подать заявку на привязку анонимного игрока к профилю
2. Список моих заявок со статусами (pending/approved/rejected)
3. Входящие заявки (как хост) — одобрить/отклонить
4. Присоединение к игре по коду

**API endpoints:**
```typescript
// Submit claim
supabase.from('player_claims').insert({ game_player_id, claimant_id, host_id, game_id })

// My claims
supabase.from('player_claims').select('*, games(name)').eq('claimant_id', me)

// Pending claims (as host)
supabase.from('player_claims').select('*, profiles(username)').eq('host_id', me).eq('status', 'pending')

// Approve/Reject
supabase.from('player_claims').update({ status, resolved_at }).eq('id', claimId)

// Join by code
supabase.from('games').select('id, name').eq('invite_code', code).single()
```

---

### Phase 7: Billiard Games (2 дня) — P1

| iOS Screen | Web Page | Supabase API | Приоритет |
|------------|----------|--------------|-----------|
| **BilliardGameDetailView** | `/(user)/games/[id]` (type=billiard) | `billiard_batches` | P1 |

**Задачи для агента:**
1. Деталь бильярдной игры: таблица партий, счёт
2. Добавление/редактирование партий (для хоста)
3. Выбор/смена игроков

**API endpoints:**
```typescript
// Billiard batches
supabase.from('billiard_batches')
  .select('*')
  .eq('game_id', gameId)
  .order('batch_number')

// Add batch
supabase.from('billiard_batches').insert({ game_id, batch_number, player1_score, player2_score, winner_id })
```

---

### Phase 8: Notifications + Realtime (2 дня) — P2

| iOS Screen | Web Page | Supabase API | Приоритет |
|------------|----------|--------------|-----------|
| **NotificationsView** | `/(user)/notifications` | Supabase Realtime | P2 |

**Задачи для агента:**
1. Realtime подписки: новые игры, изменения claims, обновления профиля
2. Toast-уведомления в UI
3. Список уведомлений (хранение в localStorage или новая таблица)
4. Счётчик непрочитанных в навигации

**API:**
```typescript
// Realtime subscription
supabase.channel('user-updates')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'player_claims', filter: `host_id=eq.${me}` }, handler)
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'games' }, handler)
  .subscribe()
```

---

### Phase 9: Poker Hands (3 дня) — P3 (Future)

| iOS Screen | Web Page | Supabase API | Приоритет |
|------------|----------|--------------|-----------|
| **HandAddView** | `/(user)/games/[id]/hands` | Новая таблица `hands` (или localStorage) | P3 |
| **HandDetailView** | — | — | P3 |

**Задачи для агента:**
1. Если нужна синхронизация — создать миграцию `005_hands.sql` для таблицы `hands`
2. UI: запись раздачи, визуализация карт
3. Альтернатива: хранение в localStorage (как в iOS — HandsStorageService)

**Примечание:** В iOS раздачи хранятся локально (HandsStorageService), не в Supabase. Для web нужно решить: localStorage или серверная таблица.

---

## Приоритеты (сводка)

| Приоритет | Фазы | Ориентир |
|-----------|-------|----------|
| **P0 — Must Have** | Phase 0-4 | ~2 недели |
| **P1 — Should Have** | Phase 5, 7 | ~1 неделя |
| **P2 — Nice to Have** | Phase 6, 8 | ~1 неделя |
| **P3 — Future** | Phase 9 | TBD |

**Итого MVP (P0):** ~2 недели → Auth, Dashboard, Games CRUD, Players, Profile

---

## Зависимости от Supabase

Текущая схема (миграции 001-004) **достаточна** для Phase 0-8. Дополнительные миграции:

| Фаза | Нужна миграция? | Что |
|------|-----------------|-----|
| 0-7 | Нет | Всё уже есть |
| 8 | Возможно | Таблица `notifications` (или Realtime-only) |
| 9 | Да | Таблица `hands` (если серверное хранение) |

---

## Для агентов: как использовать этот план

1. **Читай этот файл** перед началом каждой фазы
2. **Одна фаза = один PR** — не смешивать
3. **Каждая страница** должна использовать Supabase endpoints из этого плана
4. **RLS** — user-facing страницы используют `anon key`, не `service_role`
5. **Тестируй** каждую страницу: создай тестового пользователя, проверь CRUD
6. **Обновляй** этот файл после завершения фазы (статус, дата)
7. **Стек:** Next.js 16, Tailwind CSS, shadcn/ui, Recharts (уже в проекте)
8. **Figma:** ссылки выше — используй как визуальный референс

---

## Детальная карта экранов iOS → веб

Источник правды по iOS: Swift views + [`MainViewModel`](../../FishAndChips/ViewModels/MainViewModel.swift) + [`GameService`](../../FishAndChips/Services/) / Core Data. На веб: Supabase anon + RLS, материализованные представления и таблицы из [DATA_DIAGRAM.md](DATA_DIAGRAM.md).

### Auth и оболочка

| Экран | Swift | Компоненты / данные | iOS источник | Supabase / веб | Веб маршрут |
|-------|--------|---------------------|--------------|----------------|-------------|
| Контент по состоянию | `ContentView` | Login / Biometric / Main / spinner / error | `AuthViewModel.authState` | `auth.getSession`, профиль | `/login`, `/register` |
| Логин | `LoginView` | email, password, ошибки | `AuthViewModel.login` | `auth.signInWithPassword` | `/login` |
| Регистрация | `RegistrationView` | email, password, username | signUp + `handle_new_user` | `auth.signUp` | `/register` |
| Биометрия | `BiometricPromptView` | Face ID / отказ | Keychain + LocalAuthentication | нет аналога | — (опционально WebAuthn) |
| Splash | `SplashScreenView` | бренд | таймер | `loading.tsx` | — |

### Главный таб-бар (`MainView`)

| Вкладка | Swift | Компоненты / данные | iOS источник | Supabase / веб | Веб |
|---------|--------|---------------------|--------------|----------------|-----|
| Обзор | `OverviewTabView` | `BalanceCardView`, сетка `StatCardView` (сессии, MVP, win rate, MVP rate), аккордеоны год/месяц [`OverviewAccordionViews`](../../FishAndChips/Views/OverviewAccordionViews.swift), выбор игрока | `MainViewModel`: `UserStatistics`, `games`, `chartData`; `GameService` из Core Data | `user_statistics` MV; список игр `games` + участие `game_players`; MVP нет в MV — только локальная аналитика iOS | `/app` |
| Игры | `GamesListTabView` | фильтр `GameFilter`, поиск, календарь/диапазон, группировка по дням | `filteredGames`, `applyFilter`, `loadMoreGames` | `games` (RLS) + клиентская фильтрация | `/app/games` |
| Статистика | `StatisticsTabView` | `BuyinsChartView`, топ-рекорды, `GameTypeStatistics`, стрики | `chartData`, `topAnalytics`, `gameTypeStats` | `game_players` + `games`; агрегаты на клиенте или RPC | `/app/stats` |
| Игроки | `PlayersTabView` | список профилей, поиск; супер-админ видит все | `@FetchRequest PlayerProfile` | `profiles` where `is_public` (и админ — `/users`) | `/app/players` |

### Шиты и детали

| Экран | Swift | Данные | iOS | Supabase / веб | Веб |
|-------|--------|--------|-----|----------------|-----|
| Профиль | `ProfileView` | аватар буква, username, email, sync, заявки, выход | `AuthViewModel`, `PlayerClaimService`, `SyncCoordinator` | `profiles` update, claims count | `/app/profile` + меню |
| Новая игра | `AddGameSheet` | тип, дата, заметки | Core Data insert + sync | `games.insert` | `/app/games/new` |
| Деталь покера | `GameDetailView` | игроки buy-in/cashout, баланс, руки [`HandsStorageService`](../../FishAndChips/Services/), claim, шаринг | локальные руки | `games`, `game_players`, `check_game_balance`; руки — локально или будущая таблица | `/app/games/[id]`, `/app/games/[id]/hands` |
| Бильярд | `BilliardGameDetailView` | партии | Core Data | `billiard_batches` | ветка в `/app/games/[id]` |
| Мои заявки | `MyClaimsView` | список claims | `PlayerClaimService` | `player_claims` claimant | `/app/claims` |
| Входящие | `PendingClaimsView` | approve/reject | host | `player_claims` host | `/app/claims/pending` |
| Уведомления | `NotificationsView` | список | сервис + Core Data | Realtime | `/app/notifications` |
| Join | `JoinGameByCodeSheet` | UUID игры | поиск Game | `games.select` по id | `/app/join` |
| Импорт | `ImportDataSheet` + конфликты | текст, даты, replace/skip | парсер + Core Data | `parseImportText`, insert/update `games` | `/app/import` |
| Публичный профиль | `PlayerPublicProfileView` | статы игрока | GameService | `profiles` + `game_players` | `/app/players/[id]` |

### Gap-анализ (приоритеты)

| ID | Тема | iOS | Веб (цель) | Приоритет |
|----|------|-----|------------|-----------|
| G1 | Обзор: карточки win rate, avg profit, buy-in/cashout суммарно | полный `UserStatistics` | расширить из `user_statistics` | P0 |
| G2 | Обзор: аккордеоны год/месяц, MVP | локальная аналитика | частично: группировка по `games.timestamp` без MVP до новой RPC | P1 |
| G3 | Список игр: фильтр типа, поиск, календарь | полный UX | клиентский фильтр + календарь месяца | P0 |
| G4 | Статистика: топ-рекорды, типы игр, график бай-инов | `TopAnalytics`, `GameTypeStatistics` | агрегаты из `game_players`+`games` | P0 |
| G5 | Деталь игры: гистограмма игроков | `playerResults` | расчёт из `game_players` | P0 |
| G6 | Руки покера | локальный `HandsStorageService` | localStorage / будущая миграция | P2 |
| G7 | Игроки: все профили для супер-админа | Fetch всех | только веб-админ `/users` | P2 (продукт) |

**Статус паритета (2026-03-27):** закрыты G1, G3, G4, G5 в коде `fishchips-web` (см. выше). Открыты: G2 (аккордеоны/MVP без отдельной RPC), G6 (руки), G7 (продукт).

---

## Статус

| Фаза | Статус | Дата |
|-------|--------|------|
| Phase 0: Инфраструктура | Done | 2026-03-27 |
| Phase 1: Auth + Profile | Done | 2026-03-27 |
| Phase 2: Dashboard + Games List | Done | 2026-03-27 |
| Phase 3: Game Detail + Players | Done | 2026-03-27 |
| Phase 4: Players + Public Profiles | Done | 2026-03-27 |
| Phase 5: Statistics + Charts | Done | 2026-03-27 |
| Phase 6: Claims System | Done | 2026-03-27 |
| Phase 7: Billiard Games | Done | 2026-03-27 |
| Phase 8: Notifications + Realtime | Done | 2026-03-27 |
| Phase 9: Poker Hands | Partial (local notes only) | 2026-03-27 |
