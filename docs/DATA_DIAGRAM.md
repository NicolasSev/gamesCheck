# Диаграмма данных — Fish & Chips

**Обновление:** 2026-02-22 | v2.1

---

## Core Data ER

```mermaid
erDiagram
    User ||--o| PlayerProfile : has
    User ||--o{ Game : creates
    PlayerProfile ||--o{ PlayerAlias : has
    PlayerProfile ||--o{ GameWithPlayer : participates
    Game ||--o{ GameWithPlayer : has
    Game ||--o{ Player : "legacy"
    Player ||--o{ GameWithPlayer : maps
    User ||--o{ PlayerClaim : submits/receives
```

**Ключи:** User.userId | PlayerProfile.profileId | Game.gameId | PlayerClaim.claimId  
**Использовать UUID**, не objectID.

---

## CloudKit Schema (все в Public DB)

| Entity | Назначение |
|--------|------------|
| User, Game, GameWithPlayer, PlayerAlias | Основные |
| PlayerProfile, PlayerClaim | Cross-user |
| UserStatisticsSummary, GameSummaryRecord, UserGameIndex | Витрины (Phase 2–3) |
| AppNotification | Только Core Data (локально) |

---

## Витрины (Materialized Views)

| Entity | Обновление |
|--------|------------|
| GameSummaryRecord | checksum для smartSync |
| UserStatisticsSummary | При импорте, approve |
| UserGameIndex | При создании GWP |

**Smart Sync:** fetchSummariesOnly → compareSummariesWithLocal → при различиях performBackgroundSync → rebuildAllGameSummaries.

---

## Порядок синхронизации

1. PlayerProfile 2. Game 3. PlayerAlias 4. GameWithPlayer 5. PlayerClaim  
Порядок критичен: профили до алиасов и GWP.

---

## Защита данных

- CloudKit = Source of Truth: локальное удаляется, если нет в CloudKit
- Pending: PendingSyncTracker — не удалять при pull
- playerProfile: если CloudKit вернул nil, но локально есть — не затирать

---

## Deletion Rules

- PlayerProfile.aliases → Cascade
- PlayerProfile.gameParticipations → Nullify
- Game.gameWithPlayers → Nullify
- User.playerProfile → Nullify

---

## Примечания

- PlayerProfile в Public DB: cross-user заявки, GWP → profile reference
- Пагинация: CloudKit limit 400, fetchAllRecords с Cursor для GWP
