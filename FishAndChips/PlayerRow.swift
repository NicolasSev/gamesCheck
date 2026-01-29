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
            .textFieldStyle(.roundedBorder)
            .keyboardType(.numberPad)
    }
}

struct PlayerRow: View {
    @ObservedObject var gameWithPlayer: GameWithPlayer
    var updateBuyIn: (GameWithPlayer, Int16) -> Void
    var setCashout: (GameWithPlayer, Int64) -> Void
    var isHost: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Первая строка: имя игрока и управление buyin
            HStack {
                Text(gameWithPlayer.player?.name ?? "Без имени")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Управление buyin (только для хоста)
                if isHost {
                    HStack(spacing: 8) {
                        Button(action: { updateBuyIn(gameWithPlayer, -1) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                                .padding(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("\(gameWithPlayer.buyin)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(minWidth: 40)
                        
                        Button(action: { updateBuyIn(gameWithPlayer, 1) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                                .padding(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(width: 140)
                } else {
                    // Для не-хоста показываем только buyin
                    Text("\(gameWithPlayer.buyin)")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Вторая строка: ввод cashout
            HStack {
                Text("Cashout:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                if isHost {
                    CashoutInputView(cashout: Binding(
                        get: { Double(gameWithPlayer.cashout) },
                        set: { newValue in
                            gameWithPlayer.cashout = Int64(newValue)
                        }
                    ))
                    .frame(width: 140)
                } else {
                    Text("\(gameWithPlayer.cashout)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .liquidGlass(cornerRadius: 12)
    }
}
