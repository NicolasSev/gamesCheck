# Poker Odds Calculator - Быстрый старт

## 🚀 Минимальный пример

```swift
import PokerCardRecognizer

// Pre-flop: AA vs KK
let result = try PokerOddsCalculator.calculate(
    players: ["AhAs", "KdKc"],
    board: nil
)

print("AA: \(result.equities[0].equity)%")
print("KK: \(result.equities[1].equity)%")
```

## 📋 Формат карт

- **Ранг**: A, K, Q, J, T, 9, 8, 7, 6, 5, 4, 3, 2
- **Масть**: h (♥), d (♦), c (♣), s (♠)
- **Примеры**: `"Ah"` (туз червей), `"Ks"` (король пик), `"TdTc"` (пара десяток)

## 📖 Основные сценарии

### 1. Pre-flop (без борда)

```swift
let result = try PokerOddsCalculator.calculate(
    players: ["AhAs", "KdKc", "QsQh"],
    board: nil
)
```

### 2. Post-flop (с флопом)

```swift
let result = try PokerOddsCalculator.calculate(
    players: ["JhJs", "JdQd"],
    board: "7d9dTs"
)
```

### 3. Short Deck

```swift
let result = try PokerOddsCalculator.calculate(
    players: ["AhAs", "KdKc"],
    board: "6d7d8d",
    gameVariant: .shortDeck
)
```

### 4. Настройка точности

```swift
// Быстро (~50ms)
let quick = try PokerOddsCalculator.calculate(
    players: ["AhAs", "KdKc"],
    iterations: 1000
)

// Точно (~500ms)
let precise = try PokerOddsCalculator.calculate(
    players: ["AhAs", "KdKc"],
    iterations: 100000
)
```

## 🎯 Результаты

```swift
let result = try PokerOddsCalculator.calculate(
    players: ["AhAs", "KdKc"],
    board: nil
)

// Доступ к данным
for equity in result.equities {
    print("Player \(equity.playerIndex + 1): \(equity.hand)")
    print("  Equity: \(equity.equity)%")
    print("  Wins: \(equity.wins)")
    print("  Ties: \(equity.ties)")
    print("  Losses: \(equity.losses)")
}

print("Time: \(result.executionTime * 1000)ms")
```

## ❌ Обработка ошибок

```swift
do {
    let result = try PokerOddsCalculator.calculate(
        players: ["AhAs", "KdKc"],
        board: nil
    )
} catch PokerOddsError.duplicateCards(let cards) {
    print("Дубликаты: \(cards)")
} catch PokerOddsError.invalidCardFormat(let card) {
    print("Неверный формат: \(card)")
} catch {
    print("Ошибка: \(error)")
}
```

## 🎮 Интеграция в UI

```swift
struct MyView: View {
    @State private var result: OddsResult?
    
    var body: some View {
        VStack {
            Button("Calculate") {
                Task {
                    result = try? await calculate()
                }
            }
            
            if let result = result {
                ForEach(result.equities, id: \.playerIndex) { equity in
                    Text("\(equity.hand): \(equity.getEquityPercentage())")
                }
            }
        }
    }
    
    func calculate() async throws -> OddsResult {
        try await Task.detached {
            try PokerOddsCalculator.calculate(
                players: ["AhAs", "KdKc"],
                board: nil
            )
        }.value
    }
}
```

## 📚 Полная документация

Смотрите [POKER_ODDS_CALCULATOR.md](POKER_ODDS_CALCULATOR.md) для:
- Детального API описания
- Примеров интеграции
- Бенчмарков производительности
- Полного списка функций

## ⚡ Производительность

| Сценарий | Итерации | Время |
|----------|----------|-------|
| 2 игрока, pre-flop | 10,000 | ~80ms |
| 3 игрока, pre-flop | 10,000 | ~120ms |
| 2 игрока, post-flop | 10,000 | ~90ms |

## 🧪 Тесты

```bash
# Запуск тестов
⌘ + U в Xcode
```

Или программно:

```swift
import XCTest
@testable import PokerCardRecognizer

// Смотрите PokerCardRecognizerTests/PokerOddsCalculatorTests.swift
```

---

**Готово!** Теперь вы можете использовать Poker Odds Calculator в своем приложении.

Для получения дополнительной информации читайте [полную документацию](POKER_ODDS_CALCULATOR.md).
