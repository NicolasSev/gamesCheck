# CloudKit Schema Verification Checklist

## ✅ Что должно быть создано (проверьте в Dashboard)

### Record Types (5 штук)

#### 1. User (должно быть ~14 fields включая system fields)
**Ваши поля (8):**
- [ ] username (String)
- [ ] email (String)
- [ ] passwordHash (String)
- [ ] subscriptionStatus (String)
- [ ] isSuperAdmin (Int64)
- [ ] createdAt (Date/Time)
- [ ] lastLoginAt (Date/Time)
- [ ] subscriptionExpiresAt (Date/Time)

**System fields (~6):** createdTimestamp, modifiedTimestamp, recordName, и т.д.

#### 2. Game (должно быть ~12 fields)
**Ваши поля (6):**
- [ ] gameType (String)
- [ ] timestamp (Date/Time)
- [ ] isPublic (Int64)
- [ ] softDeleted (Int64)
- [ ] notes (String)
- [ ] creator (Reference) ← может показывать просто "REFERENCE"

#### 3. PlayerProfile (должно быть ~13 fields)
**Ваши поля (7):**
- [ ] displayName (String)
- [ ] isAnonymous (Int64)
- [ ] createdAt (Date/Time)
- [ ] totalGamesPlayed (Int64)
- [ ] totalBuyins (Double)
- [ ] totalCashouts (Double)
- [ ] user (Reference)

#### 4. PlayerAlias (должно быть ~10 fields)
**Ваши поля (4):**
- [ ] aliasName (String)
- [ ] claimedAt (Date/Time)
- [ ] gamesCount (Int64)
- [ ] profile (Reference)

#### 5. PlayerClaim (должно быть ~16 fields)
**Ваши поля (10):**
- [ ] playerName (String)
- [ ] gameWithPlayerObjectId (String)
- [ ] status (String)
- [ ] createdAt (Date/Time)
- [ ] resolvedAt (Date/Time)
- [ ] notes (String)
- [ ] game (Reference)
- [ ] claimantUser (Reference)
- [ ] hostUser (Reference)
- [ ] resolvedByUser (Reference)

---

## ✅ Indexes (создавайте через Indexes раздел)

### User Indexes
- [ ] username - QUERYABLE
- [ ] username - SORTABLE
- [ ] email - QUERYABLE

### Game Indexes
- [ ] timestamp - QUERYABLE

### PlayerProfile Indexes
- [ ] displayName - QUERYABLE

### PlayerAlias Indexes
- [ ] aliasName - QUERYABLE

### PlayerClaim Indexes
- [ ] playerName - QUERYABLE
- [ ] status - QUERYABLE
- [ ] createdAt - QUERYABLE

---

## ⚠️ Про Reference поля

**НЕ БЕСПОКОЙТЕСЬ**, если в Dashboard референсы показывают просто "REFERENCE" без указания целевого типа!

Ваш код в `CloudKitModels.swift` уже правильно настраивает типы:
- ✅ Game.creator → User
- ✅ PlayerProfile.user → User
- ✅ PlayerAlias.profile → PlayerProfile
- ✅ PlayerClaim.game → Game
- ✅ PlayerClaim.claimantUser → User
- ✅ PlayerClaim.hostUser → User
- ✅ PlayerClaim.resolvedByUser → User

Типы определяются **programmatically** при создании записей, а не в схеме.

---

## Следующие шаги

После проверки этого чеклиста:

1. ✅ Убедитесь, что все Record Types созданы
2. ✅ Создайте все Indexes
3. ✅ В режиме Development всё готово
4. ⏭️ **НЕ DEPLOY в Production пока!**
5. ⏭️ Сначала протестируйте (Step 7 в `CLOUDKIT_MANUAL_SETUP_REQUIRED.md`)

---

## Тестирование

Запустите приложение и проверьте консоль:

```
☁️ CloudKit Status: Optional(CloudKit.CKAccountStatus.available)
```

Если статус `available` - всё работает!

---

## Если хотите явно указать типы Reference в схеме

Это опционально, но если хотите:

1. Удалите все Reference поля из всех Record Types
2. Переключитесь в Development режим в CloudKit Dashboard
3. Используйте автоматический метод создания схемы:
   - Запустите приложение с кодом `CloudKitSchemaCreator`
   - Схема создастся с правильными типами
   - Потом добавьте индексы
   - Deploy в Production

**НО ЭТО НЕ ОБЯЗАТЕЛЬНО!** Текущая схема будет работать.
