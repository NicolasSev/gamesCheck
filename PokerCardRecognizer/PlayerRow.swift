import SwiftUI
import CoreData

// Представление для ввода cashout с использованием NumberFormatter
struct CashoutInputView: View {
    @Binding var cashout: Double
    private let formatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = false
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        nf.maximumIntegerDigits = 50
        return nf
    }()

    var body: some View {
        TextField("Cashout", value: $cashout, formatter: formatter)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.numberPad)
    }
}

struct PlayerRow: View {
    @ObservedObject var gameWithPlayer: GameWithPlayer
    var updateBuyIn: (GameWithPlayer, Int16) -> Void
    var setCashout: (GameWithPlayer, Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Первая строка: имя игрока и управление buyin
            HStack {
                Text(gameWithPlayer.player?.name ?? "Без имени")
                Spacer()
                HStack {
                    Button(action: { updateBuyIn(gameWithPlayer, -1) }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("\(gameWithPlayer.buyin)")
                        .frame(minWidth: 40)
                    
                    Button(action: { updateBuyIn(gameWithPlayer, 1) }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            // Вторая строка: ввод cashout
            HStack {
                Text("Cashout:")
                Spacer()
                // Создаем binding, чтобы работать с cashout как с Double
                CashoutInputView(cashout: Binding(
                    get: { Double(gameWithPlayer.cashout) },
                    set: { newValue in
                        gameWithPlayer.cashout = Int64(newValue)
                    }
                ))
                .frame(width: 100)
            }
        }
        .padding(.vertical, 4)
    }
}
