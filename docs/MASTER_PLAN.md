# Мастер-план проекта gamesCheck

> **Единый источник правды для всех агентов, работающих над проектом**

**Последнее обновление:** 2026-02-22 12:00

**📊 Документация:**
- [Диаграмма данных и схема базы данных](DATA_DIAGRAM.md) - полная схема Core Data, CloudKit, flow синхронизации

**История обновлений:**
- 2026-02-22 (12:00): 📋 ФАЗА 3 НАЧАТА — Витрины, Пуши, Игроки, Скорость: обновлён MASTER_PLAN, добавлены правила для агентов (читать план, обновлять DATA_DIAGRAM при изменении данных)
- 2026-02-11 (14:00): ✅ ФАЗА 2 ЗАВЕРШЕНА — Оптимизация производительности: Materialized Views, двухфазная загрузка (minimal + background), lazy loading GWP, пагинация игр, кеш статистики, Background Fetch, миграция данных
- 2026-02-06 (23:50): 🐛 Импорт игр: исправлен пустой список имён при выборе хоста — uniquePlayerNames заполняется при валидации (в т.ч. при конфликтах), fallback-сообщение в PlayerSelectionSheet
- 2026-02-06 (вечер): ✅ Профиль игрока: полный сброс при «Сменить игрока», объединённая статистика по нескольким выбранным именам (выборка увеличивается)
- 2026-02-07 (00:15): 🚀 КРИТИЧЕСКОЕ: Реализована полная пагинация CloudKit для GameWithPlayer (CKQueryOperation.Cursor)
- 2026-02-07 (23:00): 🛡️ КРИТИЧЕСКИЙ FIX: PlayerProfile мигрирован в Public DB, защита от CloudKit limit
- 2026-02-07 (22:50): 🎨 UI: Улучшена анимация splash screen - эффект "удар сердца"
- 2026-02-07 (19:15): 📊 Создана детальная диаграмма данных - схема БД, CloudKit, flow синхронизации, защита данных
- 2026-02-07 (19:10): 🛡️ КРИТИЧЕСКИЙ FIX: Защита от затирания playerProfile + синхронизация PlayerProfile
- 2026-02-07 (01:30): 🔄 КРИТИЧЕСКОЕ ИЗМЕНЕНИЕ: CloudKit = единственный источник правды (Source of Truth)
- 2026-02-07 (01:00): 🐛 Исправлена синхронизация после одобрения заявки - данные теперь отправляются в CloudKit
- 2026-02-07 (00:40): 🚨 КРИТИЧНО: Перенесен PlayerClaim из Private DB в Public DB для корректной работы заявок
- 2026-02-07 (00:30): 🐛 Исправлена синхронизация PlayerClaim - добавлена загрузка из CloudKit
- 2026-02-07 (00:20): 🐛 Исправлена ошибка Limit Exceeded - изменен limit с 1000 на 400
- 2026-02-06 (23:45): 🔄 Миграция User: Private DB → Public DB для корректной проверки уникальности email
- 2026-02-06 (23:00): 🐛 Hotfix регистрации - User синхронизируется в CloudKit, успешное уведомление, email в профиле
- 2026-02-06 (14:30): ✅ Улучшен выбор игрока - мульти-селект для разных вариантов имени
- 2026-02-06: ✅ Критические баги TestFlight исправлены - выбор игрока, публичность игр, регистрация
- 2026-02-03: 🐛 Добавлен план дебага GameWithPlayer - игроки не синхронизируются в CloudKit
- 2026-02-02 (COMMIT f4fd35e): ✅ Pre-TestFlight улучшения завершены - ребрендинг, email auth, biometric fix, logging
- 2026-02-02: Pre-TestFlight улучшения - ребрендинг на Fish & Chips, вход по email, номер сборки в профиле
- 2026-01-31 11:30: Добавлен детальный план исправления критического бага синхронизации CloudKit
- 2026-01-31 11:30: Добавлен раздел "Будущие оптимизации" - On-Demand Game Loading
- 2026-01-30: Добавлен детальный план Этапа 2 - Тестирование в TestFlight
- 2026-01-30: Добавлено КРИТИЧЕСКОЕ правило - создание MD файлов только с явного разрешения пользователя
- 2026-01-29: Очистка устаревшей документации выполнена

---

## 🔄 КРИТИЧЕСКОЕ ИЗМЕНЕНИЕ: CloudKit = Source of Truth (2026-02-07, 01:30)

**Статус:** ✅ РЕАЛИЗОВАНО

### Новая философия синхронизации:

**БЫЛО:**
- Локальные данные (Core Data) + CloudKit
- При merge: конфликты, проверка дат модификации
- Локальные данные могли "выигрывать" у CloudKit
- Удаление в CloudKit НЕ приводило к удалению локально

**СТАЛО:**
- **CloudKit = единственный источник правды (Source of Truth)**
- **Core Data = локальный кэш** для офлайн работы
- При pull: локальная БД **полностью приводится к CloudKit**
- CloudKit **ВСЕГДА побеждает** в любых конфликтах

### Изменения в коде:

#### 1. `mergeGamesWithLocal()`:
```swift
// Собираем все gameId из CloudKit
var cloudGameIds = Set<UUID>()

// Создаем/обновляем из CloudKit
for record in cloudRecords {
    // Всегда обновляем (CloudKit = истина)
    localGame.updateFromCKRecord(record)
}

// УДАЛЯЕМ локальные игры, которых НЕТ в CloudKit
for localGame in allLocalGames {
    if !cloudGameIds.contains(localGame.gameId) {
        context.delete(localGame) // 🗑️
    }
}
```

#### 2. `mergeGameWithPlayersWithLocal()`:
- Аналогичная логика: CloudKit → Local
- Удаление локальных GWP, которых нет в CloudKit
- Всегда обновляет `playerProfile` связь

#### 3. `pullChanges()`:
- Для **каждой сущности** (User, PlayerProfile, Game, GWP, Alias, Claim):
  * Создает если нет локально
  * Обновляет если есть локально
  * **УДАЛЯЕТ если есть локально, но НЕТ в CloudKit**
- Особый случай: CloudKit вернул 0 GWP → удаляет **ВСЕ** локальные GWP

### Результат:

✅ **Удалил игры в DEV CloudKit** → при синхронизации удалятся локально  
✅ **Пустой CloudKit** → пустой Core Data после pull  
✅ **Импортировал игру** → push в CloudKit → она станет истиной  
✅ **Одобрил заявку** → push в CloudKit → изменения синхронизируются на все устройства  

### Флоу для пользователя:

1. **Создание данных** (импорт игры, регистрация):
   - Создается локально ✅
   - **Сразу пушится в CloudKit** ✅
   - CloudKit становится Source of Truth ✅

2. **Синхронизация**:
   - Fetch из CloudKit ✅
   - Core Data **полностью приводится** к CloudKit ✅
   - Удаленные в CloudKit → удаляются локально ✅

3. **Офлайн работа**:
   - Core Data работает как кэш ✅
   - При следующей синхронизации: push → CloudKit → pull → локальное перезаписывается ✅

---

## 🐛 Исправление: PlayerClaim синхронизация (2026-02-07, 00:30)

**Статус:** ✅ ИСПРАВЛЕНО

### Проблема:
PlayerClaim сохранялся в CloudKit Private DB, но **НЕ загружался** при синхронизации. Хост создавал игры на устройстве 1, другой пользователь подавал заявку с устройства 2, но на устройстве 1 заявки не появлялись даже после синхронизации.

### Диагностика:
- `syncPlayerClaims()` - сохраняет (push) claims в Private DB ✓
- `pullChanges()` - загружает User и PlayerProfile, но НЕ загружает PlayerClaim ❌
- `performFullSync()` - НЕ вызывает загрузку PlayerClaim ❌

### Решение:

**Добавлены методы в `CloudKitSyncService.swift`:**

1. **`fetchPlayerClaims()`** - загружает PlayerClaim из Private DB
2. **`mergePlayerClaimsWithLocal()`** - мержит загруженные claims с локальной БД
3. **Обновлен `pullChanges()`** - добавлена загрузка claims
4. **Обновлен `performFullSync()`** - добавлен вызов `fetchPlayerClaims()`

### Результат:
- ✅ PlayerClaim синхронизируется в обе стороны (push + pull)
- ✅ Хост видит заявки от других пользователей после синхронизации
- ✅ Детальное логирование с префиксами `[FETCH_CLAIMS]` и `[MERGE_CLAIMS]`

---

## 🔄 Миграция: User в Public Database (2026-02-06, 23:45)

**Статус:** ✅ ЗАВЕРШЕНО

### Проблема:
User хранился в Private Database, что создавало проблемы:
1. **Невозможность проверки уникальности email** - Private DB доступна только владельцу iCloud аккаунта
2. **Race condition** - два пользователя могут зарегистрироваться с одним email одновременно
3. **Ложные ошибки регистрации** - проверка CloudKit всегда возвращала ошибку для неавторизованных пользователей

### Решение - Миграция User в Public Database:

**Измененные файлы:**

1. **CloudKitModels.swift** - `User.toCKRecord()` и `updateFromCKRecord()`
   - ❌ **Убран passwordHash** из CloudKit синхронизации (sensitive data)
   - ✅ passwordHash хранится ТОЛЬКО локально в Core Data
   - Синхронизируются: userId, username, email, subscriptionStatus, isSuperAdmin, createdAt

2. **CloudKitSyncService.swift** - все User методы
   - `fetchUser(byUsername:)` - `.privateDB` → `.publicDB`
   - `fetchUser(byEmail:)` - `.privateDB` → `.publicDB`
   - `quickSyncUser()` - `.privateDB` → `.publicDB`
   - `deleteUser()` - `.privateDB` → `.publicDB`

3. **AuthViewModel.swift** - `register()`
   - ✅ **Возвращена проверка CloudKit** - теперь работает корректно
   - Проверка email в Public DB ДО создания локального пользователя
   - Если CloudKit недоступен - блокируется регистрация (критично!)

### Архитектура после миграции:

**User:**
- **CloudKit Public DB:** userId, username, email (публичные данные для проверки уникальности)
- **Core Data Local:** userId, username, email, passwordHash (локальная копия + аутентификация)

**PlayerProfile:**
- **CloudKit Private DB:** profileId, userId, displayName, stats (приватные данные игрока)

### Результат:
- ✅ Проверка уникальности email работает ДО создания аккаунта
- ✅ Нет race condition - CloudKit гарантирует уникальность
- ✅ passwordHash не попадает в CloudKit (security)
- ✅ Регистрация работает корректно для всех пользователей

---

## 🐛 Hotfix: Ошибка регистрации в TestFlight (2026-02-06, 23:00)

**Статус:** ✅ ИСПРАВЛЕНО

### Проблема:
При регистрации в TestFlight показывалась "Произошла неизвестная ошибка", хотя пользователь создавался локально и вход проходил успешно. Пользователя не было в CloudKit Production Database.

### Диагностика:
- User создавался локально (Core Data + Keychain) ✓
- PlayerProfile создавался ✓
- Но User НЕ синхронизировался в CloudKit
- Проверка CloudKit могла выбрасывать ошибки timeout/network

### Решение:
1. **User синхронизируется в CloudKit Private Database** в [`AuthViewModel.swift`](FishAndChips/ViewModels/AuthViewModel.swift)
   - При регистрации User сохраняется в CloudKit Private DB через `quickSyncUser()`
   - **ВАЖНО:** Проверка CloudKit убрана - Private DB недоступна для неавторизованных пользователей
   - Проверка уникальности username и email только локально (Core Data)
   - Graceful degradation: если CloudKit недоступен при сохранении - не блокируем регистрацию

2. **Добавлено уведомление об успешной регистрации** в [`RegistrationView.swift`](FishAndChips/Views/RegistrationView.swift)
   - Alert "Успех" с сообщением "Вы успешно зарегистрировались!"
   - После нажатия OK view закрывается

3. **Улучшена обработка ошибок** в [`RegistrationView.swift`](FishAndChips/Views/RegistrationView.swift)
   - Вместо "Неизвестная ошибка" показывается `error.localizedDescription`
   - Полное логирование для отладки
   - MainActor для обновления UI состояния

4. **Email добавлен в профиль** в [`ProfileView.swift`](FishAndChips/Views/ProfileView.swift)
   - Отображается под username
   - Формат: Username (крупнее) → Email (средний) → UserId (мелкий)

### Результат:
- User синхронизируется в CloudKit Private Database при регистрации (для multi-device)
- Проверка уникальности email/username только локально (Core Data)
- После успешной регистрации - уведомление "Вы успешно зарегистрировались!"
- В профиле отображается email рядом с username
- Регистрация работает быстро без зависимости от CloudKit

### Почему убрана проверка CloudKit при регистрации:
**Private Database недоступна для неавторизованных пользователей:**
- Private DB каждого пользователя изолирована и доступна только владельцу iCloud аккаунта
- Неавторизованный пользователь НЕ МОЖЕТ запросить данные из чужой Private DB
- Попытка проверить email в CloudKit при регистрации всегда возвращает ошибку доступа
- Решение: проверка уникальности только локально, User синхронизируется после создания

---

## 🎯 Исправления критических багов TestFlight (2026-02-06)

**Статус:** ✅ ЗАВЕРШЕНО

### Что было исправлено:

#### 1. ✅ Убран хардкод "Ник" - мульти-селект выбора игрока
**Проблема:** В `DataImportService.swift` было захардкожено имя "Ник", из-за чего только пользователь с этим именем мог корректно импортировать игры.

**Решение:**
- Удалён хардкод `currentUserName = "Ник"`
- Добавлен метод `extractUniquePlayerNames()` для извлечения всех игроков из импортируемых данных
- Создан компонент `PlayerSelectionSheet.swift` с UI для мульти-селекта игроков
- Модифицирован `ImportDataSheet.swift` - после валидации показывается селект выбора игроков
- Обновлён метод `importGames()` - принимает параметр `selectedPlayerNames: Set<String>`
- Убрана проверка `username == "Ник"` для супер-админа в `AuthViewModel.swift`

**Результат:** 
- Любой пользователь может импортировать игры
- **Мульти-селект:** можно выбрать несколько вариантов своего имени (например: "Я", "я", "Ник", "ник")
- Все выбранные имена будут связаны с профилем текущего пользователя
- Решена проблема когда один игрок записывается под разными вариантами имени

#### 2. ✅ Проверена синхронизация GameWithPlayer
**Статус:** Синхронизация уже реализована корректно!

**Проверено:**
- ✅ `syncGameWithPlayers()` синхронизирует в Public Database
- ✅ `fetchPublicGameWithPlayers()` загружает из Public Database
- ✅ `fetchGameWithPlayers(forGameId:)` загружает для конкретной игры
- ✅ `mergeGameWithPlayersWithLocal()` правильно объединяет с локальными данными
- ✅ `GameWithPlayer.toCKRecord()` и `updateFromCKRecord()` реализованы
- ✅ `performFullSync()` вызывает `fetchPublicGameWithPlayers()`
- ✅ `fetchGame(byId:)` автоматически загружает игроков при открытии по диплинку

**Результат:** Детали игры (игроки, buyins, cashouts) должны корректно синхронизироваться между устройствами.

#### 3. ✅ Реализована логика публичности игр
**Проблема:** Любая игра была доступна по ID, не было разграничения доступа.

**Решение:**
- Проверено: поле `isPublic` существует в Core Data и синхронизируется в CloudKit
- Проверено: Toggle "Публичная игра" уже реализован в `GameDetailView` (строки 426-439)
- Добавлена ошибка `CloudKitSyncError.gameNotPublic`
- Модифицирован `fetchGame(byId:)` - проверяет `isPublic` перед загрузкой
  - Если игра не публична и пользователь не создатель → ошибка
- Обновлён `DeepLinkService` - специальная обработка ошибки `gameNotPublic`
  - Показывает понятное сообщение: "Игра недоступна. Создатель ещё не сделал её публичной."

**Результат:** 
- По умолчанию игры приватные (только для создателя)
- Хост может сделать игру публичной через Toggle
- Попытка открыть приватную игру другим пользователем → информативная ошибка

#### 4. ✅ Система заявок (PlayerClaim)
**Статус:** Уже реализована!

**Проверено:**
- ✅ `PlayerClaimService.swift` - сервис для работы с заявками
- ✅ `ClaimPlayerView.swift` - форма подачи заявки
- ✅ `PendingClaimsView.swift` - просмотр заявок для хоста
- ✅ `MyClaimsView.swift` - мои заявки
- ✅ `ClaimStatusView.swift` - статус заявки в игре
- ✅ Кнопка "Подать заявку" в `GameDetailView` toolbar (строки 498-504)
- ✅ Логика `canClaim` для проверки возможности подать заявку

**Результат:** Полнофункциональная система заявок на участие в играх работает.

#### 5. ✅ Исправлена проблема регистрации
**Проблема:** При регистрации проверялась только локальная БД, CloudKit не проверялся. Старые записи могли восстанавливаться при логине, вызывая ошибку "Пользователь уже существует".

**Решение:**
- Добавлена проверка CloudKit в `AuthViewModel.register()` (строки 204-223)
  - После проверки локальной БД вызывается `fetchUser(byEmail:)`
  - Если пользователь найден в CloudKit → ошибка "Email уже существует в CloudKit"
  - Если CloudKit недоступен → продолжается регистрация (graceful degradation)
- Добавлен метод `deleteUser(userId:)` в `CloudKitSyncService` для очистки
  - Удаляет пользователя из Private Database
  - Используется для отладки и очистки данных

**Результат:** 
- Регистрация проверяет как локальную БД, так и CloudKit
- Избегаются конфликты при восстановлении данных
- Добавлен инструмент для очистки тестовых данных

### Измененные файлы:

| Файл | Изменения |
|------|-----------|
| `DataImportService.swift` | Удалён хардкод "Ник", добавлен `extractUniquePlayerNames()`, параметр `selectedPlayerNames: Set<String>` |
| `AuthViewModel.swift` | Убран хардкод супер-админа, добавлена проверка CloudKit при регистрации |
| `ImportDataSheet.swift` | Интегрирован мульти-селект выбора игроков после валидации |
| `PlayerSelectionSheet.swift` | **НОВЫЙ** - UI компонент для мульти-селекта игроков (checkbox вместо radio) |
| `CloudKitSyncService.swift` | Добавлена ошибка `gameNotPublic`, проверка публичности в `fetchGame()`, метод `deleteUser()` |
| `DeepLinkService.swift` | Обработка ошибки `gameNotPublic` с информативным сообщением |

### Что нужно протестировать в TestFlight:

**Сценарий 1: Импорт игр с мульти-селектом игрока**
1. Пользователь (не "Ник") открывает Import Data
2. Вставляет данные с игроками: "Алекс", "Борис", "Я", "я", "ник"
3. Нажимает "Валидировать"
4. Появляется мульти-селект с игроками (checkbox)
5. Выбирает несколько вариантов своего имени: "Я", "я", "ник"
6. Нажимает "Подтвердить" → импорт успешен
7. Все выбранные имена связаны с профилем пользователя

**Сценарий 2: Публичность игры**
1. Устройство А: создать игру (приватная по умолчанию)
2. Устройство А: включить Toggle "Публичная игра"
3. Устройство А: поделиться ссылкой
4. Устройство Б: открыть ссылку → игра загружается с деталями

**Сценарий 3: Приватная игра**
1. Устройство А: создать игру (оставить приватной)
2. Устройство А: поделиться ссылкой
3. Устройство Б: открыть ссылку → ошибка "Игра недоступна. Создатель ещё не сделал её публичной."

**Сценарий 4: Регистрация**
1. Очистить локальную БД
2. Зарегистрировать пользователя с email
3. Выход
4. Попытка повторной регистрации с тем же email → ошибка "Email уже существует"

---

## ✅ Профиль игрока (суперадмин) — сброс и мультиселект (2026-02-06)

**Статус:** ✅ ВЫПОЛНЕНО

### Изменения

1. **Полный сброс при «Сменить игрока»**
   - Обнуляются: `selectedPlayerName`, `selectedPlayerNamesForProfile`, `selectedPlayerNames`, `statistics`, `games`.
   - При возврате к списку галочки сняты, старые данные не показываются.
   - В начале `loadPlayerStats(for:)` сразу выставляются `games = []`, `statistics = nil`, чтобы при загрузке другого игрока не отображались старые данные.

2. **Объединённая статистика по нескольким именам**
   - Выбор нескольких имён в списке **увеличивает выборку**: подтягиваются все игры, где участвовал хотя бы один из выбранных игроков; в расчёт входят все участия выбранных игроков (в одной игре может быть несколько выбранных — учитываются оба).
   - Реализовано: `loadPlayerStats(for: [String])`, `calculatePlayerStatistics(playerNames:games:)`, в `OverviewTabView` — `selectedPlayerNamesForStats: [String]?` для блока «Игры по годам/месяцам».
   - Заголовок профиля при нескольких выбранных: «Несколько (N)».

3. **Исправление компиляции**
   - Устранена повторная декларация `worstSession`: используется присваивание в существующую `var` вместо `let`.

**Файлы:** `PlayerProfileView.swift`, `OverviewTabView.swift`.

---

## ✅ Импорт игр — список имён при выборе хоста (2026-02-06)

**Статус:** ✅ ИСПРАВЛЕНО

**Проблема:** При импорте игр экран «Выберите себя из списка» (выбор хоста) показывался с пустым списком имён — нельзя было выбрать, кем был хост в этих играх.

**Причина:** При наличии конфликтов по датам код выходил из валидации до заполнения `uniquePlayerNames`; список заполнялся только при отсутствии конфликтов.

**Решение:**
- В `ImportDataSheet`: при сохранении валидированных игр (`validatedGames = parsedGames`) сразу заполняется `uniquePlayerNames = service.extractUniquePlayerNames(from: parsedGames)` — и при конфликтах, и без. Список имён готов при первом показе sheet и после нажатия «Импортировать» в диалоге конфликтов.
- Уточнён текст ошибки, если игроки не найдены (подсказка по формату строк).
- В `PlayerSelectionSheet`: при пустом списке показывается fallback-сообщение с подсказкой по формату данных.

**Файлы:** `ImportDataSheet.swift`, `PlayerSelectionSheet.swift`.

---

## Инструкция для AI агентов

### ⛔ КРИТИЧНО: Правила создания файлов

**СТРОГО ЗАПРЕЩЕНО создавать новые .md файлы без ЯВНОГО разрешения пользователя!**

**Правило:**
- ❌ **НЕ создавайте** новые MD файлы в `docs/` самостоятельно
- ❌ **НЕ создавайте** README, GUIDE, CHECKLIST, TEMPLATE или любые другие MD файлы
- ✅ **СПРОСИТЕ** пользователя: "Создать новый файл `имя_файла.md` для этой информации?"
- ✅ **ДОЖДИТЕСЬ** явного ответа "да" или "создай файл"
- ✅ **ОБНОВЛЯЙТЕ** существующие файлы вместо создания новых

**Исключения (когда можно создавать файлы БЕЗ разрешения):**
1. Пользователь явно сказал: "создай файл X.md"
2. Пользователь сказал: "сделай документацию в отдельных файлах"
3. Это файлы кода (.swift, .py, .ts и т.д.), а не документация

**Примеры ПРАВИЛЬНОГО поведения:**

```
Пользователь: "распиши детальней по задачам 2 этап"
Агент: 
1. Читаю MASTER_PLAN.md
2. Обновляю раздел "Этап 2" в MASTER_PLAN.md
3. НЕ создаю новые файлы
```

**Примеры НЕПРАВИЛЬНОГО поведения:**

```
Пользователь: "распиши детальней по задачам 2 этап"
Агент:
❌ Создаю TESTING_CHECKLIST.md
❌ Создаю TEST_SCENARIOS.md  
❌ Создаю BUG_REPORT_TEMPLATE.md
❌ Создаю 5+ новых MD файлов без разрешения
```

---

### Когда пользователь просит продолжить работу над проектом:

1. **ВСЕГДА начинайте с чтения актуального плана:**
   ```
   Read ~/.cursor/plans/testflight_deployment_plan_81a25c38.plan.md
   ```

2. **Проверьте текущий статус:**
   - Посмотрите на `todos` в начале плана
   - Найдите задачи со статусом `pending`
   - Начните с первой незавершенной задачи

3. **Документирование:**
   - Вся актуальная информация должна быть в существующих планах
   - Обновляйте план напрямую вместо создания новых файлов
   - Если считаете нужным создать новый файл - **СПРОСИТЕ** пользователя

4. **Обновляйте статус задач** по мере выполнения:
   ```markdown
   status: pending → status: in_progress (начали)
   status: in_progress → status: completed (завершили)
   ```

---

## Текущий этап: Загрузка в TestFlight

**Цель:** Загрузить первый билд приложения в TestFlight для проверки синхронизации CloudKit между устройствами.

**План находится здесь:** `~/.cursor/plans/testflight_deployment_plan_81a25c38.plan.md`

**Что уже сделано:**
- ✅ CloudKit интеграция (код готов)
- ✅ Push Notifications (код готов)
- ✅ Repository pattern (код готов)
- ✅ 43 unit теста (все проходят)
- ✅ CloudKit Record Types созданы в Development
- ✅ Записи успешно сохраняются в CloudKit

**Что осталось:**
- ✅ Все задачи выполнены!
- ✅ Приложение успешно загружено в TestFlight
- ✅ Deep linking настроен и работает
- ✅ Уведомления фильтруются по пользователям
- ✅ Все критические баги исправлены
- ✅ Pre-TestFlight улучшения выполнены (commit f4fd35e)

**Что добавлено в последней сборке (Build 2 → Build 3):**
- ✅ Ребрендинг: "Fish & Chips" вместо "PokerTracker"
- ✅ Вход по email вместо username
- ✅ Исправлена биометрическая аутентификация (Face ID)
- ✅ Номер сборки в профиле
- ✅ Debug доступен в TestFlight
- ✅ Подробные логи для всех auth flows

**Статус:** Готово к загрузке следующей сборки в TestFlight (автоматически через Xcode Cloud)

---

## Правила работы с документацией

### ✅ Что ОСТАВИТЬ

**Важные справочные файлы:**
- `docs/CLOUDKIT_MANUAL_SETUP_REQUIRED.md` - детали CloudKit настройки
- `docs/TESTFLIGHT_DEPLOYMENT_GUIDE.md` - полный гайд по TestFlight
- `docs/TECHNICAL_SPEC.md` - техническая спецификация
- `docs/MASTER_PLAN.md` - этот файл (инструкция для агентов)

**Poker Odds документация:**
- Все файлы `POKER_ODDS_*.md` - рабочая фича приложения

### ❌ Что УДАЛИТЬ

**✅ Выполнено (2026-01-29):** все перечисленные ниже устаревшие файлы удалены из `docs/`.

~~Phase Summaries, CloudKit дубликаты, старая структура (PROGRESS, INDEX, README и др.)~~

### 🚀 Важно: Автоматические сборки

**Xcode Cloud настроен:**
- Каждый `git push` автоматически запускает новую сборку в App Store Connect
- Сборка появляется в App Store Connect через 10-20 минут
- **ВАЖНО:** Релиз в TestFlight нужно делать вручную:
  1. App Store Connect → TestFlight
  2. Найти новую сборку
  3. Нажать "Submit for Testing"
  4. Заполнить "What to Test" (опционально)
  5. Выбрать группы тестировщиков

**Workflow:**
```
git commit → git push → Xcode Cloud сборка → App Store Connect → Manual TestFlight Release
```

**Преимущества:**
- Не нужно создавать архивы локально
- Не нужно загружать через Xcode Organizer
- Консистентные сборки на сервере Apple
- История сборок в App Store Connect

---

## Как агенту начать работу

### Промпты для пользователя

Когда пользователь говорит:
- "Продолжи работу над TestFlight" 
- "Какой следующий шаг?"
- "Загрузи приложение в TestFlight"

**Вы должны:**
1. Прочитать план: `Read ~/.cursor/plans/testflight_deployment_plan_81a25c38.plan.md`
2. Найти первый `pending` todo
3. Начать его выполнение
4. Обновить статус todo на `in_progress`
5. По завершении обновить на `completed`

### Пример правильной работы

```markdown
Пользователь: "Продолжи подготовку к TestFlight"

Агент:
1. Read ~/.cursor/plans/testflight_deployment_plan_81a25c38.plan.md
2. Вижу: todo "cloudkit-indexes" - status: pending
3. Начинаю выполнение:
   - Открываю CloudKit Dashboard
   - Добавляю индексы...
4. Обновляю plan файл:
   - status: pending → status: completed
5. Перехожу к следующему todo
```

### Пример НЕПРАВИЛЬНОЙ работы

```markdown
❌ Создаю новые MD файлы без разрешения:
   - docs/TESTFLIGHT_PLAN_NEW.md
   - docs/TESTING_CHECKLIST.md
   - docs/TESTING_README.md
   (КРИТИЧЕСКАЯ ОШИБКА!)

❌ Спрашиваю пользователя "С чего начать?" вместо чтения плана

❌ Начинаю работу, не прочитав актуальный план

❌ Не обновляю статус todos по мере работы

❌ Игнорирую правила из "Инструкция для AI агентов"
```

**ВАЖНО:** Если вы не уверены, можно ли создать файл - **СПРОСИТЕ** пользователя!

---

## 🚨 КРИТИЧЕСКИЙ БАГ: Синхронизация CloudKit

**Дата обнаружения:** 2026-01-31 11:04

**📋 КРАТКОЕ РЕЗЮМЕ ПЛАНА:**
- ⚠️ Сейчас: Все данные в Private DB → другие пользователи не видят игры
- ✅ Решение: Игры в Public DB, заявки в Private DB
- 🔄 Синхронизация: при запуске + возврат из фона + pull-to-refresh
- 🎯 Текущее решение: загружаем ВСЕ игры (простое, для тестирования)
- 🔮 Будущее: On-Demand Loading через UserGameLink (после TestFlight)

---

### Описание проблемы

**Симптомы:**
1. Устройство 1: Создана игра, поделился ссылкой
2. Устройство 2: Перешел по ссылке → ничего не произошло
3. Устройство 2: Нажал "Присоединиться" → ошибка "Игра не найдена"
4. Синхронизация вручную не помогла

**Корневая причина (после анализа кода):**

🔍 **ТЕКУЩАЯ АРХИТЕКТУРА:**
1. Все записи (игры, профили, заявки) сохраняются в **Private Database** (CloudKitService.swift, строки 56, 85, 92, 99)
2. CloudKitSyncService.sync() ТОЛЬКО **загружает** локальные записи в CloudKit (push), но НЕ скачивает (pull)
3. Есть метод `pullChanges()` (строка 177), но он:
   - Вызывается только вручную (не автоматически при запуске)
   - Загружает из Private Database (только записи текущего пользователя)
   - НЕ может видеть записи других пользователей

**🔴 ДВЕ КРИТИЧЕСКИЕ ПРОБЛЕМЫ:**

**Проблема 1: Private vs Public Database**
- ❌ Сейчас: Игры сохраняются в **Private Database** каждого пользователя
- ✅ Нужно: Игры должны быть в **Public Database** (доступны всем по коду/ссылке)
- **Логика:** 
  - Игра создается пользователем A → сохраняется в Public Database
  - Пользователь B получает код/ссылку → может найти игру в Public Database
  - Пользователь B подает заявку → создается PlayerClaim в Private Database пользователя B

**Проблема 2: Нет автоматической загрузки при старте**
- ❌ Сейчас: Приложение НЕ загружает публичные игры при запуске
- ✅ Нужно: При старте вызывать `fetchPublicGames()` и merge с локальными данными

### ⚠️ Важное замечание о масштабируемости

**ТЕКУЩЕЕ РЕШЕНИЕ (для запуска и тестирования):**
- Загружаем ВСЕ публичные игры из Public Database при старте
- Это простое решение, которое позволит быстро протестировать синхронизацию
- ✅ Подходит для начального этапа (малое количество пользователей и игр)
- ⚠️ НЕ масштабируемо: при 1000+ пользователях и 10000+ играх будет медленно

**БУДУЩЕЕ РЕШЕНИЕ (отложено на позднюю оптимизацию):**
- Не загружаем все игры автоматически
- Игра загружается ТОЛЬКО когда:
  1. Пользователь переходит по deep link (ссылка на игру)
  2. Пользователь вводит код игры вручную
  3. При этом: fetch конкретной игры из Public DB → save в Private DB текущего пользователя
- Результат: у пользователя локально только "его" игры (созданные им + те, к которым присоединился)
- Преимущества:
  - Минимальный трафик (только нужные игры)
  - Быстрый старт приложения
  - Масштабируется на любое количество игр
  
📅 **План миграции на будущее решение будет создан после этапа тестирования в TestFlight**

### Технология CloudKit: Best Practices

**CloudKit - это облачная база данных Apple с двумя зонами:**

1. **Private Database** - личные данные пользователя (доступны **ТОЛЬКО** ему)
   - User (личные настройки)
   - PlayerProfile (профиль пользователя)
   - PlayerClaim (мои заявки на участие в играх)
   
2. **Public Database** - публичные данные (доступны **ВСЕМ** пользователям приложения)
   - Game (все игры - доступны по коду/ссылке)
   - GameWithPlayer (связь игра-игрок - публичная информация)
   - PlayerAlias (псевдонимы для отображения в играх)

**📊 ПРАВИЛЬНАЯ АРХИТЕКТУРА ДАННЫХ:**

```
Пользователь A создает игру:
┌─────────────────────────────────────────────────────────────┐
│ Устройство A (User A)                                       │
│                                                              │
│ 1. Создать Game локально (Core Data)                       │
│ 2. Sync → Сохранить в Public Database                      │
│    ✅ Game доступна ВСЕМ пользователям                      │
└─────────────────────────────────────────────────────────────┘

Пользователь B получает ссылку:
┌─────────────────────────────────────────────────────────────┐
│ Устройство B (User B)                                       │
│                                                              │
│ 1. Запуск приложения → fetchPublicGames()                   │
│    ✅ Загружает Game из Public Database                     │
│ 2. Deep Link → findLocalGame(gameId)                        │
│    ✅ Игра найдена → открыть                                │
│ 3. Подать заявку → создать PlayerClaim                      │
│    ✅ Сохранить в Private Database User B                   │
└─────────────────────────────────────────────────────────────┘
```

**Best Practices для синхронизации:**

```
┌─────────────────────────────────────────────────────────────┐
│                    CloudKit Sync Flow                        │
└─────────────────────────────────────────────────────────────┘

App Launch
   ↓
1. Check CloudKit availability
   ↓
2. Fetch public games (Public Database)
   ↓
3. Merge with local data (Core Data)
   ├─ If CloudKit record newer → Update local
   ├─ If local record newer → Upload to CloudKit
   └─ If conflict → Use merge policy (last-writer-wins)
   ↓
4. Subscribe to push notifications (CKSubscription)
   ↓
5. Background sync (при получении push)
```

**Ключевые принципы:**

1. **Public for Shared Data** - игры в Public Database (доступны всем)
2. **Private for Personal Data** - заявки, профили в Private Database (только свои)
3. **Fetch First** - всегда загружай данные перед показом UI
4. **Incremental Sync** - используй CKFetchRecordZoneChangesOperation для получения только изменений
5. **Merge Strategy** - определи правило разрешения конфликтов (обычно last-writer-wins)
6. **Cache Locally** - Core Data = local cache, CloudKit = source of truth
7. **Push Updates** - подписка на изменения через CKQuerySubscription

### План решения проблемы

**Фаза 0: АРХИТЕКТУРНОЕ РЕШЕНИЕ - Private vs Public Database**

**Задача 0.1:** Определить какие данные куда сохранять

**Public Database (доступно ВСЕМ пользователям):**
- ✅ **Game** - все игры (чтобы пользователи могли находить их по коду/ссылке)
- ✅ **GameWithPlayer** - связь игра-игрок (публичная информация о составе игры)
- ✅ **PlayerAlias** - псевдонимы (для отображения в списках игр)

**Private Database (доступно ТОЛЬКО владельцу):**
- ✅ **User** - данные пользователя (логин, email, настройки)
- ✅ **PlayerProfile** - профиль пользователя
- ✅ **PlayerClaim** - заявки на участие в играх (личные заявки пользователя)

**Задача 0.2:** Модифицировать CloudKitService для поддержки обеих баз

Добавить параметр `database` в методы:
```swift
func save(record: CKRecord, to database: DatabaseType = .private) async throws -> CKRecord
func fetch(recordID: CKRecord.ID, from database: DatabaseType = .private) async throws -> CKRecord
func fetchRecords(withType type: RecordType, from database: DatabaseType = .private) async throws -> [CKRecord]

enum DatabaseType {
    case publicDB
    case privateDB
}
```

**Задача 0.3:** Обновить CloudKitSyncService

- syncGames() → сохранять в **Public Database**
- syncGameWithPlayers() → сохранять в **Public Database**
- syncPlayerAliases() → сохранять в **Public Database**
- syncUsers() → сохранять в **Private Database**
- syncPlayerProfiles() → сохранять в **Private Database**
- syncPlayerClaims() → сохранять в **Private Database**

---

**Фаза 1: Fetch публичных игр при запуске**

**Задача 1.1:** Создать метод `fetchPublicGames()` в CloudKitSyncService
- Загружать все публичные записи CKRecord типа "Game" из **Public Database**
- Фильтровать по статусу (только активные игры, softDeleted = false)
- Сортировать по дате создания (новые первые)

**Задача 1.2:** Реализовать merge логику
- Сравнивать локальные записи с CloudKit по `recordName` (ID)
- Если записи нет локально → создать
- Если есть → сравнить `modificationDate`:
  - CloudKit новее → обновить локальную
  - Локальная новее → НЕ перезаписывать (загрузить на CloudKit при следующем save)

**Задача 1.3:** Вызывать fetch при запуске App
- В `AppDelegate` или `@main` после инициализации Core Data
- Показывать Loading индикатор во время загрузки
- Обрабатывать ошибки сети (retry logic)
- **ВАЖНО:** Также вызывать синхронизацию:
  - При возврате в приложение из фона (ScenePhase.active)
  - Pull-to-refresh в списках игр
  - Фоновая синхронизация (background fetch)

**Фаза 2: Оптимизация производительности** — ✅ ЗАВЕРШЕНА (2026-02-11)

Реализовано:
- **Materialized Views:** UserStatisticsSummary, GameSummaryRecord, UserGameIndex в Core Data и CloudKit
- **Двухфазная загрузка:** performMinimalSync() (< 3 сек) → UI готов → performBackgroundSync() в фоне
- **Lazy loading:** GameWithPlayer загружаются по требованию при открытии игры
- **Пагинация:** loadMoreGames() в MainViewModel, постраничная загрузка в GamesListTabView
- **Кеш статистики:** 5 мин TTL в GameService, invalidateStatisticsCache() при изменениях
- **Background Fetch + Silent Push:** автоматическая синхронизация при возврате и push
- **Миграция:** DataMigrationService.generateMaterializedViews() для существующих данных
- **UI:** SkeletonLoadingView, индикатор фоновой синхронизации в MainView, PerformanceMonitor

**Задача 2.1 (устарела):** CKServerChangeToken — заменено на двухфазную загрузку

**Задача 2.2:** ✅ Реализовать фоновую синхронизацию
- Background Fetch (периодическая синхронизация) — реализовано в AppDelegate
- Push-триггерная синхронизация (при получении silent push) — в didReceiveRemoteNotification

---

## 🤖 Правила для AI-агентов (ОБЯЗАТЕЛЬНО)

**Перед началом любой задачи:**
1. **Прочитать** `docs/MASTER_PLAN.md` — единый источник правды
2. **Убедиться**, что действия соответствуют текущей фазе проекта

**При изменении структуры данных:**
- **ОБЯЗАТЕЛЬНО обновлять** `docs/DATA_DIAGRAM.md` (entity, атрибуты, CloudKit schema, flow)
- К изменениям относятся: новые/изменённые entity, атрибуты, relationships, CloudKit record types, порядок синхронизации

**Парадигма работы:** Small diffs → компиляция → CloudKit Dashboard проверка (если касается CloudKit) → следующий шаг.

---

## 📋 Фаза 3 MVP: Витрины, Пуши, Игроки, Скорость (2026-02)

**Статус:** ✅ РЕАЛИЗОВАНО (2026-02-22)

**Блоки:**
- [x] Блок 0: Обновить MASTER_PLAN
- [x] Блок 1: Исправить "Я" в снипетах (displayName вместо player.name, rebuildAllGameSummaries)
- [x] Блок 7: Исправить pending claims (push после approve/reject)
- [x] Блок 2: Витринная синхронизация (smartSync, checksum, fetchSummariesOnly)
- [x] Блок 3: Push-уведомления о новых/обновлённых играх (CKSubscription)
- [x] Блок 4: Экран "Уведомления" в профиле (AppNotification entity)
- [x] Блок 5: Раздел "Игроки" (isPublic, PlayersTabView, поделиться профилем)
- [x] Блок 6: SuperAdmin просмотр профиля (PlayerPublicProfileView, SuperAdminProfileInfo)

---

**Фаза 3 (Legacy): Обработка Deep Links**

**Задача 3.1:** Улучшить обработку deep link для несуществующих игр
- Если игра не найдена локально → fetch конкретную игру из CloudKit по ID
- Показать Loading экран: "Загрузка игры..."
- Если игра не найдена в CloudKit → показать alert:
  ```
  "Игра не найдена"
  "Возможно, игра была удалена или ссылка устарела"
  [OK]
  ```

**Задача 3.2:** Добавить retry механизм
- Если fetch fail из-за сети → показать:
  ```
  "Ошибка загрузки"
  "Проверьте подключение к интернету"
  [Повторить] [Отмена]
  ```

**Фаза 4: Улучшение UI/UX**

**Задача 4.1:** Показывать статус синхронизации
- В профиле: "Последняя синхронизация: 2 минуты назад"
- При ручной синхронизации: Progress indicator

**Задача 4.2:** Pull-to-refresh ⭐ КРИТИЧНО
- В списке игр: возможность обновить свайпом вниз
- Автоматический fetch свежих данных
- Триггерит `performFullSync()` или `performIncrementalSync()`

**Задача 4.3:** Фоновая синхронизация
- Синхронизация при возврате в приложение из фона
- Использовать `.onChange(of: scenePhase)` в SwiftUI
- Когда scenePhase меняется на `.active` → запустить sync

### Технические детали реализации

**0. CloudKitService: Поддержка Public/Private Database**

```swift
class CloudKitService {
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    
    enum DatabaseType {
        case publicDB
        case privateDB
    }
    
    // НОВЫЙ метод с выбором базы
    func save(record: CKRecord, to database: DatabaseType = .private) async throws -> CKRecord {
        switch database {
        case .publicDB:
            return try await publicDatabase.save(record)
        case .privateDB:
            return try await privateDatabase.save(record)
        }
    }
    
    func saveRecords(_ records: [CKRecord], to database: DatabaseType = .private) async throws -> [CKRecord] {
        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        return try await withCheckedThrowingContinuation { continuation in
            var savedRecords: [CKRecord] = []
            
            operation.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let record):
                    savedRecords.append(record)
                case .failure(let error):
                    print("Failed to save record \(recordID): \(error)")
                }
            }
            
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: savedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // ИЗМЕНЕНО: выбор базы данных
            let db = database == .publicDB ? publicDatabase : privateDatabase
            db.add(operation)
        }
    }
    
    func fetchRecords(
        withType type: RecordType, 
        from database: DatabaseType = .private,
        predicate: NSPredicate = NSPredicate(value: true), 
        limit: Int = 100
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        let db = database == .publicDB ? publicDatabase : privateDatabase
        let (matchResults, _) = try await db.records(matching: query, desiredKeys: nil, resultsLimit: limit)
        
        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Failed to fetch record: \(error)")
            }
        }
        
        return records
    }
}
```

**1. CloudKitSyncService: Новые методы**

```swift
class CloudKitSyncService {
    
    // ОБНОВЛЕННЫЙ метод sync() - разделяет Public и Private записи
    func sync() async throws {
        guard !isSyncing else { return }
        guard await cloudKit.isCloudKitAvailable() else {
            throw CloudKitSyncError.cloudKitNotAvailable
        }
        
        await MainActor.run { isSyncing = true; syncError = nil }
        defer { Task { @MainActor in isSyncing = false } }
        
        do {
            // Private Database sync
            try await syncUsers()              // Private
            try await syncPlayerProfiles()     // Private
            try await syncPlayerClaims()       // Private
            
            // Public Database sync
            try await syncGames()               // Public
            try await syncGameWithPlayers()     // Public
            try await syncPlayerAliases()       // Public
            
            // Update last sync date
            let now = Date()
            await MainActor.run { lastSyncDate = now }
            UserDefaults.standard.set(now, forKey: "lastCloudKitSyncDate")
            
            print("✅ CloudKit sync completed successfully")
        } catch {
            let errorMessage = cloudKit.handleCloudKitError(error)
            await MainActor.run { syncError = errorMessage }
            throw error
        }
    }
    
    // ИЗМЕНЕННЫЙ метод - сохранение в Public Database
    private func syncGames() async throws {
        let context = persistence.container.viewContext
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "softDeleted == NO")
        let games = try context.fetch(fetchRequest)
        
        let records = games.map { $0.toCKRecord() }
        
        if !records.isEmpty {
            // ИЗМЕНЕНО: сохранение в Public Database
            _ = try await cloudKit.saveRecords(records, to: .publicDB)
            print("✅ Synced \(records.count) games to Public Database")
        }
    }
    
    // НОВЫЙ метод - полная синхронизация (при первом запуске)
    func performFullSync() async throws {
        // Fetch данные из CloudKit
        try await fetchPublicGames()
        try await fetchPublicGameWithPlayers()
        try await fetchPublicPlayerAliases()
        
        // Push локальные данные в CloudKit
        try await sync()
    }
    
    // НОВЫЙ метод - загрузка всех публичных игр
    func fetchPublicGames() async throws {
        let predicate = NSPredicate(format: "softDeleted == NO")
        let records = try await cloudKit.fetchRecords(
            withType: .game,
            from: .publicDB,
            predicate: predicate,
            limit: 500
        )
        
        if records.isEmpty {
            print("ℹ️ No public games found in CloudKit")
            return
        }
        
        // Merge с локальными данными
        await mergeGamesWithLocal(records)
        print("✅ Fetched \(records.count) public games from CloudKit")
    }
    
    // НОВЫЙ метод - merge стратегия для игр
    private func mergeGamesWithLocal(_ cloudRecords: [CKRecord]) async {
        let context = persistence.container.viewContext
        
        await context.perform {
            for record in cloudRecords {
                let gameId = UUID(uuidString: record.recordID.recordName)!
                
                // Ищем локально
                let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "id == %@", 
                    gameId as CVarArg
                )
                
                if let localGame = try? context.fetch(fetchRequest).first {
                    // Сравниваем даты
                    if let cloudModDate = record.modificationDate,
                       let localModDate = localGame.lastModified,
                       cloudModDate > localModDate {
                        // CloudKit новее → обновляем локальную
                        localGame.updateFromCKRecord(record)
                        print("🔄 Updated local game: \(gameId)")
                    }
                } else {
                    // Нет локально → создаем
                    if let newGame = self.createGameFromCKRecord(record, in: context) {
                        print("➕ Created local game: \(gameId)")
                    }
                }
            }
            
            // Сохраняем изменения
            if context.hasChanges {
                try? context.save()
            }
        }
    }
    
    // НОВЫЙ метод - создание игры из CKRecord
    private func createGameFromCKRecord(_ record: CKRecord, in context: NSManagedObjectContext) -> Game? {
        let game = Game(context: context)
        game.updateFromCKRecord(record)
        return game
    }
    
    // НОВЫЙ метод - инкрементальная синхронизация (delta sync)
    func performIncrementalSync() async throws {
        guard let token = UserDefaults.standard.lastSyncToken else {
            // Нет токена → полная синхронизация
            return try await performFullSync()
        }
        
        // Fetch только изменения с последней синхронизации
        // (реализация через CKFetchRecordZoneChangesOperation)
        print("🔄 Performing incremental sync with token")
    }
    
    // НОВЫЙ метод - fetch конкретной игры по ID (для deep link)
    func fetchGame(byId gameId: UUID) async throws -> Game? {
        let recordID = CKRecord.ID(recordName: gameId.uuidString)
        
        do {
            let record = try await cloudKit.fetch(recordID: recordID, from: .publicDB)
            
            // Создаем или обновляем локальную копию
            let context = persistence.container.viewContext
            return await context.perform {
                let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", gameId as CVarArg)
                
                if let existingGame = try? context.fetch(fetchRequest).first {
                    existingGame.updateFromCKRecord(record)
                    try? context.save()
                    return existingGame
                } else {
                    let newGame = self.createGameFromCKRecord(record, in: context)
                    try? context.save()
                    return newGame
                }
            }
        } catch {
            throw CloudKitSyncError.gameNotFound
        }
    }
}

// Добавить новую ошибку
enum CloudKitSyncError: LocalizedError {
    case cloudKitNotAvailable
    case syncInProgress
    case networkError
    case authenticationRequired
    case gameNotFound  // НОВАЯ
    
    var errorDescription: String? {
        switch self {
        case .gameNotFound:
            return "Игра не найдена в CloudKit"
        // ... остальные случаи
        }
    }
}
```

**2. App Launch: Инициализация синхронизации**

```swift
@main
struct FishAndChipsApp: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var syncService = CloudKitSyncService.shared
    @State private var isInitialSyncComplete = false
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Запускаем первичную синхронизацию
        Task {
            do {
                print("🚀 Starting initial sync...")
                try await syncService.performFullSync()
                await MainActor.run {
                    isInitialSyncComplete = true
                }
                print("✅ Initial sync completed")
            } catch {
                print("❌ Sync error: \(error)")
                // Не блокируем запуск приложения при ошибке синхронизации
                await MainActor.run {
                    isInitialSyncComplete = true
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if isInitialSyncComplete {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .onAppear {
                        // Подписка на push-уведомления
                        Task {
                            await syncService.subscribeToPushNotifications()
                        }
                    }
            } else {
                // Экран загрузки
                VStack {
                    ProgressView()
                    Text("Загрузка данных...")
                        .padding()
                }
            }
        }
        // 🔄 Синхронизация при возврате из фона
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                print("🔄 App became active, starting background sync...")
                Task {
                    do {
                        // Используем incremental sync если возможно
                        if UserDefaults.standard.lastSyncToken != nil {
                            try await syncService.performIncrementalSync()
                        } else {
                            try await syncService.performFullSync()
                        }
                        print("✅ Background sync completed")
                    } catch {
                        print("❌ Background sync error: \(error)")
                    }
                }
            }
        }
    }
}
```

**3. Deep Link Handler: Fetch конкретной игры**

```swift
func handleDeepLink(gameId: String) async {
    guard let uuid = UUID(uuidString: gameId) else {
        showAlert(title: "Ошибка", message: "Некорректная ссылка")
        return
    }
    
    // 1. Ищем локально
    if let localGame = await findLocalGame(id: uuid) {
        navigateToGame(localGame)
        return
    }
    
    // 2. Не нашли → fetch из CloudKit
    await MainActor.run {
        showLoadingIndicator("Загрузка игры...")
    }
    
    do {
        if let cloudGame = try await CloudKitSyncService.shared.fetchGame(byId: uuid) {
            await MainActor.run {
                hideLoadingIndicator()
                navigateToGame(cloudGame)
            }
        } else {
            await MainActor.run {
                hideLoadingIndicator()
                showAlert(
                    title: "Игра не найдена",
                    message: "Возможно, игра была удалена или ссылка устарела"
                )
            }
        }
    } catch {
        await MainActor.run {
            hideLoadingIndicator()
            showAlert(
                title: "Ошибка загрузки",
                message: "Проверьте подключение к интернету",
                primaryButton: .default(Text("Повторить")) {
                    Task { await handleDeepLink(gameId: gameId) }
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
    }
}
```

**4. UserDefaults: Хранение токена синхронизации**

```swift
extension UserDefaults {
    var lastSyncToken: CKServerChangeToken? {
        get {
            guard let data = data(forKey: "lastSyncToken") else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self, 
                from: data
            )
        }
        set {
            if let token = newValue {
                let data = try? NSKeyedArchiver.archivedData(
                    withRootObject: token,
                    requiringSecureCoding: true
                )
                set(data, forKey: "lastSyncToken")
            } else {
                removeObject(forKey: "lastSyncToken")
            }
        }
    }
}
```

**5. Core Data Extension: updateFromCKRecord для Game**

```swift
extension Game {
    func updateFromCKRecord(_ record: CKRecord) {
        // Обновляем поля из CloudKit записи
        if let gameType = record["gameType"] as? String {
            self.gameType = gameType
        }
        if let notes = record["notes"] as? String {
            self.notes = notes
        }
        if let timestamp = record["timestamp"] as? Date {
            self.timestamp = timestamp
        }
        if let creatorUserIdString = record["creatorUserId"] as? String,
           let creatorUserId = UUID(uuidString: creatorUserIdString) {
            self.creatorUserId = creatorUserId
        }
        if let softDeleted = record["softDeleted"] as? Int {
            self.softDeleted = softDeleted != 0
        }
        
        // Обновляем lastModified
        self.lastModified = record.modificationDate ?? Date()
    }
}
```

**6. Pull-to-Refresh в списке игр**

```swift
import SwiftUI

struct GamesListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Game.timestamp, ascending: false)],
        predicate: NSPredicate(format: "softDeleted == NO"),
        animation: .default
    )
    private var games: FetchedResults<Game>
    
    @StateObject private var syncService = CloudKitSyncService.shared
    @State private var isRefreshing = false
    
    var body: some View {
        List {
            ForEach(games) { game in
                GameRowView(game: game)
            }
        }
        .refreshable {
            await refreshGames()
        }
        .overlay {
            if syncService.isSyncing && !isRefreshing {
                VStack {
                    ProgressView()
                    Text("Синхронизация...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
        }
    }
    
    private func refreshGames() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            print("🔄 Pull-to-refresh triggered")
            
            // Используем incremental sync если есть токен
            if UserDefaults.standard.lastSyncToken != nil {
                try await syncService.performIncrementalSync()
            } else {
                try await syncService.performFullSync()
            }
            
            print("✅ Pull-to-refresh completed")
        } catch {
            print("❌ Pull-to-refresh error: \(error)")
            // Можно показать alert с ошибкой
        }
    }
}
```

**7. Статус синхронизации в профиле**

```swift
struct ProfileView: View {
    @StateObject private var syncService = CloudKitSyncService.shared
    @State private var showingSyncError = false
    
    var body: some View {
        List {
            // ... другие секции профиля
            
            Section("Синхронизация") {
                HStack {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("CloudKit")
                            .font(.headline)
                        Text(syncService.syncStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if syncService.isSyncing {
                        ProgressView()
                    } else {
                        Button(action: {
                            Task {
                                await manualSync()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                
                if let error = syncService.syncError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private func manualSync() async {
        do {
            try await syncService.performFullSync()
        } catch {
            showingSyncError = true
        }
    }
}
```

### Приоритет и очередность

**КРИТИЧНО (делать сейчас):**

**Фаза 0: Архитектурные изменения**
1. ✅ Задача 0.1: Определить разделение Private/Public Database ✅ ГОТОВО
2. ⬜ Задача 0.2: Модифицировать CloudKitService (добавить `DatabaseType`)
3. ⬜ Задача 0.3: Обновить CloudKitSyncService (разделить sync на Public/Private)

**Фаза 1: Fetch данных при запуске + Фоновая синхронизация**
4. ⬜ Задача 1.1: Создать `fetchPublicGames()` в CloudKitSyncService
5. ⬜ Задача 1.2: Реализовать merge логику (`mergeGamesWithLocal()`)
6. ⬜ Задача 1.3: Вызывать `performFullSync()` при запуске App
7. ⬜ Задача 4.3: Синхронизация при возврате из фона (ScenePhase.active)

**Фаза 3: Deep Links**
8. ⬜ Задача 3.1: Улучшить обработку deep link (fetch если нет локально)
9. ⬜ Задача 3.2: Добавить retry механизм при ошибках сети

**Фаза 4: UI для синхронизации**
10. ⬜ Задача 4.2: Pull-to-refresh в списках игр ⭐ КРИТИЧНО
11. ⬜ Задача 4.1: UI статуса синхронизации в профиле

**ВАЖНО (после критичных задач):**
12. Задача 2.1: Incremental sync с CKServerChangeToken
13. Задача 2.2: Background fetch (периодическая синхронизация в фоне)

**ОПЦИОНАЛЬНО (отложено на будущее):**
- Этап 5: On-Demand Game Loading (после TestFlight, когда игр > 100)
- Конфликт-резолюция (пока используем last-writer-wins)
- Оптимизация батчинга (пока загружаем все записи)

**⚠️ ВАЖНАЯ ЗАМЕТКА:**
После Фазы 0 потребуется **повторная миграция CloudKit schema** в Development:
- Game, GameWithPlayer, PlayerAlias → перенести в Public Database
- User, PlayerProfile, PlayerClaim → оставить в Private Database

Можно сделать через CloudKit Dashboard вручную или через CloudKitSchemaCreator.

### Чек-лист для проверки

После реализации проверить:
- [ ] При первом запуске загружаются все публичные игры
- [ ] При возврате из фона запускается синхронизация
- [ ] Pull-to-refresh работает в списках игр
- [ ] Deep link загружает игру из CloudKit если нет локально
- [ ] Ошибка "Игра не найдена" показывается корректно
- [ ] Кнопка "Синхронизация" в профиле работает
- [ ] Нет дублирования записей после merge
- [ ] Core Data + CloudKit данные консистентны
- [ ] Работает на 2+ устройствах с разными пользователями

---

## 🐛 НОВЫЙ БАГ: GameWithPlayer не синхронизируется (2026-02-03)

**Дата обнаружения:** 2026-02-03

**📋 КРАТКОЕ ОПИСАНИЕ ПРОБЛЕМЫ:**
- ✅ Игра (Game) сохраняется и загружается из Public DB - работает
- ❌ Игроки (GameWithPlayer) НЕ синхронизируются в CloudKit вообще
- 🔍 Результат: При открытии игры по диплинку другим пользователем отображается "Нет данных" и "Игроки (0)"

### Симптомы

**Сценарий:**
1. Пользователь A создает игру, добавляет игроков с buyins/cashouts
2. Пользователь A делится ссылкой на игру (диплинк)
3. Пользователь B (другое устройство, другой iCloud) открывает ссылку
4. Игра открывается (экран "Детали игры")
5. НО: "Результаты игры: Нет данных", "Игроки (0)"

**Скриншот проблемы:**
- Дата игры: 25 янв. 2026г., 00:00
- Сумма байинов: 0 (0 Т)
- Игроки: 0
- Кнопка "Отправить статистику по игре" (не активна)

### Анализ кода

**Что РАБОТАЕТ:**
1. ✅ [`CloudKitService.swift`](FishAndChips/Services/CloudKitService.swift) - поддерживает Public/Private DB
2. ✅ [`CloudKitSyncService.syncGames()`](FishAndChips/Services/CloudKitSyncService.swift#L142-157) - сохраняет Game в Public DB
3. ✅ [`CloudKitSyncService.fetchPublicGames()`](FishAndChips/Services/CloudKitSyncService.swift#L233) - загружает игры из Public DB
4. ✅ [`DeepLinkService`](FishAndChips/Services/DeepLinkService.swift) - обрабатывает диплинки и вызывает fetchGame(byId:)

**Что НЕ РАБОТАЕТ:**
1. ❌ [`CloudKitModels.swift`](FishAndChips/Models/CloudKit/CloudKitModels.swift) - НЕТ extension для GameWithPlayer (toCKRecord, updateFromCKRecord)
2. ❌ [`CloudKitSyncService.swift`](FishAndChips/Services/CloudKitSyncService.swift) - НЕТ метода syncGameWithPlayers()
3. ❌ Нет метода fetchPublicGameWithPlayers()
4. ❌ Нет метода fetchGameWithPlayers(forGameId:) для конкретной игры
5. ❌ GameWithPlayer записи вообще НЕ сохраняются в CloudKit

**Подтверждение:**
- [`CloudKitSchemaCreator.swift`](FishAndChips/Services/CloudKitSchemaCreator.swift#L118-127) создает sample GameWithPlayer в **Public DB** - схема правильная
- Но реальный код НЕ синхронизирует GameWithPlayer туда

### Архитектура данных

**GameWithPlayer - что это:**
- Связь many-to-many между Game и Player
- Содержит данные участника игры: buyin (Int16), cashout (Int64)
- Опционально связан с PlayerProfile (для идентификации пользователя)
- Создается при добавлении игроков в игру

**Где создается:**
- [`AddPlayerToGameSheet.swift`](FishAndChips/AddPlayerToGameSheet.swift#L77) - при добавлении игрока
- [`DataImportService.swift`](FishAndChips/Services/DataImportService.swift#L327) - при импорте данных
- Tests - в тестах

**Где ДОЛЖЕН храниться:**
- ✅ Public Database - чтобы другие пользователи видели состав игры
- ❌ НЕ Private Database - иначе только создатель видит игроков

### План исправления

#### Этап 1: Проверка CloudKit Dashboard

**Цель:** Убедиться что схема создана правильно и понять текущее состояние данных

**Действия:**
1. Открыть CloudKit Dashboard → Development environment
2. Проверить Public Database → Schema → Record Types:
   - [ ] Game - должен быть
   - [ ] PlayerAlias - должен быть
   - [ ] GameWithPlayer - проверить есть ли, какие поля
3. Проверить Private Database → Schema → Record Types:
   - [ ] User - должен быть
   - [ ] PlayerProfile - должен быть
   - [ ] PlayerClaim - должен быть
   - [ ] GameWithPlayer - НЕ должно быть (если есть - это проблема)
4. Проверить данные:
   - Public Database → Data → найти игру от 25 янв. 2026
   - Записать recordID игры
   - Искать GameWithPlayer записи для этой игры (Public DB query)
   - Если не найдены → проверить Private DB

**Что снять скриншотами:**
- [ ] Public DB: список Record Types
- [ ] Public DB: схема GameWithPlayer (если есть)
- [ ] Private DB: список Record Types  
- [ ] Data: запись Game
- [ ] Data: записи GameWithPlayer (где нашлись)

#### Этап 2: Добавить CloudKit extension для GameWithPlayer

**Файл:** [`FishAndChips/Models/CloudKit/CloudKitModels.swift`](FishAndChips/Models/CloudKit/CloudKitModels.swift)

**Добавить после PlayerClaim extension (строка 294):**

```swift
// MARK: - GameWithPlayer CloudKit Extension

extension GameWithPlayer {
    func toCKRecord() -> CKRecord {
        // Генерируем уникальный ID или используем существующий
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "GameWithPlayer", recordID: recordID)
        
        record["buyin"] = buyin as CKRecordValue
        record["cashout"] = cashout as CKRecordValue
        
        // Reference к Game (обязательный)
        if let game = game {
            let gameRef = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: game.gameId.uuidString),
                action: .deleteSelf  // Удалить при удалении игры
            )
            record["game"] = gameRef as CKRecordValue
        }
        
        // Reference к PlayerProfile (опциональный)
        if let playerProfile = playerProfile {
            let profileRef = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: playerProfile.profileId.uuidString),
                action: .none
            )
            record["playerProfile"] = profileRef as CKRecordValue
        }
        
        // Имя игрока для отображения
        if let player = player, let playerName = player.name {
            record["playerName"] = playerName as CKRecordValue
        }
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let buyin = record["buyin"] as? Int16 {
            self.buyin = buyin
        }
        if let cashout = record["cashout"] as? Int64 {
            self.cashout = cashout
        }
        // References (game, playerProfile) обрабатываются при merge
    }
}
```

#### Этап 3: Добавить синхронизацию GameWithPlayer

**Файл:** [`FishAndChips/Services/CloudKitSyncService.swift`](FishAndChips/Services/CloudKitSyncService.swift)

**3.1. Добавить метод syncGameWithPlayers() после syncGames() (после строки 157):**

```swift
// MARK: - GameWithPlayer Sync (Public Database)

private func syncGameWithPlayers() async throws {
    let context = persistence.container.viewContext
    
    let fetchRequest: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
    // Только для не удалённых игр
    fetchRequest.predicate = NSPredicate(format: "game.softDeleted == NO")
    
    let gameWithPlayers = try context.fetch(fetchRequest)
    
    let records = gameWithPlayers.map { $0.toCKRecord() }
    
    if !records.isEmpty {
        _ = try await cloudKit.saveRecords(records, to: .publicDB)
        print("✅ Synced \(records.count) game-player records to Public Database")
    }
}
```

**3.2. Обновить метод sync() (строка 68-90) - добавить вызов syncGameWithPlayers():**

```swift
do {
    // Private Database sync
    try await syncUsers()              // Private
    try await syncPlayerProfiles()     // Private
    try await syncPlayerClaims()       // Private
    
    // Public Database sync
    try await syncGames()               // Public
    try await syncGameWithPlayers()     // Public ← ДОБАВИТЬ ЭТУ СТРОКУ
    try await syncPlayerAliases()       // Public
    
    // Update last sync date
    let now = Date()
    await MainActor.run { lastSyncDate = now }
    UserDefaults.standard.set(now, forKey: "lastCloudKitSyncDate")
    
    print("✅ CloudKit sync completed successfully")
}
```

#### Этап 4: Добавить загрузку GameWithPlayer

**Файл:** [`FishAndChips/Services/CloudKitSyncService.swift`](FishAndChips/Services/CloudKitSyncService.swift)

**4.1. Добавить метод fetchPublicGameWithPlayers() после fetchPublicPlayerAliases() (после строки 268):**

```swift
// MARK: - Fetch Public GameWithPlayer

private func fetchPublicGameWithPlayers() async throws {
    let records = try await cloudKit.fetchRecords(
        withType: .gameWithPlayer,
        from: .publicDB,
        limit: 1000
    )
    
    if !records.isEmpty {
        print("📥 Fetched \(records.count) game-player records from CloudKit")
        await mergeGameWithPlayersWithLocal(records)
    }
}
```

**4.2. Добавить метод mergeGameWithPlayersWithLocal():**

```swift
@MainActor
private func mergeGameWithPlayersWithLocal(_ cloudRecords: [CKRecord]) async {
    let context = persistence.container.viewContext
    
    for record in cloudRecords {
        // Получаем gameId из reference
        guard let gameRef = record["game"] as? CKRecord.Reference else {
            print("⚠️ GameWithPlayer record without game reference")
            continue
        }
        let gameIdString = gameRef.recordID.recordName
        guard let gameId = UUID(uuidString: gameIdString) else {
            print("⚠️ Invalid game ID: \(gameIdString)")
            continue
        }
        
        // Ищем игру локально
        let gameFetch: NSFetchRequest<Game> = Game.fetchRequest()
        gameFetch.predicate = NSPredicate(format: "gameId == %@", gameId as CVarArg)
        
        guard let game = try? context.fetch(gameFetch).first else {
            print("⚠️ Game \(gameId) not found locally, skipping GameWithPlayer")
            continue
        }
        
        // Ищем PlayerProfile если есть reference
        var playerProfile: PlayerProfile? = nil
        if let profileRef = record["playerProfile"] as? CKRecord.Reference {
            let profileIdString = profileRef.recordID.recordName
            if let profileId = UUID(uuidString: profileIdString) {
                playerProfile = persistence.fetchPlayerProfile(byProfileId: profileId)
            }
        }
        
        // Получаем имя игрока
        guard let playerName = record["playerName"] as? String else {
            print("⚠️ GameWithPlayer record without playerName")
            continue
        }
        
        // Ищем или создаём Player
        var player: Player? = nil
        let playerFetch: NSFetchRequest<Player> = Player.fetchRequest()
        playerFetch.predicate = NSPredicate(format: "name == %@", playerName)
        player = try? context.fetch(playerFetch).first
        
        if player == nil {
            player = Player(context: context)
            player?.name = playerName
            print("➕ Created Player: \(playerName)")
        }
        
        // Проверяем не существует ли уже GameWithPlayer
        let gwpFetch: NSFetchRequest<GameWithPlayer> = GameWithPlayer.fetchRequest()
        gwpFetch.predicate = NSPredicate(
            format: "game == %@ AND player == %@",
            game,
            player as CVarArg
        )
        
        if let existingGWP = try? context.fetch(gwpFetch).first {
            // Обновляем существующий
            existingGWP.updateFromCKRecord(record)
            print("🔄 Updated GameWithPlayer for \(playerName) in game \(gameId)")
        } else {
            // Создаём новый
            let gwp = GameWithPlayer(context: context)
            gwp.game = game
            gwp.player = player
            gwp.playerProfile = playerProfile
            gwp.updateFromCKRecord(record)
            print("➕ Created GameWithPlayer for \(playerName) in game \(gameId)")
        }
    }
    
    // Сохраняем все изменения
    if context.hasChanges {
        do {
            try context.save()
            print("✅ Merged GameWithPlayer records with local database")
        } catch {
            print("❌ Failed to save merged GameWithPlayer: \(error)")
        }
    }
}
```

**4.3. Добавить метод fetchGameWithPlayers(forGameId:) для конкретной игры:**

```swift
// MARK: - Fetch GameWithPlayers for specific game

func fetchGameWithPlayers(forGameId gameId: UUID) async throws {
    // Query с фильтром по игре
    let gameRecordID = CKRecord.ID(recordName: gameId.uuidString)
    let gameRef = CKRecord.Reference(recordID: gameRecordID, action: .none)
    let predicate = NSPredicate(format: "game == %@", gameRef)
    
    let records = try await cloudKit.fetchRecords(
        withType: .gameWithPlayer,
        from: .publicDB,
        predicate: predicate,
        limit: 100
    )
    
    if !records.isEmpty {
        print("📥 Fetched \(records.count) players for game \(gameId)")
        await mergeGameWithPlayersWithLocal(records)
    } else {
        print("ℹ️ No players found in CloudKit for game \(gameId)")
    }
}
```

**4.4. Обновить performFullSync() (строка 214-229) - добавить fetchPublicGameWithPlayers():**

```swift
func performFullSync() async throws {
    guard await cloudKit.isCloudKitAvailable() else {
        throw CloudKitSyncError.cloudKitNotAvailable
    }
    
    print("🚀 Starting full sync...")
    
    // 1. Fetch public data from CloudKit
    try await fetchPublicGames()
    try await fetchPublicPlayerAliases()
    try await fetchPublicGameWithPlayers()  // ← ДОБАВИТЬ
    
    // 2. Push local changes to CloudKit
    try await sync()
    
    print("✅ Full sync completed")
}
```

**4.5. Обновить fetchGame(byId:) (строка 350-376) - загружать игроков при открытии игры:**

```swift
func fetchGame(byId gameId: UUID) async throws -> Game? {
    let recordID = CKRecord.ID(recordName: gameId.uuidString)
    
    do {
        let record = try await cloudKit.fetch(recordID: recordID, from: .publicDB)
        
        // Create or update local copy
        let game = await MainActor.run {
            let context = persistence.container.viewContext
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId as CVarArg)
            
            if let existingGame = try? context.fetch(fetchRequest).first {
                existingGame.updateFromCKRecord(record)
                try? context.save()
                return existingGame
            } else {
                let newGame = self.createGameFromCKRecord(record, in: context)
                try? context.save()
                return newGame
            }
        }
        
        // ← ДОБАВИТЬ: Загрузить игроков для этой игры
        if game != nil {
            print("🔄 Fetching players for game \(gameId)...")
            try await fetchGameWithPlayers(forGameId: gameId)
        }
        
        return game
    } catch {
        print("❌ Failed to fetch game \(gameId) from CloudKit: \(error)")
        throw CloudKitSyncError.gameNotFound
    }
}
```

#### Этап 5: Добавить RecordType

**Файл:** [`FishAndChips/Services/CloudKitService.swift`](FishAndChips/Services/CloudKitService.swift)

**Обновить enum RecordType (строка 26-33):**

```swift
enum RecordType: String {
    case user = "User"
    case game = "Game"
    case playerProfile = "PlayerProfile"
    case playerAlias = "PlayerAlias"
    case gameWithPlayer = "GameWithPlayer"  // ← ДОБАВИТЬ
    case playerClaim = "PlayerClaim"
}
```

#### Этап 6: Тестирование

**6.1. Запустить полную синхронизацию на устройстве создателя (Пользователь A):**
1. Запустить приложение
2. Открыть Профиль → Debug → Sync или Pull-to-refresh в списке игр
3. Проверить логи Xcode:
   ```
   ✅ Synced X games to Public Database
   ✅ Synced Y game-player records to Public Database
   ```
4. Проверить CloudKit Dashboard → Public DB → Data:
   - Должны появиться GameWithPlayer записи
   - Проверить что они связаны с Game через reference

**6.2. Проверить загрузку на другом устройстве (Пользователь B):**
1. Открыть приложение
2. Pull-to-refresh или переоткрыть по диплинку
3. Проверить логи:
   ```
   📥 Fetched Z game-player records from CloudKit
   ➕ Created GameWithPlayer for [playerName] in game [gameId]
   ```
4. Проверить UI:
   - "Игроки (X)" - должно быть > 0
   - "Результаты игры" - должны показываться имена и суммы
   - Buyins и cashouts отображаются корректно

**6.3. Тест сценария End-to-End:**
- [ ] Устройство A: Создать новую игру с 2-3 игроками
- [ ] Устройство A: Синхронизация (автоматическая или ручная)
- [ ] CloudKit Dashboard: Проверить что Game и GameWithPlayer в Public DB
- [ ] Устройство A: Поделиться ссылкой на игру
- [ ] Устройство B: Открыть ссылку
- [ ] Устройство B: Игра открывается с полным составом игроков
- [ ] Устройство B: Результаты отображаются корректно

### Чек-лист выполнения

**Диагностика:**
- [ ] Проверена схема Public Database в CloudKit Dashboard
- [ ] Проверена схема Private Database
- [ ] Найдены записи GameWithPlayer (в какой базе)
- [ ] Сделаны скриншоты для документации

**Изменения кода:**
- [ ] Добавлен CloudKit extension для GameWithPlayer (toCKRecord, updateFromCKRecord)
- [ ] Добавлен метод syncGameWithPlayers() в CloudKitSyncService
- [ ] Добавлен метод fetchPublicGameWithPlayers()
- [ ] Добавлен метод mergeGameWithPlayersWithLocal()
- [ ] Добавлен метод fetchGameWithPlayers(forGameId:)
- [ ] Обновлен enum RecordType (добавлен gameWithPlayer)
- [ ] Обновлен метод sync() (вызов syncGameWithPlayers)
- [ ] Обновлен performFullSync() (вызов fetchPublicGameWithPlayers)
- [ ] Обновлен fetchGame(byId:) (загрузка игроков для конкретной игры)

**Тестирование:**
- [ ] Запущена синхронизация на устройстве создателя игры
- [ ] Проверены данные в CloudKit Dashboard (GameWithPlayer в Public DB)
- [ ] Протестирован диплинк на другом устройстве
- [ ] Игроки отображаются корректно
- [ ] Результаты игры показываются с правильными суммами
- [ ] End-to-End сценарий работает

**Документация:**
- [ ] Обновлена история в начале MASTER_PLAN.md
- [ ] Задокументировано решение проблемы
- [ ] Добавлена дата завершения исправления

### Важные замечания

**⚠️ Про дубликаты:**
- При первой синхронизации могут создаться дубликаты GameWithPlayer
- Решение: использовать уникальный идентификатор (можно добавить поле objectID в Core Data)
- Или проверять существование перед созданием (текущий подход в merge)

**⚠️ Про производительность:**
- Если в игре 10+ игроков и 100+ игр → 1000+ записей GameWithPlayer
- Рекомендуется батчинг (загружать по 100-500 за раз)
- Добавить индексы в CloudKit: game (reference) - Queryable

**⚠️ Про миграцию существующих данных:**
- Если GameWithPlayer уже есть в Private DB → удалить их после переноса в Public DB
- Или оставить как есть и создать новые в Public DB (дубликаты)
- Лучший вариант: удалить старые после успешной синхронизации

**⚠️ Про схему CloudKit:**
- Если GameWithPlayer НЕТ в CloudKit схеме → создать через CloudKitSchemaCreator
- После создания схемы в Development → задеплоить в Production

---

## 🔮 Будущие оптимизации (после TestFlight)

### Этап 5: Оптимизация масштабируемости (отложено)

**Проблема текущего решения:**
- Загружаем ВСЕ публичные игры из Public Database
- При росте до 1000+ пользователей и 10000+ игр:
  - Медленная загрузка при старте приложения
  - Большой трафик (загружаем ненужные игры)
  - Захламление локальной БД

**Решение: On-Demand Game Loading**

**Концепция:**
```
Пользователь НЕ видит все игры автоматически
↓
Игра загружается ТОЛЬКО когда:
1. Пользователь создает игру (сохраняется в Public DB + локально)
2. Пользователь переходит по ссылке/вводит код игры:
   → fetch конкретной игры из Public DB по ID
   → save в локальную БД
   → добавить связь User ↔ Game (участник/наблюдатель)
3. Push-уведомление о приглашении в игру
   → fetch игры из Public DB
   → save локально
```

**Архитектура:**

```
┌─────────────────────────────────────────────────────────────┐
│                     Public Database                          │
│                                                               │
│  - Game (все игры всех пользователей)                       │
│  - GameWithPlayer (составы игр)                             │
│  - PlayerAlias (псевдонимы)                                 │
│                                                               │
│  ⚠️ Пользователь НЕ загружает все игры!                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    (fetch по требованию)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Private Database                          │
│                                                               │
│  - User (данные пользователя)                               │
│  - PlayerProfile                                             │
│  - PlayerClaim (заявки на участие)                          │
│  - UserGameLink (связь: какие игры доступны пользователю)   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    (локальный кэш)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       Core Data                              │
│                                                               │
│  - Только игры, к которым у пользователя есть доступ:       │
│    * Созданные им                                            │
│    * Где он участник                                         │
│    * Где он подал заявку                                     │
│    * По которым получил приглашение                          │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

**Новая сущность: UserGameLink**

```swift
// Private Database
UserGameLink {
    userId: UUID           // Текущий пользователь
    gameId: UUID           // Игра
    linkType: String       // "creator", "participant", "pending", "observer"
    createdAt: Date
    lastAccessedAt: Date
}
```

**Изменения в CloudKitSyncService:**

```swift
// УБРАТЬ из начальной синхронизации
func performFullSync() async throws {
    // ❌ СТАРОЕ: try await fetchPublicGames() - загружали ВСЕ игры
    
    // ✅ НОВОЕ: загружаем только свои связи
    try await fetchUserGameLinks()       // Private DB
    try await fetchMyGames()             // Private DB: игры по UserGameLink
    try await syncUsers()
    try await syncPlayerProfiles()
}

// НОВЫЙ метод: загрузка игр по ссылкам
func fetchMyGames() async throws {
    // 1. Получить список gameId из UserGameLinks
    let links = try await fetchUserGameLinks()
    let gameIds = links.map { $0.gameId }
    
    // 2. Fetch только эти игры из Public DB
    for gameId in gameIds {
        try await fetchAndCacheGame(byId: gameId)
    }
}

// ОБНОВЛЕННЫЙ метод: fetch игры по ID (для deep link)
func fetchAndCacheGame(byId gameId: UUID) async throws -> Game {
    // 1. Fetch из Public DB
    let record = try await cloudKit.fetch(
        recordID: CKRecord.ID(recordName: gameId.uuidString),
        from: .publicDB
    )
    
    // 2. Save в локальную БД (Core Data)
    let game = createOrUpdateLocalGame(from: record)
    
    // 3. Создать UserGameLink в Private DB
    try await createUserGameLink(
        gameId: gameId, 
        linkType: "observer"  // или "participant" если уже участник
    )
    
    return game
}
```

**Deep Link обработка (обновленная):**

```swift
func handleDeepLink(gameId: UUID) async {
    // 1. Ищем в локальной БД
    if let localGame = await findLocalGame(id: gameId) {
        navigateToGame(localGame)
        return
    }
    
    // 2. Нет локально → fetch из Public DB и сохранить
    showLoading("Загрузка игры...")
    
    do {
        // Fetch и создать UserGameLink
        let game = try await syncService.fetchAndCacheGame(byId: gameId)
        hideLoading()
        navigateToGame(game)
    } catch {
        hideLoading()
        showAlert("Игра не найдена", "Возможно, игра была удалена")
    }
}
```

**Преимущества On-Demand Loading:**
- ⚡ Быстрый старт приложения (загружаем только свои игры)
- 📉 Минимальный трафик (только нужные данные)
- 🗂️ Чистая локальная БД (нет мусора)
- 📈 Масштабируется на любое количество игр
- 🔒 Приватность (пользователь не видит чужие игры)

**Недостатки:**
- 🔧 Более сложная архитектура (UserGameLink)
- 🧪 Требует тщательного тестирования
- 🔄 Миграция с текущей схемы

**Оценка трудозатрат:**
- Создание UserGameLink сущности: 2-3 часа
- Рефакторинг CloudKitSyncService: 4-6 часов
- Обновление UI и deep links: 2-3 часа
- Тестирование и отладка: 4-6 часов
- **Итого:** ~15-20 часов работы

**Когда начинать:**
- ✅ После успешного тестирования в TestFlight
- ✅ После получения feedback от пользователей
- ✅ Когда количество игр в Public DB > 100
- ✅ Когда время загрузки при старте > 5 секунд

**План миграции:**
1. Создать UserGameLink в CloudKit schema
2. Сгенерировать UserGameLinks для существующих игр
3. Обновить CloudKitSyncService
4. Обновить UI (loading states)
5. Тестирование на TestFlight
6. Плавный релиз (feature flag)

📅 **Этот этап будет детализирован после завершения текущего тестирования**

---

## 🎯 Pre-TestFlight улучшения (2026-02-02) ✅ ВЫПОЛНЕНО

**Статус:** ✅ Завершено (commit f4fd35e)

**Контекст:** Игры и пользователи успешно загружены в development CloudKit database. Перед загрузкой следующей сборки в App Store Connect и TestFlight внесены финальные улучшения UX и функциональности.

### ✅ Выполненные улучшения

1. **✅ Ребрендинг на "Fish & Chips"**
   - Было: на странице логина отображалось "PokerTracker"
   - Стало: "Fish & Chips"
   - Файл: `LoginView.swift` (строка 23)

2. **✅ Вход по email и паролю**
   - Было: вход по username + пароль
   - Стало: вход по email + пароль
   - Username используется только для отображения в профиле и общении
   - CloudKit восстановление по email

3. **✅ Уникальность полей при регистрации**
   - Email = логин (уникальный идентификатор для входа) ✓
   - Username = отображаемое имя (уникальное, для профиля и чатов) ✓
   - Оба поля обязательны и проверяются на уникальность ✓

4. **✅ Номер сборки в профиле**
   - Добавлена версия и build number в верхней части профиля
   - Формат: "Версия 1.0 (2)"
   - Файл: `ProfileView.swift`

5. **✅ Исправлена биометрическая аутентификация**
   - Проблема: Face ID не работал после logout
   - Решение: Новый LAContext для каждой попытки + флаг requiresReauth
   - Keychain сохраняется после logout для Face ID

6. **✅ Debug доступен в TestFlight**
   - Убрано условие `#if DEBUG`
   - Debug view доступен во всех сборках

7. **✅ Подробные логи для отладки**
   - [AUTH STATUS] - проверка статуса при запуске
   - [LOGIN] - вход по email
   - [REGISTER] - регистрация
   - [BIOMETRIC] - Face ID/Touch ID
   - [LOGOUT] - выход

### Технические детали реализации

#### 1. Изменение названия на странице логина

**Файл:** `FishAndChips/Views/LoginView.swift`

Строка 23 - заменить:
```swift
Text("Fish & Chips")
    .font(.largeTitle)
    .fontWeight(.bold)
```

#### 2. Вход по email и паролю

**Архитектура аутентификации:**
- **Email** → используется для логина (уникальный идентификатор)
- **Username** → отображается в профиле и общении между пользователями

**Файл:** `FishAndChips/Views/LoginView.swift`
- Строка 6: `@State private var username` → `@State private var email`
- Строка 28: TextField - заменить "Имя пользователя" на "Email" + `.keyboardType(.emailAddress)`
- Строка 86: `try await authViewModel.login(email: email, password: password)`

**Файл:** `FishAndChips/ViewModels/AuthViewModel.swift`

Обновить метод `login()` (строка 150):
```swift
func login(email: String, password: String) async throws {
    isLoading = true
    authState = .authenticating
    
    try? await Task.sleep(nanoseconds: 200_000_000)
    
    // Попытка 1: Поиск по email локально
    var user = persistence.fetchUser(byEmail: email)
    
    // Попытка 2: Если не найден - загрузить из CloudKit
    if user == nil {
        print("⚠️ User with email '\(email)' not found locally, trying CloudKit...")
        do {
            user = try await CloudKitSyncService.shared.fetchUser(byEmail: email)
            if user != nil {
                print("✅ User restored from CloudKit by email")
            }
        } catch {
            print("❌ Failed to fetch user from CloudKit: \(error)")
        }
    }
    
    guard let foundUser = user else {
        isLoading = false
        authState = .error("Пользователь не найден")
        throw AuthenticationError.userNotFound
    }
    
    let passwordHash = hashPassword(password)
    guard foundUser.passwordHash == passwordHash else {
        isLoading = false
        authState = .error("Неверный пароль")
        throw AuthenticationError.invalidCredentials
    }
    
    persistence.updateUserLastLogin(foundUser)
    _ = keychain.saveUserId(foundUser.userId.uuidString)
    _ = keychain.saveUsername(foundUser.username)
    
    currentUser = foundUser
    isLoading = false
    authState = .authenticated
}
```

**Файл:** `FishAndChips/Services/CloudKitSyncService.swift`

Добавить новый метод после `fetchUser(byUsername:)` (после строки 423):
```swift
/// Загружает пользователя из CloudKit Private Database по email
func fetchUser(byEmail email: String) async throws -> User? {
    print("🔍 Trying to fetch user by email '\(email)' from CloudKit...")
    
    let predicate = NSPredicate(format: "email == %@", email)
    
    let result = try await cloudKit.queryRecords(
        withType: .user,
        from: .privateDB,
        predicate: predicate,
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
        resultsLimit: 1
    )
    
    guard let userRecord = result.records.first else {
        print("❌ User with email '\(email)' not found in CloudKit")
        return nil
    }
    
    print("✅ Found user by email in CloudKit, creating local copy...")
    
    let user = try await MainActor.run {
        createUserFromCKRecord(userRecord, in: persistence.container.viewContext)
    }
    
    if let user = user {
        await fetchPlayerProfile(forUserId: user.userId)
    }
    
    return user
}
```

#### 3. Проверка регистрации

**Статус:** ✅ Уже реализовано

Текущая реализация (`RegistrationView.swift` + `AuthViewModel.swift`):
- ✅ Username: обязательное поле, проверка уникальности
- ✅ Email: обязательное поле, валидация формата, проверка уникальности
- ✅ Валидация пароля: минимум 6 символов, буквы + цифры

Действие: только протестировать работу валидаций.

#### 4. Номер сборки в профиле

**Файл:** `FishAndChips/Views/ProfileView.swift`

Добавить в самом верху ScrollView (после строки 32, перед секцией "Пользователь"):
```swift
// Версия и номер сборки
VStack(alignment: .leading, spacing: 4) {
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
        Text("Версия \(version) (\(build))")
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
    }
}
.frame(maxWidth: .infinity, alignment: .trailing)
.padding(.horizontal)
.padding(.top, 8)
```

**Текущая конфигурация:** Version 1.0, Build 2
**Результат:** В профиле будет отображаться "Версия 1.0 (2)"

### Диаграмма архитектуры

**Новый flow аутентификации:**

```
LoginView → AuthViewModel (email + password)
    ↓
1. Persistence.fetchUser(byEmail:) [локально]
    ↓
2. Если не найден → CloudKitSyncService.fetchUser(byEmail:) [CloudKit Private DB]
    ↓
3. Создать локальную копию (если загружен из CloudKit)
    ↓
4. Проверка пароля (SHA256 hash)
    ↓
5. Сохранить в Keychain (userId, username)
    ↓
6. Authenticated state
```

**Регистрация:**

```
RegistrationView → AuthViewModel.register(username, email, password)
    ↓
1. Проверка уникальности username (локально)
    ↓
2. Проверка уникальности email (локально)
    ↓
3. Валидация формата email (regex)
    ↓
4. Валидация пароля (6+ символов, буквы + цифры)
    ↓
5. Создать User + PlayerProfile (Core Data)
    ↓
6. Синхронизация → CloudKit Private DB
    ↓
7. Автоматический вход
```

### Чек-лист тестирования

После реализации проверить:
- [ ] На странице логина отображается "Fish & Chips"
- [ ] Вход принимает email (клавиатура email)
- [ ] Вход работает с существующими пользователями (по email)
- [ ] CloudKit восстановление работает (если пользователь удален локально)
- [ ] Регистрация проверяет уникальность username
- [ ] Регистрация проверяет уникальность и формат email
- [ ] Регистрация создает User + PlayerProfile
- [ ] В профиле отображается номер сборки (1.0 (2))
- [ ] Биометрический вход продолжает работать
- [ ] Сообщения об ошибках на русском языке

### Файлы для изменения

| Файл | Изменения |
|------|-----------|
| `FishAndChips/Views/LoginView.swift` | Название + поле email |
| `FishAndChips/ViewModels/AuthViewModel.swift` | Метод login(email:password:) |
| `FishAndChips/Services/CloudKitSyncService.swift` | Новый метод fetchUser(byEmail:) |
| `FishAndChips/Views/ProfileView.swift` | Номер сборки |

### Важные замечания

**CloudKit:**
- Пользователи остаются в Private Database (изменений в схему не требуется)
- Поле `email` уже существует в Core Data модели User
- CloudKit record уже синхронизирует email

**Обратная совместимость:**
- Существующие пользователи должны помнить свой email для входа
- Если email не указан (старые пользователи) - потребуется миграция

**Версия:**
- Current: Version 1.0, Build 2
- После изменений: можно увеличить до Build 3 перед загрузкой в TestFlight

---

## 📊 Краткая сводка изменений (commit f4fd35e)

### Измененные файлы (7 файлов, +516/-46 строк)

| Файл | Изменения | Строк |
|------|-----------|-------|
| `AuthViewModel.swift` | Email auth, biometric fix, logging | +173/-46 |
| `MASTER_PLAN.md` | Документация Pre-TestFlight | +254 |
| `CloudKitSyncService.swift` | fetchUser(byEmail:) | +47 |
| `LoginView.swift` | Email field, "Fish & Chips" | +11 |
| `ProfileView.swift` | Build number, Debug в TestFlight | +17 |
| `CloudKitService.swift` | Minor fixes | +6 |
| `CloudKitModels.swift` | Minor fixes | +8 |

### Ключевые изменения

**Аутентификация:**
- `login(email:password:)` вместо `login(username:password:)`
- `fetchUser(byEmail:)` для CloudKit восстановления
- Новый LAContext для каждой попытки биометрии
- Флаг `requiresReauth` после logout
- Keychain сохраняется для Face ID

**UX улучшения:**
- "Fish & Chips" вместо "PokerTracker"
- Email клавиатура при входе
- Номер сборки в профиле
- Debug доступен в TestFlight

**Отладка:**
- Подробные логи: [AUTH STATUS], [LOGIN], [REGISTER], [BIOMETRIC], [LOGOUT]
- Все ключевые точки auth flow логируются
- Email, userId, username видны в логах

### Тестирование в TestFlight

**Новые области для тестирования:**
1. ✅ Вход по email вместо username
2. ✅ Face ID работает после logout
3. ✅ Регистрация с обязательным email
4. ✅ Номер сборки отображается в профиле
5. ✅ Debug view доступен

**Проверить логи в Xcode Console при:**
- Запуске приложения
- Входе по email
- Выходе и повторном входе по Face ID
- Регистрации нового пользователя

---

## Следующие этапы (после TestFlight)

**Этап 2: Тестирование в TestFlight**

**План находится здесь:** `~/.cursor/plans/тестирование_в_testflight_0d34a08e.plan.md`

**Цель:** Протестировать приложение на реальных устройствах, проверить работу CloudKit синхронизации между устройствами, оффлайн режим, push-уведомления и выявить критические баги перед релизом в App Store.

### Подготовка к тестированию

**Требования:**
- Минимум 2 физических iOS устройства (iPhone/iPad)
- Оба устройства залогинены под разные iCloud аккаунты
- Стабильное интернет-соединение (Wi-Fi)
- Возможность отключать интернет для оффлайн тестов

### Блоки тестирования

**Блок 1: Базовая функциональность**
- Регистрация (с обязательным email и username) ⭐ ОБНОВЛЕНО
- Авторизация по email + пароль ⭐ ОБНОВЛЕНО
- Face ID / Touch ID после logout ⭐ ОБНОВЛЕНО
- Создание игр и добавление игроков
- Профили игроков и заявки (claims)
- Номер сборки в профиле ⭐ НОВОЕ
- Debug view в TestFlight ⭐ НОВОЕ
- Статистика и отчёты

**Блок 2: CloudKit синхронизация (критически важно!)**
- Синхронизация создания игры между устройствами
- Синхронизация обновления игры
- Синхронизация удаления
- Синхронизация заявок на игроков (PlayerClaim)
- Конфликты синхронизации (одновременные изменения)

**Блок 3: Оффлайн режим**
- Работа без интернета
- Создание игр оффлайн
- Восстановление синхронизации после переподключения
- Чтение данных из локального кэша

**Блок 4: Push уведомления**
- Подписка на уведомления
- Уведомления о новых играх
- Уведомления об изменениях
- Фоновое обновление (background fetch)

**Блок 5: Специфичные фичи приложения**
- Poker Odds Calculator
- Распознавание карт (Card Recognition)
- Импорт/экспорт данных
- Deep Links

**Блок 6: Граничные случаи и баги**
- Большой объём данных (50+ игр, 20+ игроков)
- Некорректные данные (валидация)
- Одновременные операции
- Лимиты и ограничения
- Проверка утечек памяти

**Блок 7: Сбор обратной связи**
- TestFlight Feedback от тестеров
- Автоматическое логирование ошибок
- Мониторинг CloudKit Dashboard

**Блок 8: Регрессионное тестирование**
- Обновление билда (миграция данных)
- Чистая установка (восстановление из CloudKit)

### Критерии успешного тестирования

**Must-Have (блокеры релиза):**
- ✅ CloudKit синхронизация работает стабильно
- ✅ Нет критических крашей
- ✅ Регистрация и авторизация работают
- ✅ Создание и редактирование игр без багов
- ✅ Оффлайн режим функционален
- ✅ Push-уведомления приходят

**Should-Have (желательно исправить):**
- ✅ UI/UX глитчи минимальны
- ✅ Производительность приемлемая
- ✅ Конфликты синхронизации обрабатываются
- ✅ Валидация данных работает корректно

### Чек-лист завершения тестирования

**Базовые проверки:**
- [ ] Протестированы все блоки 1-8
- [ ] Найденные критические баги исправлены
- [ ] Минимум 7 дней активного использования
- [ ] Протестировано на 3+ разных устройствах

**Новые фичи (Build 3):**
- [x] Вход по email работает корректно
- [x] Регистрация требует email и username
- [x] Face ID работает после logout
- [x] Face ID можно вызвать повторно при неудаче
- [x] Номер сборки отображается в профиле
- [x] Debug view доступен в TestFlight
- [x] Логи видны в Xcode Console

**Синхронизация и производительность:**
- [ ] CloudKit синхронизация стабильна (> 95% успешных запросов)
- [ ] Push-уведомления работают на всех устройствах
- [ ] Нет потери данных в стресс-тестах
- [ ] Оффлайн режим функционален
- [ ] Memory leaks отсутствуют
- [ ] Производительность приемлемая (app launch < 3s)

**Обратная связь:**
- [ ] Собрана обратная связь от тестеров
- [ ] Документированы известные не критические баги

**Документация для тестирования:**
- 📋 Вся информация в этом файле (MASTER_PLAN.md)
- 📋 Дополнительные планы в `~/.cursor/plans/` (если создавались)

**Этап 3: Исправление багов (создать отдельный план)**
- Приоритизация найденных проблем
- Исправление критических багов
- Загрузка обновленных билдов
- Повторное тестирование

**Этап 4: Production Release (создать отдельный план)**
- Финальная проверка
- Подготовка метаданных App Store
- Submit на App Review
- Релиз в App Store

---

## Структура проекта

```
gamesCheck/
├── docs/
│   ├── MASTER_PLAN.md (этот файл)
│   ├── CLOUDKIT_MANUAL_SETUP_REQUIRED.md
│   ├── TESTFLIGHT_DEPLOYMENT_GUIDE.md
│   ├── TECHNICAL_SPEC.md
│   ├── POKER_ODDS_*.md (документация фичи Poker Odds)
│   └── tasks/ (задачи по фазам)
├── FishAndChips/ (код приложения)
│   ├── Services/
│   │   ├── CloudKitService.swift
│   │   ├── CloudKitSyncService.swift
│   │   ├── NotificationService.swift
│   │   └── KeychainService.swift
│   └── Repository/
│       └── Repository.swift
└── ~/.cursor/plans/
    └── testflight_deployment_plan_81a25c38.plan.md
```

---

## Важные ссылки

### Для разработки
- [Apple Developer Portal](https://developer.apple.com/account)
- [App Store Connect](https://appstoreconnect.apple.com)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [TestFlight](https://testflight.apple.com)

### Документация Apple
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [TestFlight Guide](https://developer.apple.com/testflight/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

---

## Контрольный чеклист для агента

Перед началом работы проверьте:
- [ ] Прочитал актуальный план из `~/.cursor/plans/`
- [ ] Знаю текущий статус todos
- [ ] Понимаю, какую задачу выполняю
- [ ] ⛔ **КРИТИЧНО:** НЕ буду создавать новые MD файлы без ЯВНОГО разрешения пользователя
- [ ] Если нужен новый файл - СПРОШУ пользователя: "Создать файл X.md?"
- [ ] Буду обновлять существующие файлы вместо создания новых
- [ ] Буду обновлять статус todos по мере работы
- [ ] После завершения задачи отмечу её как `completed`

**⚠️ НАПОМИНАНИЕ:** Создание MD файлов без разрешения = критическая ошибка!

---

**Этот файл - единая точка входа для всех агентов. Следуйте ему!**
