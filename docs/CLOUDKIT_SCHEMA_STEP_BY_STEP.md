# CloudKit Schema - Пошаговая инструкция

## Быстрое создание Record Types

Вы сейчас находитесь в CloudKit Dashboard → Schema → Record Types.

## ⚠️ ВАЖНО: Порядок создания

1. **Сначала** создайте все Record Types с простыми полями (String, Int, Date)
2. **Потом** добавьте индексы через "Indexes"
3. **В конце** добавьте Reference поля (они требуют, чтобы целевые типы уже существовали)

---

### Шаг 1: Создание Record Type "User"

1. Нажмите **"+"** возле "Record Types"
2. Введите имя: **User**
3. Нажмите кнопку **"Add Field"** 8 раз и заполните:

| Field Name | Type |
|-----------|------|
| username | String |
| email | String |
| passwordHash | String |
| subscriptionStatus | String |
| isSuperAdmin | Int(64) |
| createdAt | Date/Time |
| lastLoginAt | Date/Time |
| subscriptionExpiresAt | Date/Time |

4. Нажмите **"Save"**

5. **Создайте индексы** для Record Type "User":
   - Перейдите в боковое меню → **Indexes**
   - Выберите Record Type: **User**
   - Нажмите **"+"** и создайте:

| Index Name | Type | Field |
|-----------|------|-------|
| username_queryable | QUERYABLE | username |
| username_sortable | SORTABLE | username |
| email_queryable | QUERYABLE | email |

---

### Шаг 2: Создание Record Type "Game"

1. Нажмите **"+"** возле "Record Types"
2. Введите имя: **Game**
3. Добавьте поля (пока БЕЗ `creator`):

| Field Name | Type |
|-----------|------|
| gameType | String |
| timestamp | Date/Time |
| isPublic | Int(64) |
| softDeleted | Int(64) |
| notes | String |

4. Нажмите **"Save"**

5. **Создайте индекс**:
   - Indexes → Record Type: **Game**
   - Создайте:

| Index Name | Type | Field |
|-----------|------|-------|
| timestamp_indexed | QUERYABLE | timestamp |

---

### Шаг 3: Создание Record Type "PlayerProfile"

1. Нажмите **"+"** возле "Record Types"
2. Введите имя: **PlayerProfile**
3. Добавьте поля (пока БЕЗ `user`):

| Field Name | Type |
|-----------|------|
| displayName | String |
| isAnonymous | Int(64) |
| createdAt | Date/Time |
| totalGamesPlayed | Int(64) |
| totalBuyins | Double |
| totalCashouts | Double |

4. Нажмите **"Save"**

5. **Создайте индекс**:

| Index Name | Type | Field |
|-----------|------|-------|
| displayName_queryable | QUERYABLE | displayName |

---

### Шаг 4: Создание Record Type "PlayerAlias"

1. Нажмите **"+"** возле "Record Types"
2. Введите имя: **PlayerAlias**
3. Добавьте поля (пока БЕЗ `profile`):

| Field Name | Type |
|-----------|------|
| aliasName | String |
| claimedAt | Date/Time |
| gamesCount | Int(64) |

4. Нажмите **"Save"**

5. **Создайте индекс**:

| Index Name | Type | Field |
|-----------|------|-------|
| aliasName_queryable | QUERYABLE | aliasName |

---

### Шаг 5: Создание Record Type "PlayerClaim"

1. Нажмите **"+"** возле "Record Types"
2. Введите имя: **PlayerClaim**
3. Добавьте поля (пока БЕЗ reference полей):

| Field Name | Type |
|-----------|------|
| playerName | String |
| gameWithPlayerObjectId | String |
| status | String |
| createdAt | Date/Time |
| resolvedAt | Date/Time |
| notes | String |

4. Нажмите **"Save"**

5. **Создайте индексы**:

| Index Name | Type | Field |
|-----------|------|-------|
| playerName_indexed | QUERYABLE | playerName |
| status_queryable | QUERYABLE | status |
| createdAt_indexed | QUERYABLE | createdAt |

---

### Шаг 6: Добавление Reference полей

Теперь, когда все Record Types созданы, вернитесь и добавьте Reference поля:

#### 6.1. Добавьте поле `creator` в Record Type "Game"

1. Откройте Record Type **"Game"** (кликните на него в списке)
2. Нажмите **"Add Field"**
3. Field Name: `creator`
4. Type: выберите **"Reference"** (или **"CKReference"**)

**Важно:** После выбора типа Reference:
- Если появилось дополнительное поле/dropdown - выберите там **User**
- Если dropdown не появился - попробуйте:
  - Кликнуть на созданное поле `creator` чтобы его отредактировать
  - Или в списке типов найти готовые варианты типа "Reference(User)"
  - Или выбрать тип "CKReference" вместо "Reference"

5. Убедитесь, что поле `creator` ссылается на тип **User**
6. Нажмите **"Save"**

**Альтернатива:** Если интерфейс не даёт настроить Reference:
- Сохраните поле как есть
- После деплоя схемы Reference поля можно будет настроить программно через код
- Или попробуйте метод автоматического создания схемы (см. секцию ниже)

#### 6.2. Добавьте поле `user` в Record Type "PlayerProfile"

1. Откройте Record Type **"PlayerProfile"**
2. Add Field → Name: `user`
3. Type: **Reference** → Выберите **User**
4. Save

#### 6.3. Добавьте поле `profile` в Record Type "PlayerAlias"

1. Откройте Record Type **"PlayerAlias"**
2. Add Field → Name: `profile`
3. Type: **Reference** → Выберите **PlayerProfile**
4. Save

#### 6.4. Добавьте Reference поля в Record Type "PlayerClaim"

1. Откройте Record Type **"PlayerClaim"**
2. Добавьте 4 Reference поля:

| Field Name | Reference Type |
|-----------|----------------|
| game | Game |
| claimantUser | User |
| hostUser | User |
| resolvedByUser | User |

Для каждого поля:
- Add Field → Name: (имя из таблицы)
- Type: **Reference** → Выберите (тип из таблицы)
- Save

---

## Проверка

После создания всех Record Types и добавления Reference полей, вы должны увидеть в списке:
- ✓ User (8 fields)
- ✓ Game (6 fields) - включая reference `creator`
- ✓ PlayerProfile (7 fields) - включая reference `user`
- ✓ PlayerAlias (4 fields) - включая reference `profile`
- ✓ PlayerClaim (10 fields) - включая 4 reference поля

---

## Альтернативный метод: Автоматическое создание (Development mode)

Если вы хотите использовать автоматическое создание схемы:

1. В CloudKit Dashboard переключитесь на **"Development"** environment (вверху страницы)

2. Добавьте этот код в `FishAndChipsApp.swift`:

```swift
.onAppear {
    #if DEBUG
    Task {
        do {
            try await CloudKitSchemaCreator().createDevelopmentSchema()
        } catch {
            print("❌ Schema creation failed: \(error)")
        }
    }
    #endif
}
```

3. Запустите приложение один раз

4. Вернитесь в CloudKit Dashboard → Development → Schema

5. Проверьте созданные Record Types

6. Добавьте индексы вручную (Queryable, Sortable)

7. **Deploy to Production**: нажмите кнопку "Deploy Schema Changes" чтобы перенести схему в Production

⚠️ **Важно**: После деплоя в Production, удалите код из шага 2!

---

## Что дальше?

После создания схемы:
1. Вернитесь к документу `CLOUDKIT_MANUAL_SETUP_REQUIRED.md`
2. Переходите к **Step 7: Test CloudKit Connection**

---

## Troubleshooting

**Не видите кнопку "Add Field"?**
- Убедитесь, что вы создали новый Record Type (нажали "+")
- Проверьте, что вы в правильном контейнере

**Поле Reference не даёт выбрать тип?**
- Сначала создайте Record Type, на который нужна ссылка
- Например, для создания Game с reference на User, сначала создайте User

**"Queryable" checkbox неактивен?**
- Queryable доступен только для некоторых типов полей
- Обязательно: String, Date/Time
- Не доступно: Asset, Location, некоторые другие

---

**Время выполнения**: ~15-20 минут для ручного создания
