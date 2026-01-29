# CloudKit - Автоматическое создание схемы (рекомендуется)

## Проблема с ручным созданием

Если в CloudKit Dashboard интерфейс не даёт правильно настроить Reference поля, используйте этот метод.

## Решение: Автоматическое создание через код

### Шаг 1: Убедитесь, что вы в Development режиме

1. Откройте [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. Выберите контейнер: `iCloud.com.nicolascooper.FishAndChips`
3. **Вверху страницы** переключитесь на **"Development"** (не Production!)

### Шаг 2: Удалите существующие Record Types (если создали)

Если вы уже создали какие-то Record Types вручную:
1. Перейдите в Schema → Record Types
2. Удалите все созданные типы (User, Game, и т.д.)
3. Это нужно, чтобы автоматическое создание работало чисто

### Шаг 3: Добавьте код в приложение

Файл уже создан: `FishAndChips/Services/CloudKitSchemaCreator.swift`

Теперь добавьте вызов этого кода в главный файл приложения.

Найдите файл `FishAndChips/FishAndChipsApp.swift` (или `PokerCardRecognizerApp.swift`) и добавьте код:

```swift
import SwiftUI

@main
struct PokerCardRecognizerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    #if DEBUG
                    Task {
                        do {
                            print("🔧 Starting CloudKit schema creation...")
                            try await CloudKitSchemaCreator().createDevelopmentSchema()
                            print("✅ Schema creation completed!")
                        } catch {
                            print("❌ Schema creation failed: \(error)")
                            print("   Error details: \(error.localizedDescription)")
                        }
                    }
                    #endif
                }
        }
    }
}
```

### Шаг 4: Запустите приложение

1. Откройте проект в Xcode
2. Выберите **физическое устройство** (не симулятор!)
3. Убедитесь, что на устройстве выполнен вход в iCloud
4. Запустите приложение (Cmd+R)
5. Смотрите в консоль Xcode - должны появиться сообщения:
   ```
   🔧 Creating CloudKit schema in Development mode...
   ✓ User record type created
   ✓ Game record type created
   ✓ PlayerProfile record type created
   ✓ PlayerAlias record type created
   ✓ PlayerClaim record type created
   ✅ Development schema created successfully!
   ```

### Шаг 5: Проверьте схему в CloudKit Dashboard

1. Вернитесь в CloudKit Dashboard → Development → Schema → Record Types
2. Обновите страницу (F5)
3. Должны появиться все 5 Record Types с полями
4. **Проверьте, что Reference поля созданы правильно**

### Шаг 6: Добавьте индексы вручную

Автоматическое создание не добавляет индексы, поэтому добавьте их вручную:

#### Indexes для User:
- `username_queryable`: QUERYABLE, Field: username
- `username_sortable`: SORTABLE, Field: username  
- `email_queryable`: QUERYABLE, Field: email

#### Indexes для Game:
- `timestamp_indexed`: QUERYABLE, Field: timestamp

#### Indexes для PlayerProfile:
- `displayName_queryable`: QUERYABLE, Field: displayName

#### Indexes для PlayerAlias:
- `aliasName_queryable`: QUERYABLE, Field: aliasName

#### Indexes для PlayerClaim:
- `playerName_indexed`: QUERYABLE, Field: playerName
- `status_queryable`: QUERYABLE, Field: status
- `createdAt_indexed`: QUERYABLE, Field: createdAt

### Шаг 7: Deploy схемы в Production

1. В CloudKit Dashboard нажмите кнопку **"Deploy Schema Changes"**
2. Выберите: Deploy from Development to Production
3. Подтвердите деплой
4. Дождитесь завершения (может занять несколько минут)

### Шаг 8: Удалите код создания схемы

После успешного деплоя в Production:

1. Откройте `FishAndChipsApp.swift`
2. **Удалите** весь блок с `CloudKitSchemaCreator()` (или закомментируйте)
3. Этот код нужен был только один раз для создания схемы

```swift
// Удалите или закомментируйте этот блок после деплоя:
/*
.onAppear {
    #if DEBUG
    Task {
        ...
    }
    #endif
}
*/
```

---

## Преимущества этого метода

✅ Reference поля создаются правильно автоматически
✅ Не нужно разбираться с интерфейсом CloudKit Dashboard  
✅ Быстрее ручного создания
✅ Меньше вероятность ошибки

## Недостатки

⚠️ Требует запуск приложения на физическом устройстве
⚠️ Индексы всё равно нужно добавлять вручную

---

## Troubleshooting

**Ошибка: "Container not found"**
- Убедитесь, что контейнер создан в Apple Developer Portal
- Попробуйте подождать 5-10 минут после создания контейнера
- Проверьте, что identifier контейнера точно совпадает: `iCloud.com.nicolascooper.FishAndChips`

**Ошибка: "Not authenticated"**
- Убедитесь, что на устройстве выполнен вход в iCloud
- Перезагрузите устройство
- В Settings → iCloud проверьте, что iCloud Drive включен

**Record Types не появляются в Dashboard**
- Обновите страницу в браузере (F5)
- Проверьте, что вы в режиме "Development" а не "Production"
- Попробуйте выйти и зайти снова в CloudKit Dashboard

---

**Время выполнения**: ~10-15 минут
