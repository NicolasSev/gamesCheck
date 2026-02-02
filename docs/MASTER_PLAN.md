# Мастер-план проекта gamesCheck

> **Единый источник правды для всех агентов, работающих над проектом**

**История обновлений:**
- 2026-02-02: Pre-TestFlight улучшения - ребрендинг на Fish & Chips, вход по email, номер сборки в профиле
- 2026-01-31 11:30: Добавлен детальный план исправления критического бага синхронизации CloudKit
- 2026-01-31 11:30: Добавлен раздел "Будущие оптимизации" - On-Demand Game Loading
- 2026-01-30: Добавлен детальный план Этапа 2 - Тестирование в TestFlight
- 2026-01-30: Добавлено КРИТИЧЕСКОЕ правило - создание MD файлов только с явного разрешения пользователя
- 2026-01-29: Очистка устаревшей документации выполнена

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
- 🔄 Pre-TestFlight улучшения (в процессе - см. раздел ниже)

**Статус:** Внесение финальных улучшений перед следующей сборкой в TestFlight

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

**Фаза 2: Incremental Sync (оптимизация)**

**Задача 2.1:** Использовать CKServerChangeToken
- Сохранять токен последней синхронизации
- При следующем fetch загружать только изменения (delta sync)
- Это экономит трафик и время загрузки

**Задача 2.2:** Реализовать фоновую синхронизацию
- Background Fetch (периодическая синхронизация)
- Push-триггерная синхронизация (при получении silent push)

**Фаза 3: Обработка Deep Links**

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

## 🎯 Pre-TestFlight улучшения (2026-02-02)

**Статус:** В процессе выполнения

**Контекст:** Игры и пользователи успешно загружены в development CloudKit database. Перед загрузкой следующей сборки в App Store Connect и TestFlight необходимо внести финальные улучшения UX и функциональности.

### Список улучшений

1. **Ребрендинг на "Fish & Chips"**
   - Сейчас: на странице логина отображается "PokerTracker"
   - Нужно: изменить на "Fish & Chips"

2. **Вход по email и паролю**
   - Сейчас: вход по username + пароль
   - Нужно: вход по email + пароль
   - Username остается для отображения в профиле и общении между пользователями

3. **Уникальность полей при регистрации**
   - Email = логин (уникальный идентификатор для входа)
   - Username = отображаемое имя (уникальное, для профиля и чатов)
   - Оба поля обязательны и должны быть уникальными

4. **Номер сборки в профиле**
   - Добавить версию и build number в верхней части профиля
   - Формат: "Версия 1.0 (2)"

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
- Регистрация и авторизация
- Создание игр и добавление игроков
- Профили игроков и заявки (claims)
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

- [ ] Протестированы все блоки 1-8
- [ ] Найденные критические баги исправлены
- [ ] Минимум 7 дней активного использования
- [ ] Протестировано на 3+ разных устройствах
- [ ] CloudKit синхронизация стабильна (> 95% успешных запросов)
- [ ] Push-уведомления работают на всех устройствах
- [ ] Нет потери данных в стресс-тестах
- [ ] Оффлайн режим функционален
- [ ] Собрана обратная связь от тестеров
- [ ] Документированы известные не критические баги
- [ ] Memory leaks отсутствуют
- [ ] Производительность приемлемая (app launch < 3s)

**Документация для тестирования:**
- 📋 `~/.cursor/plans/тестирование_в_testflight_0d34a08e.plan.md` - детальный план
- 📝 `docs/TESTING_README.md` - руководство для тестировщиков
- ✅ `docs/TESTING_CHECKLIST.md` - быстрый чек-лист
- 🎯 `docs/TEST_SCENARIOS.md` - 13 тестовых сценариев
- 🐛 `docs/BUG_REPORT_TEMPLATE.md` - шаблон багрепорта

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
