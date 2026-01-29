# Мастер-план проекта gamesCheck

> **Единый источник правды для всех агентов, работающих над проектом**

Последнее обновление: 2026-01-29

---

## Инструкция для AI агентов

### Когда пользователь просит продолжить работу над проектом:

1. **ВСЕГДА начинайте с чтения актуального плана:**
   ```
   Read ~/.cursor/plans/testflight_deployment_plan_81a25c38.plan.md
   ```

2. **Проверьте текущий статус:**
   - Посмотрите на `todos` в начале плана
   - Найдите задачи со статусом `pending`
   - Начните с первой незавершенной задачи

3. **НЕ создавайте новые MD файлы** в `docs/` без явного запроса
   - Вся актуальная информация уже в плане
   - Если нужно что-то задокументировать - обновите план напрямую

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
1. Добавить индексы в CloudKit Dashboard
2. Deploy CloudKit схемы в Production
3. Создать App ID и приложение в App Store Connect
4. Настроить Xcode для Release
5. Создать архив
6. Загрузить в TestFlight
7. Активировать Internal Testing

**Ожидаемое время:** 3-4 дня работы

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

**После завершения текущего этапа удалить:**

**Phase Summaries (устарели):**
- `PROJECT_COMPLETION_SUMMARY.md`
- `PRODUCTION_READY_INDEX.md`
- `PHASE2_AUTH_SUMMARY.md`
- `PHASE2_IMPLEMENTATION_SUMMARY.md`
- `PHASE3_CLOUDKIT_SUMMARY.md`
- `PHASE4_PUSH_SUMMARY.md`
- `PHASE5_TESTING_SUMMARY.md`
- `PHASE6_REFACTOR_SUMMARY.md`
- `PHASE7_TESTFLIGHT_SUMMARY.md`

**CloudKit дубликаты:**
- `CLOUDKIT_SUCCESS_NEXT_STEPS.md`
- `CLOUDKIT_SETUP_GUIDE.md`
- `CLOUDKIT_SETUP_CHECKLIST.md`
- `CLOUDKIT_SCHEMA_STEP_BY_STEP.md`
- `CLOUDKIT_SCHEMA_VERIFICATION.md`
- `CLOUDKIT_AUTO_SCHEMA_GUIDE.md`

**Старая структура:**
- `PROGRESS.md`
- `INDEX.md`
- `README.md`
- `QUICKSTART.md`
- `QUICK_START_PHASE2.md`
- `PLAN_USER_CLAIMS.md`
- `COREDATA_PLAYERCLAIM_SETUP.md`
- `STEP7_TESTING_GUIDE.md`

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
❌ Создаю новый файл: docs/TESTFLIGHT_PLAN_NEW.md
❌ Спрашиваю пользователя "С чего начать?"
❌ Начинаю работу, не прочитав план
❌ Не обновляю статус todos
```

---

## Следующие этапы (после TestFlight)

**Этап 2: Тестирование (создать отдельный план)**
- Проверка синхронизации CloudKit на 2+ устройствах
- Тестирование оффлайн режима
- Проверка push-уведомлений
- Сбор багов через TestFlight Feedback

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
│   └── TECHNICAL_SPEC.md
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
- [ ] НЕ буду создавать новые MD файлы без необходимости
- [ ] Буду обновлять статус todos по мере работы
- [ ] После завершения задачи отмечу её как `completed`

---

**Этот файл - единая точка входа для всех агентов. Следуйте ему!**
