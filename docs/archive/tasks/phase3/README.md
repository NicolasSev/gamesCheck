# Phase 3: Миграция на PostgreSQL и FastAPI

**Срок:** 4-5 недель  
**Приоритет:** 🔴 Критический  
**Статус:** ⬜ TODO (Будущая миграция)  
**Требует:** Phase 2 (CloudKit) завершена

---

## Обзор

Создание backend API на FastAPI с PostgreSQL для облачной синхронизации данных между устройствами.

**Примечание:** Эта фаза будет реализована после Phase 2 (CloudKit), когда приложение вырастет и потребуется больше гибкости и масштабируемости. См. [../../PLAN_USER_CLAIMS.md](../../PLAN_USER_CLAIMS.md) - Вариант 3 для детального плана миграции.

---

## Структура проекта

```
poker-api/
├── app/
│   ├── main.py
│   ├── database.py
│   ├── models/       # SQLAlchemy models
│   ├── schemas/      # Pydantic schemas
│   ├── api/v1/       # API endpoints
│   ├── services/     # Business logic
│   └── utils/        # Helpers
├── alembic/          # Migrations
├── tests/
└── requirements.txt
```

---

## Задачи

### Backend (Python/FastAPI)

1. **Task 01:** Setup FastAPI проекта (2-3 дня)
2. **Task 02:** Создание SQLAlchemy моделей (2-3 дня)
3. **Task 03:** Auth endpoints (JWT) (3-4 дня)
4. **Task 04:** Game endpoints (2-3 дня)
5. **Task 05:** Player endpoints (2-3 дня)
6. **Task 06:** Statistics endpoints (2-3 дня)

### iOS Integration

7. **Task 07:** Создание Repository pattern (2-3 дня)
8. **Task 08:** APIClient для iOS (2-3 дня)
9. **Task 09:** Офлайн режим и синхронизация (3-4 дня)

---

## Технологии

**Backend:**
- Python 3.11+
- FastAPI
- PostgreSQL 15+
- SQLAlchemy 2.0
- Alembic
- JWT authentication

**iOS:**
- URLSession
- async/await
- Repository pattern

---

## API Endpoints

### Authentication
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `GET /api/v1/auth/me`

### Games
- `GET /api/v1/games`
- `POST /api/v1/games`
- `GET /api/v1/games/{id}`
- `PUT /api/v1/games/{id}`
- `DELETE /api/v1/games/{id}`

### Players
- `GET /api/v1/players/unclaimed`
- `POST /api/v1/players/claim`
- `GET /api/v1/players/profiles`

### Statistics
- `GET /api/v1/statistics/me`
- `GET /api/v1/statistics/balance`
- `GET /api/v1/statistics/by-type`

---

## Критерии завершения

- [ ] FastAPI сервер работает
- [ ] PostgreSQL база развернута
- [ ] Все endpoints реализованы
- [ ] JWT authentication работает
- [ ] iOS app подключается к API
- [ ] Офлайн режим работает
- [ ] API документация (Swagger) доступна
- [ ] Unit и integration тесты > 80%

---

## Deployment

Рекомендуется:
- **Railway.app** (простой deploy)
- **DigitalOcean** (бюджетный)
- **AWS** (production scale)

---

## Следующая фаза

- **[Phase 4: Система подписок](../phase4/)**
