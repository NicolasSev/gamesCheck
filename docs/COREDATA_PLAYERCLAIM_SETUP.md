# Инструкция: Добавление PlayerClaim в CoreData модель

Перед использованием PlayerClaimService нужно добавить entity в CoreData модель.

## Шаги в Xcode:

1. Откройте `PokerCardRecognizer.xcdatamodeld` в Xcode
2. Нажмите **+** внизу для добавления новой Entity
3. Назовите entity: **PlayerClaim**
4. Установите **Codegen:** Manual/None (чтобы использовать наши файлы)

## Атрибуты:

Добавьте следующие атрибуты:

| Имя | Тип | Optional | Default |
|-----|-----|----------|---------|
| claimId | UUID | NO | - |
| playerName | String | NO | - |
| gameId | UUID | NO | - |
| gameWithPlayerObjectId | String | NO | - |
| claimantUserId | UUID | NO | - |
| hostUserId | UUID | NO | - |
| status | String | NO | "pending" |
| createdAt | Date | NO | current |
| resolvedAt | Date | YES | - |
| resolvedByUserId | UUID | YES | - |
| notes | String | YES | - |

## Relationships:

| Имя | Destination | Type | Inverse | Delete Rule |
|-----|-------------|------|---------|-------------|
| claimantUser | User | To One | - | Nullify |
| hostUser | User | To One | - | Nullify |
| resolvedByUser | User | To One | - | Nullify |
| game | Game | To One | - | Nullify |

## После добавления:

1. Сохраните модель (Cmd+S)
2. Проект должен скомпилироваться без ошибок
3. Запустите приложение - CoreData автоматически мигрирует схему

## Проверка:

Убедитесь что файлы созданы:
- `PlayerClaim+CoreDataClass.swift` ✅
- `PlayerClaim+CoreDataProperties.swift` ✅

Если Xcode предложит перегенерировать - откажите, используем наши файлы.

