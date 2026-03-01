# Task 3.1: Setup FastAPI проекта

**Приоритет:** 🔴 Критический  
**Срок:** 2-3 дня  
**Статус:** ⬜ TODO  
**Тип:** Backend (Python)

---

## Описание

Создать базовый FastAPI проект с правильной структурой, зависимостями и конфигурацией.

---

## Предусловия

- ✅ Phase 1 завершена (iOS модели готовы)
- Python 3.11+ установлен
- PostgreSQL 15+ доступен (локально или cloud)

---

## Задачи

### 1. Создать структуру проекта

```bash
# Создать папку для backend
mkdir -p poker-api
cd poker-api

# Создать структуру
mkdir -p app/{api/v1,models,schemas,services,utils}
mkdir -p tests
mkdir -p alembic/versions
```

**Финальная структура:**

```
poker-api/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── api/
│   │   ├── __init__.py
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── auth.py
│   │       ├── games.py
│   │       ├── players.py
│   │       └── statistics.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── game.py
│   │   ├── player.py
│   │   └── base.py
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── game.py
│   │   └── token.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py
│   │   ├── game_service.py
│   │   └── player_service.py
│   └── utils/
│       ├── __init__.py
│       ├── security.py
│       └── dependencies.py
├── alembic/
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   └── test_auth.py
├── .env.example
├── .gitignore
├── requirements.txt
├── alembic.ini
└── README.md
```

### 2. Создать requirements.txt

```txt
# FastAPI
fastapi==0.109.0
uvicorn[standard]==0.27.0
python-multipart==0.0.6

# Database
sqlalchemy==2.0.25
psycopg2-binary==2.9.9
alembic==1.13.1

# Authentication
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-dotenv==1.0.0

# Validation
pydantic==2.5.3
pydantic-settings==2.1.0
email-validator==2.1.0

# Testing
pytest==7.4.4
pytest-asyncio==0.23.3
httpx==0.26.0

# Utils
python-dateutil==2.8.2
```

### 3. Создать .env.example

```env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/poker_tracker
DATABASE_ECHO=False

# Security
SECRET_KEY=your-secret-key-here-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# API
API_V1_PREFIX=/api/v1
PROJECT_NAME=Poker Tracker API
DEBUG=True
CORS_ORIGINS=["http://localhost:3000"]

# Server
HOST=0.0.0.0
PORT=8000
```

### 4. Создать app/config.py

```python
from pydantic_settings import BaseSettings
from pydantic import Field
from typing import List


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = Field(..., env="DATABASE_URL")
    DATABASE_ECHO: bool = Field(False, env="DATABASE_ECHO")
    
    # Security
    SECRET_KEY: str = Field(..., env="SECRET_KEY")
    ALGORITHM: str = Field("HS256", env="ALGORITHM")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(15, env="ACCESS_TOKEN_EXPIRE_MINUTES")
    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(7, env="REFRESH_TOKEN_EXPIRE_DAYS")
    
    # API
    API_V1_PREFIX: str = Field("/api/v1", env="API_V1_PREFIX")
    PROJECT_NAME: str = Field("Poker Tracker API", env="PROJECT_NAME")
    DEBUG: bool = Field(False, env="DEBUG")
    CORS_ORIGINS: List[str] = Field(["*"], env="CORS_ORIGINS")
    
    # Server
    HOST: str = Field("0.0.0.0", env="HOST")
    PORT: int = Field(8000, env="PORT")
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
```

### 5. Создать app/database.py

```python
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator

from app.config import settings

# Create engine
engine = create_engine(
    settings.DATABASE_URL,
    echo=settings.DATABASE_ECHO,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20
)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """
    Dependency для получения database session.
    
    Usage:
        @app.get("/items")
        def read_items(db: Session = Depends(get_db)):
            ...
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Инициализация БД (создание таблиц)"""
    Base.metadata.create_all(bind=engine)
```

### 6. Создать app/main.py

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import settings
from app.database import init_db
from app.api.v1 import auth, games, players, statistics


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle events"""
    # Startup
    print("🚀 Starting Poker Tracker API...")
    init_db()
    print("✅ Database initialized")
    
    yield
    
    # Shutdown
    print("👋 Shutting down Poker Tracker API...")


# Create FastAPI app
app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description="API for Poker Tracker iOS app",
    docs_url=f"{settings.API_V1_PREFIX}/docs",
    redoc_url=f"{settings.API_V1_PREFIX}/redoc",
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Health check
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "version": "1.0.0",
        "environment": "development" if settings.DEBUG else "production"
    }


# Include routers
app.include_router(
    auth.router,
    prefix=f"{settings.API_V1_PREFIX}/auth",
    tags=["Authentication"]
)

app.include_router(
    games.router,
    prefix=f"{settings.API_V1_PREFIX}/games",
    tags=["Games"]
)

app.include_router(
    players.router,
    prefix=f"{settings.API_V1_PREFIX}/players",
    tags=["Players"]
)

app.include_router(
    statistics.router,
    prefix=f"{settings.API_V1_PREFIX}/statistics",
    tags=["Statistics"]
)


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )
```

### 7. Создать placeholder routers

**app/api/v1/auth.py:**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter()


@router.post("/register")
async def register(db: Session = Depends(get_db)):
    """Register new user"""
    return {"message": "Registration endpoint - to be implemented"}


@router.post("/login")
async def login(db: Session = Depends(get_db)):
    """Login user"""
    return {"message": "Login endpoint - to be implemented"}


@router.post("/refresh")
async def refresh():
    """Refresh access token"""
    return {"message": "Refresh endpoint - to be implemented"}


@router.get("/me")
async def get_current_user(db: Session = Depends(get_db)):
    """Get current user info"""
    return {"message": "User info endpoint - to be implemented"}
```

**app/api/v1/games.py:**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db

router = APIRouter()

@router.get("")
async def get_games(db: Session = Depends(get_db)):
    return {"message": "Get games - to be implemented"}

@router.post("")
async def create_game(db: Session = Depends(get_db)):
    return {"message": "Create game - to be implemented"}
```

**app/api/v1/players.py:**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db

router = APIRouter()

@router.get("/unclaimed")
async def get_unclaimed_players(db: Session = Depends(get_db)):
    return {"message": "Unclaimed players - to be implemented"}
```

**app/api/v1/statistics.py:**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db

router = APIRouter()

@router.get("/me")
async def get_user_statistics(db: Session = Depends(get_db)):
    return {"message": "User stats - to be implemented"}
```

### 8. Создать .gitignore

```gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
build/
dist/
*.egg-info/

# Environment
.env
.env.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# Database
*.db
*.sqlite

# Logs
*.log

# OS
.DS_Store
Thumbs.db
```

### 9. Создать README.md

```markdown
# Poker Tracker API

Backend API для iOS приложения Poker Tracker.

## Технологии

- FastAPI 0.109+
- PostgreSQL 15+
- SQLAlchemy 2.0
- Alembic
- Python 3.11+

## Установка

```bash
# Создать virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# или
venv\Scripts\activate  # Windows

# Установить зависимости
pip install -r requirements.txt

# Скопировать .env
cp .env.example .env
# Отредактировать .env с вашими настройками

# Запустить миграции
alembic upgrade head
```

## Запуск

```bash
# Development
uvicorn app.main:app --reload

# Production
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## API Documentation

После запуска доступно по адресу:
- Swagger UI: http://localhost:8000/api/v1/docs
- ReDoc: http://localhost:8000/api/v1/redoc

## Тестирование

```bash
pytest
```
```

### 10. Setup PostgreSQL

```bash
# Создать базу данных
createdb poker_tracker

# Или через psql
psql -U postgres
CREATE DATABASE poker_tracker;
\q
```

---

## Тестирование

### 1. Установить зависимости

```bash
cd poker-api
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Настроить .env

```bash
cp .env.example .env
# Отредактировать DATABASE_URL и SECRET_KEY
```

### 3. Запустить сервер

```bash
uvicorn app.main:app --reload
```

### 4. Проверить endpoints

```bash
# Health check
curl http://localhost:8000/health

# API docs
open http://localhost:8000/api/v1/docs

# Test placeholder endpoint
curl http://localhost:8000/api/v1/auth/register -X POST
```

---

## Критерии приемки

- [ ] Структура проекта создана
- [ ] requirements.txt содержит все зависимости
- [ ] config.py загружает переменные окружения
- [ ] database.py настроен для PostgreSQL
- [ ] main.py запускается без ошибок
- [ ] Все placeholder routers созданы
- [ ] Health check endpoint работает
- [ ] API documentation доступна
- [ ] .gitignore настроен
- [ ] README.md написан

---

## Следующие шаги

- **Task 3.2:** Создание SQLAlchemy моделей
- **Task 3.3:** Реализация auth endpoints

---

## Полезные ссылки

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [SQLAlchemy 2.0 Documentation](https://docs.sqlalchemy.org/)
- [Pydantic Settings](https://docs.pydantic.dev/latest/usage/pydantic_settings/)
