# Step 7: Тестирование CloudKit соединения

## Что вы уже сделали ✅

1. ✅ Создали все Record Types в CloudKit Dashboard
2. ✅ Установили приложение на физическое устройство
3. ✅ Push notifications авторизованы
4. ✅ Device Token получен

## Следующие шаги

### 1. Пересоберите приложение

Я улучшил вывод CloudKit статуса для более понятной диагностики.

**В Xcode:**
1. Остановите текущий запуск (Stop)
2. Clean Build Folder: **Product → Clean Build Folder** (Cmd+Shift+K)
3. Запустите снова: **Product → Run** (Cmd+R)

### 2. Проверьте консоль

Теперь вы должны увидеть один из следующих статусов:

#### ✅ Успех:
```
✅ CloudKit Status: AVAILABLE - Ready to use!
✅ Push notifications authorized
Device Token: ...
```

Если видите это - **CloudKit работает!** Переходите к шагу 3.

#### ❌ Проблемы и решения:

**Статус: NO ACCOUNT**
```
❌ CloudKit Status: NO ACCOUNT - Please sign in to iCloud
```
**Решение:**
- На устройстве: Settings → [Ваше имя] → войдите в iCloud
- Убедитесь, что iCloud Drive включен

**Статус: RESTRICTED**
```
⚠️ CloudKit Status: RESTRICTED - iCloud access is restricted
```
**Решение:**
- Settings → Screen Time → Content & Privacy Restrictions → проверьте ограничения

**Статус: TEMPORARILY UNAVAILABLE**
```
⚠️ CloudKit Status: TEMPORARILY UNAVAILABLE
```
**Решение:**
- Подождите несколько минут
- Проверьте интернет-соединение
- Перезагрузите устройство

### 3. Проверка создания схемы (если используете автоматический метод)

Если вы **не удалили** код с `CloudKitSchemaCreator`, должны увидеть:

```
🔧 Starting CloudKit schema creation...
✓ User record type created
✓ Game record type created
✓ PlayerProfile record type created
✓ PlayerAlias record type created
✓ PlayerClaim record type created
✅ Schema creation completed! Check CloudKit Dashboard.
```

**Если видите ошибки** при создании схемы:
- Это нормально, если вы уже создали Record Types вручную!
- Ошибки типа "Record type already exists" можно игнорировать
- Или удалите/закомментируйте блок с `#if DEBUG` и `CloudKitSchemaCreator`

### 4. Проверьте CloudKit Dashboard

1. Откройте [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. Контейнер: `iCloud.com.nicolascooper.FishAndChips`
3. **Development** environment
4. Schema → Record Types
5. Должны видеть все 5 типов: User, Game, PlayerProfile, PlayerAlias, PlayerClaim

### 5. Создайте индексы (если ещё не сделали)

Перейдите в **Indexes** и создайте:

#### User:
- Name: `username_queryable`, Type: QUERYABLE, Field: username
- Name: `username_sortable`, Type: SORTABLE, Field: username
- Name: `email_queryable`, Type: QUERYABLE, Field: email

#### Game:
- Name: `timestamp_queryable`, Type: QUERYABLE, Field: timestamp

#### PlayerProfile:
- Name: `displayName_queryable`, Type: QUERYABLE, Field: displayName

#### PlayerAlias:
- Name: `aliasName_queryable`, Type: QUERYABLE, Field: aliasName

#### PlayerClaim:
- Name: `playerName_queryable`, Type: QUERYABLE, Field: playerName
- Name: `status_queryable`, Type: QUERYABLE, Field: status
- Name: `createdAt_queryable`, Type: QUERYABLE, Field: createdAt

### 6. Тестовая запись (опционально)

Можете попробовать создать тестовую запись:

**В CloudKit Dashboard:**
1. Data → Records
2. Выберите Record Type: "User"
3. Нажмите "+"
4. Заполните поля (username, email и т.д.)
5. Save

Если сохраняется без ошибок - схема работает правильно!

---

## Что дальше?

После успешного тестирования:

### ⚠️ Важно: Удалите временный код

Откройте `FishAndChipsApp.swift` и **закомментируйте или удалите** блок:

```swift
// TEMPORARY: Create CloudKit schema in Development mode
// ⚠️ Remove this code after schema is deployed to Production!
#if DEBUG
Task {
    do {
        print("🔧 Starting CloudKit schema creation...")
        try await CloudKitSchemaCreator().createDevelopmentSchema()
        print("✅ Schema creation completed! Check CloudKit Dashboard.")
    } catch {
        print("❌ Schema creation failed: \(error)")
        print("   Details: \(error.localizedDescription)")
    }
}
#endif
```

Замените на простой комментарий или удалите совсем.

### Переход к Production

1. В CloudKit Dashboard нажмите **"Deploy Schema Changes"**
2. Выберите: Deploy from **Development** to **Production**
3. Подтвердите деплой
4. Дождитесь завершения (может занять несколько минут)

### Step 8: Verify Everything Works

Откройте `docs/CLOUDKIT_MANUAL_SETUP_REQUIRED.md` и пройдитесь по чеклисту в Step 8:

- [x] CloudKit capability is enabled
- [x] Push Notifications capability is enabled
- [x] Background Modes are configured
- [x] Entitlements file is correct
- [x] CloudKit container exists in Developer Portal
- [x] CloudKit schema is created in Dashboard
- [x] App builds without errors
- [ ] CloudKit status check returns `.available` ← проверьте это!

---

## Troubleshooting

### CloudKit Status не показывается

Если консоль пустая или не показывает CloudKit статус:
1. Убедитесь, что вы смотрите на правильное устройство в консоли Xcode
2. Попробуйте: View → Debug Area → Show Debug Area (Cmd+Shift+Y)
3. Переключитесь на вкладку Console

### Ошибка "Container not found"

```
❌ CloudKit Status Check Failed: Container not found
```

**Решение:**
1. Проверьте, что контейнер создан в Apple Developer Portal
2. Identifier точно совпадает: `iCloud.com.nicolascooper.FishAndChips`
3. Подождите 5-10 минут после создания контейнера
4. Попробуйте выйти и войти в iCloud на устройстве

### App крашится при запуске

**Проверьте:**
1. Entitlements файл подключен к target
2. Signing настроен правильно
3. Нет конфликтов с другими capabilities

---

**Текущий статус:** Тестирование CloudKit соединения
**Следующий шаг:** Deploy схемы в Production
