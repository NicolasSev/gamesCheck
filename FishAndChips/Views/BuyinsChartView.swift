import SwiftUI

struct GameItem: Identifiable {
    let id: UUID
}

struct BuyinsChartView: View {
    let data: [(date: Date, buyin: Decimal, gameId: UUID)]
    let formatCurrency: (Decimal) -> String
    
    @State private var selectedGameId: UUID?
    @State private var isFullScreen = false
    @Environment(\.managedObjectContext) private var viewContext
    private let persistence = PersistenceController.shared
    
    private var maxBuyinValue: Decimal {
        data.map { $0.buyin }.max() ?? 1
    }
    
    private var minBuyinValue: Decimal {
        data.map { $0.buyin }.min() ?? 0
    }
    
    private var maxBuyinDouble: Double {
        Double(truncating: NSDecimalNumber(decimal: maxBuyinValue))
    }
    
    private var minBuyinDouble: Double {
        Double(truncating: NSDecimalNumber(decimal: minBuyinValue))
    }
    
    private var buyinRange: Double {
        maxBuyinDouble - minBuyinDouble
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if data.isEmpty {
                Text("Нет данных")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // График в обычном режиме (без скролла, как было раньше)
                let containerWidth = UIScreen.main.bounds.width - 32
                ChartContentView(
                    data: data,
                    maxBuyinValue: maxBuyinValue,
                    minBuyinValue: minBuyinValue,
                    maxBuyinDouble: maxBuyinDouble,
                    minBuyinDouble: minBuyinDouble,
                    buyinRange: buyinRange,
                    containerWidth: containerWidth,
                    onPointTap: { gameId in
                        selectedGameId = gameId
                    }
                )
                .frame(height: 300)
            }
        }
        .liquidGlass(cornerRadius: 12)
        .sheet(item: Binding(
            get: { selectedGameId.map { GameItem(id: $0) } },
            set: { selectedGameId = $0?.id }
        )) { item in
            if let game = persistence.fetchGame(byId: item.id) {
                if let gameType = game.gameType, gameType == "Бильярд" {
                    BilliardGameDetailView(game: game)
                } else {
                    GameDetailView(game: game)
                }
            }
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            FullScreenChartView(
                data: data,
                maxBuyinValue: maxBuyinValue,
                minBuyinValue: minBuyinValue,
                maxBuyinDouble: maxBuyinDouble,
                minBuyinDouble: minBuyinDouble,
                buyinRange: buyinRange,
                onClose: { isFullScreen = false },
                onPointTap: { gameId in
                    selectedGameId = gameId
                    isFullScreen = false
                }
            )
        }
    }
}

// Полноэкранный вид графика
struct FullScreenChartView: View {
    let data: [(date: Date, buyin: Decimal, gameId: UUID)]
    let maxBuyinValue: Decimal
    let minBuyinValue: Decimal
    let maxBuyinDouble: Double
    let minBuyinDouble: Double
    let buyinRange: Double
    let onClose: () -> Void
    let onPointTap: (UUID) -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    private let persistence = PersistenceController.shared
    @State private var selectedGameId: UUID?
    
    var body: some View {
        ZStack {
            // Фоновое изображение
            if let backgroundImage = UIImage(named: "casino-background") {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.7),
                                Color.black.opacity(0.9)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
            } else {
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Заголовок и кнопка закрытия
                HStack {
                    Text("График байинов по датам")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // График на весь экран с горизонтальным скроллом
                GeometryReader { geometry in
                    let chartWidth = max(geometry.size.width, CGFloat(data.count) * 60)
                    ScrollView(.horizontal, showsIndicators: true) {
                        ChartContentView(
                            data: data,
                            maxBuyinValue: maxBuyinValue,
                            minBuyinValue: minBuyinValue,
                            maxBuyinDouble: maxBuyinDouble,
                            minBuyinDouble: minBuyinDouble,
                            buyinRange: buyinRange,
                            containerWidth: geometry.size.width,
                            onPointTap: { gameId in
                                onPointTap(gameId)
                            }
                        )
                        .frame(height: geometry.size.height)
                        .frame(width: chartWidth, alignment: .leading)
                    }
                }
            }
        }
        .sheet(item: Binding(
            get: { selectedGameId.map { GameItem(id: $0) } },
            set: { selectedGameId = $0?.id }
        )) { item in
            if let game = persistence.fetchGame(byId: item.id) {
                if let gameType = game.gameType, gameType == "Бильярд" {
                    BilliardGameDetailView(game: game)
                } else {
                    GameDetailView(game: game)
                }
            }
        }
    }
}

private struct ChartContentView: View {
    let data: [(date: Date, buyin: Decimal, gameId: UUID)]
    let maxBuyinValue: Decimal
    let minBuyinValue: Decimal
    let maxBuyinDouble: Double
    let minBuyinDouble: Double
    let buyinRange: Double
    let containerWidth: CGFloat
    let onPointTap: (UUID) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let leftPadding: CGFloat = 35 // Уменьшенный отступ слева
            let rightPadding: CGFloat = 16
            let topPadding: CGFloat = 10
            let bottomPadding: CGFloat = 35 // Отступ снизу для подписей
            let chartWidth = width - leftPadding - rightPadding
            let chartHeight = height - topPadding - bottomPadding
            let count = CGFloat(data.count)
            let stepX = count > 1 ? chartWidth / (count - 1) : 0
            
            ZStack(alignment: .bottomLeading) {
                // Сетка
                ForEach(0..<5, id: \.self) { i in
                    let yPos = topPadding + CGFloat(i) * (chartHeight / 4)
                    GridLineView(width: width, leftPadding: leftPadding, rightPadding: rightPadding, yPosition: yPos)
                }
                
                // Оси
                YAxisView(height: height, leftPadding: leftPadding, topPadding: topPadding, bottomPadding: bottomPadding)
                XAxisView(width: width, height: height, leftPadding: leftPadding, rightPadding: rightPadding, bottomPadding: bottomPadding)
                
                // Линия графика
                if data.count > 1 {
                        LinePathView(
                        data: data,
                        stepX: stepX,
                        chartHeight: chartHeight,
                        maxBuyinDouble: maxBuyinDouble,
                        minBuyinDouble: minBuyinDouble,
                        buyinRange: buyinRange,
                        leftPadding: leftPadding,
                        topPadding: topPadding,
                        bottomPadding: bottomPadding
                    )
                }
                
                // Точки
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    let xPos = leftPadding + CGFloat(index) * stepX
                    let buyinValue = Double(truncating: NSDecimalNumber(decimal: item.buyin))
                    let normalizedValue = buyinRange > 0 ? (buyinValue - minBuyinDouble) / buyinRange : 0.5
                    let yPos = height - bottomPadding - (CGFloat(normalizedValue) * chartHeight)
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .position(x: xPos, y: yPos)
                        .onTapGesture {
                            onPointTap(item.gameId)
                        }
                }
                
                // Подписи Y-оси
                YAxisLabelsView(
                    chartHeight: chartHeight,
                    maxBuyinValue: maxBuyinValue,
                    minBuyinValue: minBuyinValue,
                    topPadding: topPadding,
                    bottomPadding: bottomPadding
                )
                
                // Подписи X-оси
                XAxisLabelsView(
                    data: data,
                    chartWidth: chartWidth,
                    height: height,
                    leftPadding: leftPadding,
                    bottomPadding: bottomPadding
                )
            }
        }
    }
}

private struct GridLineView: View {
    let width: CGFloat
    let leftPadding: CGFloat
    let rightPadding: CGFloat
    let yPosition: CGFloat
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: leftPadding, y: yPosition))
            path.addLine(to: CGPoint(x: width - rightPadding, y: yPosition))
        }
        .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
    }
}

private struct YAxisView: View {
    let height: CGFloat
    let leftPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: leftPadding, y: topPadding))
            path.addLine(to: CGPoint(x: leftPadding, y: height - bottomPadding))
        }
        .stroke(Color.white.opacity(0.3), lineWidth: 1)
    }
}

private struct XAxisView: View {
    let width: CGFloat
    let height: CGFloat
    let leftPadding: CGFloat
    let rightPadding: CGFloat
    let bottomPadding: CGFloat
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: leftPadding, y: height - bottomPadding))
            path.addLine(to: CGPoint(x: width - rightPadding, y: height - bottomPadding))
        }
        .stroke(Color.white.opacity(0.3), lineWidth: 1)
    }
}

private struct LinePathView: View {
    let data: [(date: Date, buyin: Decimal, gameId: UUID)]
    let stepX: CGFloat
    let chartHeight: CGFloat
    let maxBuyinDouble: Double
    let minBuyinDouble: Double
    let buyinRange: Double
    let leftPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    
    var body: some View {
        Path { path in
            for (index, item) in data.enumerated() {
                let xPos = leftPadding + CGFloat(index) * stepX
                let buyinValue = Double(truncating: NSDecimalNumber(decimal: item.buyin))
                let normalizedValue = buyinRange > 0 ? (buyinValue - minBuyinDouble) / buyinRange : 0.5
                let yPos = topPadding + chartHeight - (CGFloat(normalizedValue) * chartHeight)
                
                if index == 0 {
                    path.move(to: CGPoint(x: xPos, y: yPos))
                } else {
                    path.addLine(to: CGPoint(x: xPos, y: yPos))
                }
            }
        }
        .stroke(Color.blue, lineWidth: 2)
    }
}

private struct YAxisLabelsView: View {
    let chartHeight: CGFloat
    let maxBuyinValue: Decimal
    let minBuyinValue: Decimal
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    
    private func formatBuyin(_ value: Decimal) -> String {
        let intValue = Int(truncating: NSDecimalNumber(decimal: value))
        return "\(intValue)"
    }
    
    var body: some View {
        ForEach(0..<5, id: \.self) { i in
            let iDec = Decimal(i)
            let labelsDec = Decimal(4)
            let buyinDiff = maxBuyinValue - minBuyinValue
            let buyinVal = minBuyinValue + (buyinDiff * iDec / labelsDec)
            let yPos = topPadding + CGFloat(4 - i) * (chartHeight / 4)
            
            Text(formatBuyin(buyinVal))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 30, alignment: .trailing)
                .position(x: 17.5, y: yPos)
        }
    }
}

private struct XAxisLabelsView: View {
    let data: [(date: Date, buyin: Decimal, gameId: UUID)]
    let chartWidth: CGFloat
    let height: CGFloat
    let leftPadding: CGFloat
    let bottomPadding: CGFloat
    
    private var groupedDates: [(year: Int, quarter: Int, startDate: Date)] {
        var groups: [String: (year: Int, quarter: Int, startDate: Date)] = [:]
        let calendar = Calendar.current
        
        for item in data {
            let components = calendar.dateComponents([.year, .month], from: item.date)
            guard let year = components.year, let month = components.month else { continue }
            let quarter = (month - 1) / 3 + 1
            let key = "\(year)-Q\(quarter)"
            
            if groups[key] == nil {
                // Находим первую дату в этом квартале
                var quarterStartComponents = DateComponents()
                quarterStartComponents.year = year
                quarterStartComponents.month = (quarter - 1) * 3 + 1
                quarterStartComponents.day = 1
                if let quarterStart = calendar.date(from: quarterStartComponents) {
                    groups[key] = (year: year, quarter: quarter, startDate: quarterStart)
                }
            }
        }
        
        return groups.values.sorted { $0.startDate < $1.startDate }
    }
    
    var body: some View {
        let groups = groupedDates
        let calendar = Calendar.current
        let minDate = data.first?.date ?? Date()
        let maxDate = data.last?.date ?? Date()
        let totalDays = calendar.dateComponents([.day], from: minDate, to: maxDate).day ?? 1
        let labelYPosition = height - bottomPadding / 2 // Позиция по центру отступа снизу
        
        return ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
            // Находим позицию на графике для этого квартала
            let daysFromStart = calendar.dateComponents([.day], from: minDate, to: group.startDate).day ?? 0
            let xPosition = leftPadding + (CGFloat(daysFromStart) / CGFloat(max(totalDays, 1))) * chartWidth
            
            if xPosition >= leftPadding && xPosition <= chartWidth + leftPadding {
                VStack(spacing: 2) {
                    Text("Q\(group.quarter)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(group.year)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .position(x: xPosition, y: labelYPosition)
            }
        }
    }
}
