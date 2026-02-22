# Диаграмма данных - Fish & Chips (gamesCheck)

**Последнее обновление:** 2026-02-11

---

## 📊 Схема базы данных (Core Data)

### Основные сущности и их связи

```mermaid
erDiagram
    User ||--o| PlayerProfile : "has"
    User ||--o{ Game : "creates"
    
    PlayerProfile ||--o{ PlayerAlias : "has"
    PlayerProfile ||--o{ GameWithPlayer : "participates in"
    
    Game ||--o{ GameWithPlayer : "has"
    Game ||--o{ Player : "has (legacy)"
    Game ||--o{ PlayerClaim : "has claims for"
    
    Player ||--o{ GameWithPlayer : "maps to"
    
    User ||--o{ PlayerClaim : "submits as claimant"
    User ||--o{ PlayerClaim : "receives as host"
    User ||--o{ PlayerClaim : "resolves"
    
    User {
        UUID userId PK
        string username
        string email
        string passwordHash
        date createdAt
        date lastLoginAt
        bool isSuperAdmin
        string subscriptionStatus
        date subscriptionExpiresAt
    }
    
    PlayerProfile {
        UUID profileId PK
        UUID userId FK
        string displayName
        bool isAnonymous
        bool isPublic
        date createdAt
        int32 totalGamesPlayed
        decimal totalBuyins
        decimal totalCashouts
    }
    
    PlayerAlias {
        UUID aliasId PK
        UUID profileId FK
        string aliasName
        date claimedAt
        int32 gamesCount
    }
    
    Game {
        UUID gameId PK
        UUID creatorUserId FK
        string gameType
        date timestamp
        bool isPublic
        bool softDeleted
        string notes
    }
    
    Player {
        string name
        int16 buyin
    }
    
    GameWithPlayer {
        Game game FK
        Player player FK
        PlayerProfile playerProfile FK
        int16 buyin
        int64 cashout
    }
    
    PlayerClaim {
        UUID claimId PK
        UUID gameId FK
        string playerName
        string gameWithPlayerObjectId
        UUID claimantUserId FK
        UUID hostUserId FK
        UUID resolvedByUserId FK
        string status
        date createdAt
        date resolvedAt
        string notes
    }
```

---

## ☁️ CloudKit Database Schema

### Public Database (доступна всем пользователям)

```mermaid
graph TD
    subgraph "CloudKit Public DB"
        User_CK[User Record]
        Game_CK[Game Record]
        GWP_CK[GameWithPlayer Record]
        Alias_CK[PlayerAlias Record]
        Claim_CK[PlayerClaim Record]
        Profile_CK[PlayerProfile Record]
        Stats_CK[UserStatisticsSummary]
        Summary_CK[GameSummaryRecord]
        Index_CK[UserGameIndex]
        
        User_CK -->|creatorUserId| Game_CK
        Game_CK -->|game reference| GWP_CK
        GWP_CK -->|playerProfile reference| Profile_CK
        Alias_CK -->|profile reference| Profile_CK
        Claim_CK -->|gameId| Game_CK
        Claim_CK -->|claimantUserId| User_CK
        Claim_CK -->|hostUserId| User_CK
        Profile_CK -->|userId reference| User_CK
        Stats_CK -->|userId| User_CK
        Summary_CK -->|gameId| Game_CK
        Index_CK -->|gameId| Game_CK
    end
    
    style Profile_CK fill:#9f9,stroke:#333,stroke-width:2px
    style Stats_CK fill:#9cf,stroke:#333,stroke-width:1px
    style Summary_CK fill:#9cf,stroke:#333,stroke-width:1px
    style Index_CK fill:#9cf,stroke:#333,stroke-width:1px
```

### Какие данные в какой базе

| Entity | CloudKit Database | Почему |
|--------|------------------|--------|
| **User** | Public DB | Нужна проверка уникальности email при регистрации |
| **PlayerProfile** | Public DB | Нужна cross-user видимость для системы заявок и привязки GWP |
| **PlayerAlias** | Public DB | Нужна видимость для cross-user claims |
| **Game** | Public DB | Публичные игры, доступные по deep link |
| **GameWithPlayer** | Public DB | Нужна видимость игроков в играх |
| **PlayerClaim** | Public DB | Межпользовательские заявки |
| **UserStatisticsSummary** | Public DB | Предрассчитанная статистика пользователя |
| **GameSummaryRecord** | Public DB | Сводка по игре (для быстрой загрузки без GWP) |
| **UserGameIndex** | Public DB | Индекс участие пользователя в играх |
| **AppNotification** | Core Data only (локально) | История push-уведомлений для экрана «Уведомления» |

---

## 📦 Materialized Views (Фаза 2, v2.0)

Предрассчитанные витрины для ускорения загрузки:

| Entity | Назначение | Обновление |
|--------|------------|------------|
| **UserStatisticsSummary** | Статистика пользователя (totalGamesPlayed, balance, winRate) | При импорте, одобрении заявки |
| **GameSummaryRecord** | Сводка по игре (totalPlayers, totalBuyins, timestamp, checksum) | При создании игры, добавлении игроков |
| **UserGameIndex** | Индекс userId → gameId для быстрого поиска | При создании GWP |

Используются в **smartSync()** (Phase 3) для показа UI за &lt; 2 сек.

**GameSummaryRecord.checksum** — хеш для быстрого сравнения (gameId_timestamp_totalPlayers_totalBuyins). Используется в compareSummariesWithLocal() для определения необходимости полной синхронизации.

### Smart Sync (Phase 3) — двухфазный flow

```mermaid
flowchart TD
    A[App Launch] --> B[Phase 1: performMinimalSync]
    B --> C[UI Ready]
    C --> D[Phase 2 Background: fetchSummariesOnly]
    D --> E{compareSummariesWithLocal}
    E -->|Совпадают| F[Done]
    E -->|Различаются| G[performBackgroundSync]
    G --> H[rebuildAllGameSummaries]
    H --> I[Notification: syncCompletedSuccessfully]
```

---

## 🔄 Поток данных при синхронизации

```mermaid
sequenceDiagram
    participant App as Local App (Core Data)
    participant CK as CloudKit
    
    Note over App,CK: Синхронизация (PULL)
    
    App->>CK: 1. fetchPlayerProfiles() [Private DB]
    CK-->>App: PlayerProfile records
    App->>App: mergePlayerProfilesWithLocal()
    
    App->>CK: 2. fetchPublicGames() [Public DB]
    CK-->>App: Game records
    App->>App: mergeGamesWithLocal()
    
    App->>CK: 3. fetchPublicPlayerAliases() [Public DB]
    CK-->>App: PlayerAlias records
    App->>App: mergePlayerAliasesWithLocal()
    Note over App: Проверка: profile найден?
    
    App->>CK: 4. fetchPublicGameWithPlayers() [Public DB]
    CK-->>App: GameWithPlayer records
    App->>App: mergeGameWithPlayersWithLocal()
    Note over App: Защита: не затираем локальный profile
    
    App->>CK: 5. fetchPlayerClaims() [Public DB]
    CK-->>App: PlayerClaim records
    App->>App: mergePlayerClaimsWithLocal()
    
    Note over App,CK: Порядок критичен! Profiles → Games → Aliases → GWP → Claims
```

### Двухфазная загрузка (Фаза 2)

```mermaid
sequenceDiagram
    participant App as App
    participant Phase1 as performMinimalSync
    participant Phase2 as performBackgroundSync
    
    App->>Phase1: Запуск (splash screen)
    Phase1->>Phase1: fetchMyPlayerProfile
    Phase1->>Phase1: fetchRecentGames(20)
    Phase1->>Phase1: fetchPendingClaimsCount
    Phase1->>Phase1: fetchUserStatisticsSummary (если есть)
    Phase1-->>App: ✅ UI готов (< 3 сек)
    
    par Фон
        Phase2->>Phase2: fetchPublicGames (все)
        Phase2->>Phase2: fetchPublicPlayerProfiles
        Phase2->>Phase2: fetchPublicPlayerAliases
        Phase2->>Phase2: fetchPlayerClaims
        Note over Phase2: GameWithPlayer НЕ загружаются — lazy load при открытии игры
    end
```

---

## 🎯 Ключевые бизнес-процессы

### 1. Импорт игр хостом

```mermaid
flowchart TD
    A[Хост импортирует CSV] --> B[Парсинг данных]
    B --> C{Для каждого игрока}
    C --> D[Хост выбирает себя?]
    D -->|Да| E[Создать/найти PlayerProfile хоста]
    D -->|Нет| F[playerProfile = nil]
    E --> G[Создать GameWithPlayer]
    F --> G
    G --> H[Создать Game]
    H --> I[Сохранить в Core Data]
    I --> J[quickSyncGame в CloudKit]
    J --> K{Синхронизация успешна?}
    K -->|Да| L[Готово ✅]
    K -->|Нет| M[PendingSyncTracker.addPendingGame]
    M --> N[Retry позже]
```

### 2. Подача заявки (Deep Link)

```mermaid
flowchart TD
    A[Acc2 открывает deep link] --> B[fetchPublicGames для gameId]
    B --> C[mergeGamesWithLocal]
    C --> D[Скачать Game + все GameWithPlayer]
    D --> E{playerProfile в GWP?}
    E -->|nil| F[Отобразить как unclaimed]
    E -->|есть| G[Отобразить с профилем]
    F --> H[Acc2 подаёт заявку на игрока]
    H --> I[Создать PlayerClaim локально]
    I --> J[syncPlayerClaims в CloudKit]
    J --> K[Хост получает заявку]
```

### 3. Подтверждение заявки

```mermaid
flowchart TD
    A[Хост видит PlayerClaim] --> B[approveClaim]
    B --> C{PlayerProfile для клаиманта существует?}
    C -->|Нет| D[Создать PlayerProfile]
    C -->|Да| E[Использовать существующий]
    D --> F[Создать PlayerAlias]
    E --> F
    F --> G[Привязать GameWithPlayer к профилю]
    G --> H[Обновить статистику profile.recalculateStatistics]
    H --> I[Обновить claim.status = approved]
    I --> J[Сохранить в Core Data]
    J --> K[Sync в CloudKit:]
    K --> L[1. syncPlayerClaims]
    K --> M[2. quickSyncGameWithPlayers]
    K --> N[3. quickSyncPlayerProfile]
    K --> O[4. syncPlayerAliases]
    O --> P[Клаимант синхронизирует]
    P --> Q[Статистика клаиманта обновляется ✅]
```

---

## 🛡️ Защита данных (Source of Truth)

### CloudKit = Source of Truth

При синхронизации (PULL):

```mermaid
flowchart TD
    A[Fetch данные из CloudKit] --> B{Данные есть в CloudKit?}
    B -->|Да| C[Собрать cloudIds Set]
    B -->|Нет| D[Удалить ВСЕ локальные записи кроме pending]
    C --> E{Для каждой локальной записи}
    E --> F{ID есть в cloudIds?}
    F -->|Да| G[Обновить из CloudKit]
    F -->|Нет| H{Запись pending?}
    H -->|Да| I[Оставить не удалять]
    H -->|Нет| J[Удалить локальную запись]
    
    G --> K{Особый случай: playerProfile}
    K --> L{CloudKit вернул nil?}
    L -->|Да, но локально есть| M[ЗАЩИТА: Оставить локальный]
    L -->|Нет, есть профиль| N[Обновить профиль]
    L -->|Да и локально nil| O[Оставить nil]
```

### Pending Data Tracker

```mermaid
flowchart LR
    A[Создание данных] --> B[Сохранить локально]
    B --> C[Попытка PUSH в CloudKit]
    C --> D{Успешно?}
    D -->|Да| E[Готово ✅]
    D -->|Нет| F[PendingSyncTracker.add...]
    F --> G[Данные помечены как pending]
    G --> H[При следующем PULL не удаляются]
    H --> I[Пользователь видит в ProfileView]
    I --> J[Кнопка Запушить незалитые данные]
    J --> K[pushPendingData]
    K --> L{Успешно?}
    L -->|Да| M[PendingSyncTracker.remove...]
    L -->|Нет| N[Остаются pending]
```

---

## 📈 Расчёт статистики

```mermaid
flowchart TD
    A[PlayerProfile.recalculateStatistics] --> B[Получить все GameWithPlayer]
    B --> C{Для каждого GWP}
    C --> D{GWP.playerProfile == этот профиль?}
    D -->|Да| E[Добавить buyin и cashout]
    D -->|Нет| F[Пропустить]
    E --> G[totalGamesPlayed++]
    F --> C
    G --> C
    C --> H[Итого:]
    H --> I[totalBuyins = sum all buyins]
    H --> J[totalCashouts = sum all cashouts]
    I --> K[balance = totalCashouts - totalBuyins]
    J --> K
```

**Важно:** Только `GameWithPlayer` с привязанным `playerProfile` учитываются в статистике!

---

## 🔑 Ключевые идентификаторы

| Entity | Primary Key | Используется для |
|--------|-------------|------------------|
| User | `userId` (UUID) | Привязка к профилю, авторизация |
| PlayerProfile | `profileId` (UUID) | Уникальный идентификатор профиля |
| PlayerAlias | `aliasId` (UUID) | Уникальный идентификатор алиаса |
| Game | `gameId` (UUID) | Deep links, синхронизация |
| GameWithPlayer | `(gameId, playerName)` | Composite key для поиска |
| PlayerClaim | `claimId` (UUID) | Уникальный идентификатор заявки |

### Stable Identifiers (не используем!)

❌ **НЕ использовать** `objectID` из Core Data - нестабильный после перезапуска
✅ **Использовать** `UUID` поля для стабильных ссылок

---

## 🔄 Relationships (Core Data)

### Inverse Relationships

```
User.playerProfile ←→ PlayerProfile.user
User.createdGames ←→ Game.creator

PlayerProfile.aliases ←→ PlayerAlias.profile
PlayerProfile.gameParticipations ←→ GameWithPlayer.playerProfile

Game.gameWithPlayers ←→ GameWithPlayer.game
Player.gameWithPlayers ←→ GameWithPlayer.player

Game.players ←→ Player.game (legacy, для обратной совместимости)
```

### Deletion Rules

| Relationship | Deletion Rule | Причина |
|-------------|---------------|---------|
| `PlayerProfile.aliases` | Cascade | При удалении профиля удаляются все алиасы |
| `PlayerProfile.gameParticipations` | Nullify | При удалении профиля GWP остаются, но без профиля |
| `Game.gameWithPlayers` | Nullify | При удалении игры GWP не удаляются (мягкое удаление) |
| `User.playerProfile` | Nullify | При удалении юзера профиль остаётся |

---

## 🎨 Цветовая легенда (для диаграмм)

- 🟦 **Core Data** - локальное хранилище
- 🟪 **CloudKit Private DB** - приватные данные пользователя
- 🟩 **CloudKit Public DB** - публичные/shared данные
- 🟨 **Pending** - данные ожидают синхронизации
- 🟥 **Защита** - критичная логика, не затирать

---

## 📝 Примечания

### Почему PlayerProfile в Public DB?

- Нужна cross-user видимость для системы заявок
- Когда хост подтверждает заявку, создаётся профиль для клаиманта
- GameWithPlayer ссылается на профиль через CKRecord.Reference
- Клаимант должен увидеть свой профиль и статистику после синхронизации
- Статистика считается по GameWithPlayer, привязанным к профилю

**ВАЖНО:** Раньше был в Private DB, но это блокировало cross-user функциональность!

### Почему PlayerAlias в Public DB?

- Нужна видимость для системы заявок
- Хост должен видеть алиасы клаиманта
- Позволяет подтверждать заявки cross-user

### Порядок синхронизации критичен!

1. **PlayerProfile** - должны быть скачаны первыми
2. **Game** - основа для всех связей
3. **PlayerAlias** - требуют наличия профилей
4. **GameWithPlayer** - требуют наличия игр и профилей
5. **PlayerClaim** - требуют наличия игр и юзеров

Если скачать в неправильном порядке → ошибки валидации Core Data!

### Пагинация при больших объемах данных

**Проблема:** CloudKit limit = 400 records per request

**Решение:** `CloudKitService.fetchAllRecords()` с автоматической пагинацией:
- Использует `CKQueryOperation.Cursor` для продолжения запросов
- Автоматически подгружает все батчи (по 400 записей)
- Защита от бесконечного цикла (max 50 батчей = 20,000 записей)
- Детальное логирование каждого батча

**Применяется для:**
- `GameWithPlayer` - может быть 500+ записей при импорте больших игр
- Все остальные entity используют стандартный fetch (< 400 записей)

**Критично:**
- При обычном fetch: если ровно 400 записей → WARNING о лимите
- С пагинацией: автоматически подгружаются ВСЕ записи
- "Source of Truth" deletion безопасен только при полной пагинации

---

**Версия:** 2.1  
**Дата:** 2026-02-22  
**Изменения:**
- v2.1 (2026-02-22): GameSummaryRecord.checksum; smartSync(); AppNotification (Core Data); CloudKit CKSubscription для Game; экран Уведомления
- v2.0 (2026-02-11): Materialized Views — UserStatisticsSummary, GameSummaryRecord, UserGameIndex; двухфазная загрузка (minimal → background); lazy loading GameWithPlayer
- v1.2 (2026-02-07 00:15): Добавлена пагинация CloudKit для GameWithPlayer (fetchAllRecords с CKQueryOperation.Cursor)
- v1.1 (2026-02-07 23:00): PlayerProfile мигрирован из Private DB в Public DB для cross-user видимости
- v1.0 (2026-02-07 19:15): Первая версия диаграммы

**Автор:** AI Agent (Claude Sonnet 4.5)
