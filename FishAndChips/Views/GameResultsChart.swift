import SwiftUI

struct PlayerResult: Identifiable, Hashable {
    let id = UUID()
    let playerName: String
    let profit: Decimal
    let buyin: Int16
    let cashout: Int64
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PlayerResult, rhs: PlayerResult) -> Bool {
        lhs.id == rhs.id
    }
}

struct GameResultsChart: View {
    let playerResults: [PlayerResult]
    @State private var selectedResult: PlayerResult?
    
    private var maxAbsoluteProfit: Decimal {
        let profits = playerResults.map { abs($0.profit) }
        return profits.max() ?? 1
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatBuyinInTenge(_ buyin: Int16) -> String {
        let buyinInTenge = Decimal(buyin) * Decimal(ChipValue.tengePerChip)
        return buyinInTenge.formatCurrency()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Результаты игры")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            if playerResults.isEmpty {
                Text("Нет данных")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 16) {
                    ForEach(playerResults) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(result.playerName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(width: 80, alignment: .leading)
                                
                                Spacer()
                                
                                Text(result.profit.formatCurrency())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(result.profit >= 0 ? Color.casinoAccentGreen : .red)
                                    .frame(width: 100, alignment: .trailing)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 24)
                                        .cornerRadius(12)
                                    
                                    if result.profit != 0 {
                                        let profitValue = Double(truncating: NSDecimalNumber(decimal: abs(result.profit)))
                                        let maxValue = Double(truncating: NSDecimalNumber(decimal: maxAbsoluteProfit))
                                        let width = maxValue > 0 ? (profitValue / maxValue) * geometry.size.width : 0
                                        
                                        HStack {
                                            if result.profit < 0 {
                                                Spacer()
                                                Rectangle()
                                                    .fill(Color.red.opacity(0.85))
                                                    .frame(width: width, height: 24)
                                                    .cornerRadius(12)
                                            } else {
                                                Rectangle()
                                                    .fill(Color.casinoAccentGreen.opacity(0.85))
                                                    .frame(width: width, height: 24)
                                                    .cornerRadius(12)
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(height: 24)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedResult = result
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .glassCardStyle(.plain)
        .popover(item: $selectedResult) { result in
            VStack(alignment: .leading, spacing: 12) {
                Text(result.playerName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Байины:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(result.buyin)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Байины (в тенге):")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBuyinInTenge(result.buyin))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Кэшаут:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Decimal(result.cashout).formatCurrency())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Результат:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(result.profit.formatCurrency())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(result.profit >= 0 ? Color.casinoAccentGreen : .red)
                    }
                }
            }
            .padding()
            .frame(width: 280)
        }
    }
}
