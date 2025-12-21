# Техническая спецификация

Полная техническая документация проекта PokerCardRecognizer.

---

## Обзор архитектуры

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS App (SwiftUI)                     │
├─────────────────────────────────────────────────────────────┤
│  Views          ViewModels       Services       Repository   │
│    │                │                │                │      │
│    └────────────────┴────────────────┴────────────────┘      │
│                          │                                   │
│                          ▼                                   │
│              ┌───────────────────────┐                       │
│              │   CoreData (Local)    │                       │
│              └───────────────────────┘                       │
│                          │                                   │
│                          ▼                                   │
│              ┌───────────────────────┐                       │
│              │    API Client (HTTP)  │                       │
│              └───────────────────────┘                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │       FastAPI Backend (Python)      │
         ├─────────────────────────────────────┤
         │  Endpoints    Services    Models    │
         │      │            │          │      │
         │      └────────────┴──────────┘      │
         │               │                     │
         │               ▼                     │
         │     ┌──────────────────┐           │
         │     │   PostgreSQL     │           │
         │     └──────────────────┘           │
         └─────────────────────────────────────┘
```

---

## Модели данных

### iOS (CoreData)

#### User
Зарегистрированный пользователь приложения.

```swift
@objc(User)
class User: NSManagedObject {
    @NSManaged var userId: UUID          // PK
    @NSManaged var username: String      // Unique
    @NSManaged var email: String?
    @NSManaged var passwordHash: String
    @NSManaged var createdAt: Date
    @NSManaged var lastLoginAt: Date?
    @NSManaged var subscriptionStatus: String  // "free" | "premium"
    @NSManaged var subscriptionExpiresAt: Date?
    
    // Relationships
    @NSManaged var createdGames: NSSet?       // → Game
    @NSManaged var playerProfile: PlayerProfile?  // → PlayerProfile
}
```

#### Game
Запись об одной игровой сессии.

```swift
@objc(Game)
class Game: NSManagedObject {
    @NSManaged var gameId: UUID          // PK
    @NSManaged var timestamp: Date?
    @NSManaged var gameType: String?     // "Poker" | "Billiard"
    @NSManaged var creatorUserId: UUID?
    @NSManaged var notes: String?
    @NSManaged var isDeleted: Bool       // Soft delete
    
    // Relationships
    @NSManaged var creator: User?           // → User
    @NSManaged var players: NSSet?          // → GameWithPlayer
}
```

#### PlayerProfile
Унифицированный профиль игрока (анонимный или зарегистрированный).

```swift
@objc(PlayerProfile)
class PlayerProfile: NSManagedObject {
    @NSManaged var profileId: UUID       // PK
    @NSManaged var userId: UUID?         // FK → User (nullable)
    @NSManaged var displayName: String
    @NSManaged var isAnonymous: Bool
    @NSManaged var createdAt: Date
    
    // Cached statistics
    @NSManaged var totalGamesPlayed: Int32
    @NSManaged var totalBuyins: NSDecimalNumber
    @NSManaged var totalCashouts: NSDecimalNumber
    
    // Relationships
    @NSManaged var user: User?                    // → User
    @NSManaged var aliases: NSSet?                // → PlayerAlias
    @NSManaged var gameParticipations: NSSet?     // → GameWithPlayer
}
```

#### PlayerAlias
Псевдоним игрока (различные написания имени).

```swift
@objc(PlayerAlias)
class PlayerAlias: NSManagedObject {
    @NSManaged var aliasId: UUID         // PK
    @NSManaged var profileId: UUID       // FK → PlayerProfile
    @NSManaged var aliasName: String     // Unique
    @NSManaged var claimedAt: Date
    @NSManaged var gamesCount: Int32
    
    // Relationships
    @NSManaged var profile: PlayerProfile    // → PlayerProfile
}
```

#### GameWithPlayer
Join table связывающая игры и игроков с buyins/cashouts.

```swift
@objc(GameWithPlayer)
class GameWithPlayer: NSManagedObject {
    @NSManaged var buyin: NSDecimalNumber
    @NSManaged var cashout: NSDecimalNumber
    
    // Relationships
    @NSManaged var game: Game?                    // → Game
    @NSManaged var player: Player?                // → Player (legacy)
    @NSManaged var playerProfile: PlayerProfile?  // → PlayerProfile (new)
}
```

#### Player (Legacy)
Старая модель игрока, постепенно мигрируется в PlayerProfile.

```swift
@objc(Player)
class Player: NSManagedObject {
    @NSManaged var name: String?
    // ... other legacy fields
}
```

---

### Backend (PostgreSQL)

#### users

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    subscription_status VARCHAR(20) DEFAULT 'free',
    subscription_expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,
    
    CHECK (subscription_status IN ('free', 'premium'))
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
```

#### games

```sql
CREATE TABLE games (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_user_id UUID REFERENCES users(id),
    game_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_games_creator ON games(creator_user_id);
CREATE INDEX idx_games_timestamp ON games(timestamp);
CREATE INDEX idx_games_type ON games(game_type);
```

#### player_profiles

```sql
CREATE TABLE player_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    display_name VARCHAR(100) NOT NULL,
    is_anonymous BOOLEAN DEFAULT TRUE,
    total_games_played INTEGER DEFAULT 0,
    total_buyins DECIMAL(10, 2) DEFAULT 0,
    total_cashouts DECIMAL(10, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id)
);

CREATE INDEX idx_profiles_user ON player_profiles(user_id);
CREATE INDEX idx_profiles_anonymous ON player_profiles(is_anonymous);
```

#### player_aliases

```sql
CREATE TABLE player_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID REFERENCES player_profiles(id) ON DELETE CASCADE,
    alias_name VARCHAR(100) UNIQUE NOT NULL,
    games_count INTEGER DEFAULT 0,
    claimed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_aliases_profile ON player_aliases(profile_id);
CREATE INDEX idx_aliases_name ON player_aliases(alias_name);
```

#### game_players

```sql
CREATE TABLE game_players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID REFERENCES games(id) ON DELETE CASCADE,
    player_profile_id UUID REFERENCES player_profiles(id),
    buyin DECIMAL(10, 2) NOT NULL,
    cashout DECIMAL(10, 2) NOT NULL,
    
    CHECK (buyin >= 0),
    CHECK (cashout >= 0)
);

CREATE INDEX idx_game_players_game ON game_players(game_id);
CREATE INDEX idx_game_players_profile ON game_players(player_profile_id);
```

---

## API спецификация

### Базовый URL

```
Production: https://api.pokertracker.app/api/v1
Development: http://localhost:8000/api/v1
```

### Аутентификация

Все защищенные endpoints требуют JWT токен в header:

```
Authorization: Bearer <access_token>
```

### Endpoints

#### Authentication

**POST /auth/register**
```json
Request:
{
  "username": "string",
  "password": "string",
  "email": "string?" 
}

Response: 201
{
  "user_id": "uuid",
  "username": "string",
  "access_token": "string",
  "refresh_token": "string",
  "token_type": "bearer"
}
```

**POST /auth/login**
```json
Request:
{
  "username": "string",
  "password": "string"
}

Response: 200
{
  "user_id": "uuid",
  "access_token": "string",
  "refresh_token": "string",
  "token_type": "bearer"
}
```

**POST /auth/refresh**
```json
Request:
{
  "refresh_token": "string"
}

Response: 200
{
  "access_token": "string",
  "token_type": "bearer"
}
```

**GET /auth/me**
```json
Response: 200
{
  "user_id": "uuid",
  "username": "string",
  "email": "string?",
  "subscription_status": "free" | "premium",
  "subscription_expires_at": "datetime?",
  "created_at": "datetime"
}
```

#### Games

**GET /games**
```
Query params:
  - filter: "all" | "created" | "participated"
  - game_type: string?
  - from_date: datetime?
  - to_date: datetime?
  - limit: int = 50
  - offset: int = 0

Response: 200
{
  "games": [
    {
      "id": "uuid",
      "game_type": "string",
      "timestamp": "datetime",
      "creator_user_id": "uuid",
      "is_creator": boolean,
      "players_count": int,
      "my_buyin": decimal,
      "my_cashout": decimal,
      "profit": decimal,
      "notes": "string?"
    }
  ],
  "total": int,
  "limit": int,
  "offset": int
}
```

**POST /games**
```json
Request:
{
  "game_type": "string",
  "timestamp": "datetime",
  "notes": "string?",
  "players": [
    {
      "player_profile_id": "uuid",
      "buyin": decimal,
      "cashout": decimal
    }
  ]
}

Response: 201
{
  "id": "uuid",
  "game_type": "string",
  "timestamp": "datetime",
  ...
}
```

**GET /games/{game_id}**
```json
Response: 200
{
  "id": "uuid",
  "game_type": "string",
  "timestamp": "datetime",
  "creator_user_id": "uuid",
  "notes": "string?",
  "players": [
    {
      "player_profile_id": "uuid",
      "display_name": "string",
      "buyin": decimal,
      "cashout": decimal,
      "profit": decimal
    }
  ],
  "total_buyins": decimal,
  "total_cashouts": decimal,
  "is_balanced": boolean
}
```

**PUT /games/{game_id}**
```json
Request:
{
  "notes": "string?",
  "players": [...]
}

Response: 200
{ /* updated game */ }
```

**DELETE /games/{game_id}**
```
Response: 204 No Content
```

#### Statistics

**GET /statistics/me**
```json
Response: 200
{
  "total_games_created": int,
  "total_games_participated": int,
  "total_sessions": int,
  "total_buyins": decimal,
  "total_cashouts": decimal,
  "current_balance": decimal,
  "win_rate": float,
  "average_profit": decimal,
  "best_session": decimal,
  "worst_session": decimal,
  "profit_by_game_type": {
    "Poker": decimal,
    "Billiard": decimal
  }
}
```

**GET /statistics/timeline**
```
Query: from_date, to_date, granularity=day

Response: 200
{
  "timeline": [
    {
      "date": "date",
      "balance": decimal,
      "sessions": int
    }
  ]
}
```

#### Players

**GET /players/unclaimed**
```json
Response: 200
{
  "players": [
    {
      "name": "string",
      "games_count": int,
      "total_buyin": decimal,
      "total_cashout": decimal
    }
  ]
}
```

**POST /players/claim**
```json
Request:
{
  "player_name": "string"
}

Response: 200
{
  "profile_id": "uuid",
  "alias_id": "uuid",
  "games_migrated": int
}
```

**GET /players/profiles**
```json
Response: 200
{
  "profile": {
    "id": "uuid",
    "display_name": "string",
    "aliases": ["string"],
    "total_games": int,
    "balance": decimal
  }
}
```

---

## Безопасность

### Аутентификация

- **JWT токены**: Access (15 min) + Refresh (7 days)
- **Password hashing**: SHA256 (iOS), bcrypt (Backend)
- **Token storage**: Keychain (iOS)

### API Security

- **HTTPS только** в production
- **Rate limiting**: 100 req/min per IP
- **CORS**: Настроен для specific origins
- **SQL injection protection**: Parameterized queries
- **XSS protection**: Input sanitization

---

## Performance

### Оптимизации

**iOS:**
- LazyVStack для больших списков
- Image caching
- CoreData batch operations
- Async/await для сети

**Backend:**
- Database connection pooling
- Query optimization с indexes
- Response caching (Redis)
- Pagination для больших datasets

### Целевые метрики

- App launch: < 2s
- API response: < 200ms (p95)
- List scrolling: 60 FPS
- Memory usage: < 100MB

---

## Deployment

### iOS
- TestFlight → App Store
- Minimum iOS: 16.0
- Architectures: arm64

### Backend
- Platform: Railway / DigitalOcean / AWS
- Container: Docker
- Database: PostgreSQL 15+
- CI/CD: GitHub Actions

---

## Мониторинг

- **Errors**: Sentry
- **Logs**: Structlog (Python), OSLog (iOS)
- **Metrics**: DataDog
- **Uptime**: UptimeRobot

---

## Версионирование

### API
- Current: v1
- Format: /api/v{major}

### iOS App
- Format: MAJOR.MINOR.PATCH
- Current: 1.0.0

---

Эта спецификация актуальна на дату: 2025-12-21
