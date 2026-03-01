import SwiftUI
import CoreData

struct MonthGameData {
    let monthKey: String
    let monthName: String
    var games: [Game]
    var totalProfit: Decimal
    var totalBuyins: Decimal
    var totalCashouts: Decimal
    var gamesCount: Int
}

struct YearGameData {
    let year: Int
    let months: [MonthGameData]
    let totalProfit: Decimal
    let totalGames: Int
}

struct YearAccordionView: View {
    let yearData: YearGameData
    let isYearExpanded: Bool
    @Binding var expandedMonths: Set<String>
    let onYearToggle: () -> Void
    let persistence: PersistenceController
    let formatCurrency: (Decimal) -> String
    let targetUserId: UUID?
    let targetPlayerName: String?
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    onYearToggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(yearData.year)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            Text("\(yearData.totalGames) игр")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Профит: \(yearData.totalProfit.formatCurrency())")
                                .font(.caption)
                                .foregroundColor(yearData.totalProfit >= 0 ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isYearExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isYearExpanded ? 0 : -90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isYearExpanded)
                }
                .padding()
                .liquidGlass(cornerRadius: 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isYearExpanded {
                VStack(spacing: 8) {
                    ForEach(yearData.months, id: \.monthKey) { monthData in
                        MonthAccordionView(
                            monthData: monthData,
                            isExpanded: expandedMonths.contains(monthData.monthKey),
                            onToggle: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    if expandedMonths.contains(monthData.monthKey) {
                                        expandedMonths.remove(monthData.monthKey)
                                    } else {
                                        expandedMonths.insert(monthData.monthKey)
                                    }
                                }
                            },
                            persistence: persistence,
                            formatCurrency: { $0.formatCurrency() },
                            targetUserId: targetUserId,
                            targetPlayerName: targetPlayerName
                        )
                        .padding(.leading, 16)
                    }
                }
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                ))
            }
        }
    }
}

struct MonthAccordionView: View {
    let monthData: MonthGameData
    let isExpanded: Bool
    let onToggle: () -> Void
    let persistence: PersistenceController
    let formatCurrency: (Decimal) -> String
    let targetUserId: UUID?
    let targetPlayerName: String?
    
    private func gameProfit(for game: Game) -> Decimal? {
        
        let profile: PlayerProfile? = {
            if let userId = targetUserId {
                return persistence.fetchPlayerProfile(byUserId: userId)
            }
            return nil
        }()
        
        let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
        
        let myParticipation: GameWithPlayer? = {
            if let profile = profile {
                return participations.first(where: { $0.playerProfile == profile })
            } else if let targetName = targetPlayerName {
                return participations.first { gwp in
                    guard let player = gwp.player, let playerName = player.name else { return false }
                    return playerName.lowercased() == targetName.lowercased()
                }
            }
            return nil
        }()
        
        guard let myParticipation = myParticipation else {
            return nil
        }
        
        let buyin = Decimal(Int(myParticipation.buyin))
        let cashout = Decimal(Int(myParticipation.cashout))
        return cashout - (buyin * 2000)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    onToggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monthData.monthName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            Text("\(monthData.gamesCount) игр")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Профит: \(monthData.totalProfit.formatCurrency())")
                                .font(.caption)
                                .foregroundColor(monthData.totalProfit >= 0 ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isExpanded)
                }
                .padding()
                .liquidGlass(cornerRadius: 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(monthData.games.sorted(by: { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }), id: \.gameId) { game in
                        NavigationLink {
                            if let gameType = game.gameType, gameType == "Бильярд" {
                                BilliardGameDetailView(game: game)
                            } else {
                                GameDetailView(game: game)
                            }
                        } label: {
                            GameRowView(game: game, userProfit: gameProfit(for: game))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 16)
                    }
                }
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                ))
            }
        }
    }
}
