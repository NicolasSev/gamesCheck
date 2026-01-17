# CloudKit Setup - Быстрый чеклист

Краткая версия для быстрой проверки готовности к Phase 2.

---

## ✅ Чеклист (выполняйте по порядку)

### 1. Apple Developer аккаунт
- [ ] Аккаунт создан на [developer.apple.com](https://developer.apple.com)
- [ ] Подписка оплачена ($99/год)
- [ ] Статус аккаунта "Active" в Developer Portal

### 2. App Identifier и CloudKit Container
- [ ] App ID создан: `com.nicolascooper.PokerCardRecognizer`
- [ ] CloudKit capability включена в App ID
- [ ] CloudKit Container создан: `iCloud.com.nicolascooper.PokerCardRecognizer`
- [ ] Container виден в [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)

### 3. Настройка Xcode проекта
- [ ] Bundle Identifier: `com.nicolascooper.PokerCardRecognizer` (проверено ✅)
- [ ] Team выбран в Signing & Capabilities
- [ ] CloudKit capability добавлена в проект
- [ ] Container выбран: `iCloud.com.nicolascooper.PokerCardRecognizer`
- [ ] Файл `PokerCardRecognizer.entitlements` создан автоматически

### 4. Тестирование
- [ ] Проект компилируется без ошибок (Cmd+B)
- [ ] Приложение запускается на физическом устройстве
- [ ] iCloud включен на устройстве
- [ ] Тест CloudKit проходит успешно (см. CLOUDKIT_SETUP_GUIDE.md)

---

## 📋 Информация для агента

После выполнения всех шагов, передайте агенту:

```
✅ Apple Developer аккаунт: активен
✅ Bundle Identifier: com.nicolascooper.PokerCardRecognizer
✅ CloudKit Container: iCloud.com.nicolascooper.PokerCardRecognizer
✅ Team ID: [ваш Team ID из Developer Portal]
✅ Тестирование: пройдено успешно
```

---

## 📖 Подробное руководство

Для детальных инструкций см. **[CLOUDKIT_SETUP_GUIDE.md](./CLOUDKIT_SETUP_GUIDE.md)**

---

## ⚠️ Важные замечания

1. **Bundle Identifier уже правильный:** `com.nicolascooper.PokerCardRecognizer` ✅
2. **CloudKit Container ID:** должен быть `iCloud.com.nicolascooper.PokerCardRecognizer`
3. **Тестирование:** CloudKit лучше тестировать на физическом устройстве, не в симуляторе
4. **Активация аккаунта:** может занять 24-48 часов после оплаты

---

**Готово?** Когда все пункты отмечены ✅, можно передавать проект агенту для Phase 2! 🚀

