import SwiftUI

struct BalanceCardView: View {
    let balance: Decimal
    let isPositive: Bool
    let animationId: UUID // Идентификатор для перезапуска анимации

    @State private var displayedBalance: Double = 0
    @State private var currentAnimationTask: Task<Void, Never>?
    
    init(balance: Decimal, isPositive: Bool, animationId: UUID = UUID()) {
        self.balance = balance
        self.isPositive = isPositive
        self.animationId = animationId
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Текущий баланс")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Text(formatCurrency(Decimal(displayedBalance)))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    .linearGradient(
                        colors: isPositive ? [.green, .blue] : [.red, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                Text(isPositive ? "Прибыль" : "Убыток")
            }
            .font(.caption)
            .foregroundColor(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .liquidGlass()
        .onAppear { animateBalance() }
        .onChange(of: animationId) { _, _ in
            animateBalance()
        }
    }

    private func animateBalance() {
        // Отменяем предыдущую анимацию, если она есть
        currentAnimationTask?.cancel()
        displayedBalance = 0
        
        let target = Double(truncating: NSDecimalNumber(decimal: balance))
        let duration: Double = 1.5 // Общее время анимации
        
        // Для денежных значений используем фиксированное количество шагов
        let totalSteps = 60
        let step = target / Double(totalSteps)
        let stepInterval = duration / Double(totalSteps)
        
        // Используем Task для асинхронной анимации
        let task = Task { @MainActor in
            var currentValue: Double = 0
            var stepCount = 0
            
            while currentValue < target && stepCount < totalSteps {
                // Проверяем, не была ли задача отменена
                if Task.isCancelled {
                    return
                }
                
                stepCount += 1
                currentValue = min(currentValue + step, target)
                
                withAnimation(.linear(duration: stepInterval)) {
                    displayedBalance = currentValue
                }
                
                try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))
            }
            
            // Убеждаемся, что финальное значение точно установлено
            if !Task.isCancelled {
                displayedBalance = target
            }
        }
        
        currentAnimationTask = task
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₸"
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "₸0"
    }
}

