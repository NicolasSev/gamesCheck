import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    // Для анимации числовых значений
    let numericValue: Double?
    let isPercentage: Bool
    let isCurrency: Bool
    let animationId: UUID // Идентификатор для перезапуска анимации
    
    @State private var displayedValue: Double = 0
    @State private var currentAnimationTask: Task<Void, Never>?
    
    init(title: String, value: String, icon: String, color: Color, numericValue: Double? = nil, isPercentage: Bool = false, isCurrency: Bool = false, animationId: UUID = UUID()) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.numericValue = numericValue
        self.isPercentage = isPercentage
        self.isCurrency = isCurrency
        self.animationId = animationId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                if let numericValue = numericValue {
                    Text(formattedValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 15)
        .onAppear {
            if let numericValue = numericValue {
                animateValue(to: numericValue)
            }
        }
        .onChange(of: numericValue) { oldValue, newValue in
            if let newValue = newValue {
                animateValue(to: newValue)
            }
        }
        .onChange(of: animationId) { _, _ in
            // Перезапускаем анимацию при изменении идентификатора
            if let numericValue = numericValue {
                animateValue(to: numericValue)
            }
        }
    }
    
    private var formattedValue: String {
        if isPercentage {
            return "\(Int(displayedValue))%"
        } else if isCurrency {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "₸"
            formatter.currencyCode = "KZT"
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
            return formatter.string(from: NSNumber(value: displayedValue)) ?? "₸0"
        } else {
            return "\(Int(displayedValue))"
        }
    }
    
    private func animateValue(to target: Double) {
        // Отменяем предыдущую анимацию, если она есть
        currentAnimationTask?.cancel()
        displayedValue = 0
        
        let duration: Double = 1.5 // Общее время анимации
        
        // Для целых чисел <= 150 считаем по единицам, для остальных используем фиксированные шаги
        let step: Double
        let totalSteps: Int
        
        if !isPercentage && !isCurrency && target <= 150 && target == floor(target) {
            // Для целых чисел считаем по единицам
            step = 1
            totalSteps = Int(target)
        } else {
            // Для дробных чисел и больших значений используем фиксированное количество шагов
            totalSteps = 60
            step = target / Double(totalSteps)
        }
        
        let stepInterval = duration / Double(max(totalSteps, 1))
        
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
                    displayedValue = currentValue
                }
                
                try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))
            }
            
            // Убеждаемся, что финальное значение точно установлено
            if !Task.isCancelled {
                displayedValue = target
            }
        }
        
        currentAnimationTask = task
    }
}

