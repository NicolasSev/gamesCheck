import SwiftUI

struct GameRowView: View {
    let game: Game
    let userProfit: Decimal? // Профит пользователя в этой игре
    
    private var mvp: (name: String, profit: Decimal)? {
        let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        guard !participations.isEmpty else { return nil }
        
        let playersWithProfit = participations.compactMap { gwp -> (name: String, profit: Decimal)? in
            guard let player = gwp.player,
                  let name = player.name else { return nil }
            
            // Конвертируем байин в тенге: 1 байин = 2000 тенге
            let buyin = Decimal(Int(gwp.buyin))
            let cashout = Decimal(Int(gwp.cashout))
            let profit = cashout - (buyin * 2000)
            
            return (name: name, profit: profit)
        }
        
        return playersWithProfit.max(by: { $0.profit < $1.profit })
    }
    
    private var formattedMVPProfit: String {
        guard let mvp = mvp else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₸"
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: mvp.profit)) ?? "₸0"
    }
    
    private var formattedUserProfit: String? {
        guard let profit = userProfit else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₸"
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: profit))
    }
    
    private var formattedDate: String {
        guard let timestamp = game.timestamp else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: timestamp)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(game.gameType ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if !formattedDate.isEmpty {
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                if let mvp = mvp {
                    HStack(spacing: 4) {
                        Text("MVP:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(mvp.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                        Text(formattedMVPProfit)
                            .font(.caption)
                            .foregroundColor(mvp.profit >= 0 ? .green : .red)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let profit = userProfit {
                    if let profitString = formattedUserProfit {
                        Text(profitString)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(profit >= 0 ? .green : .red)
                    }
                } else {
                    Text("не участвовал")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Text("\(game.gameWithPlayers?.count ?? 0) игроков")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Стрелка в конце снипета
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 8)
        }
        .padding()
        .liquidGlass(cornerRadius: 12)
    }
}

