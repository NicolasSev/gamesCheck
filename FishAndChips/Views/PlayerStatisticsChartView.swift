//
//  PlayerStatisticsChartView.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import SwiftUI
import Charts
import CoreData

enum StatisticsType: String, CaseIterable, Identifiable {
    case buyin = "Байин"
    case cashout = "Кэшаут"
    case final = "Финальная сумма"
    
    var id: String { self.rawValue }
}

struct PlayerStatisticsChartView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player: Player
    var filteredGames: [Game]
    var selectedDate: Date?
    
    @State private var selectedStatType: StatisticsType = .final
    @State private var selectedDataPoint: ChartDataPoint?
    
    // Исходные данные игр
    private var gameData: [GameDataPoint] {
        let set = player.gameWithPlayers as? Set<GameWithPlayer> ?? []
        let filtered = set.filter { gwp in
            guard let game = gwp.game else { return false }
            let isInFilteredGames = filteredGames.contains(where: { $0.objectID == game.objectID })
            
            if let selected = selectedDate {
                if let timestamp = game.timestamp {
                    return isInFilteredGames && Calendar.current.isDate(timestamp, inSameDayAs: selected)
                } else {
                    return false
                }
            }
            
            return isInFilteredGames
        }
        .sorted { ($0.game?.timestamp ?? Date()) < ($1.game?.timestamp ?? Date()) }
        
        return filtered.compactMap { gwp -> GameDataPoint? in
            guard let game = gwp.game, let timestamp = game.timestamp else { return nil }
            
            let buyin = Int64(gwp.buyin)
            let cashout = gwp.cashout
            let final = cashout - (buyin * 2000)
            
            return GameDataPoint(
                date: timestamp,
                buyin: buyin,
                cashout: cashout,
                final: final
            )
        }
    }
    
    // Данные для графика (накопительные)
    private var chartData: [ChartDataPoint] {
        var cumulativeBuyin: Int64 = 0
        var cumulativeCashout: Int64 = 0
        var cumulativeFinal: Int64 = 0
        
        return gameData.map { gamePoint in
            cumulativeBuyin += gamePoint.buyin
            cumulativeCashout += gamePoint.cashout
            cumulativeFinal += gamePoint.final
            
            let value: Int64
            switch selectedStatType {
            case .buyin:
                value = cumulativeBuyin
            case .cashout:
                value = cumulativeCashout
            case .final:
                value = cumulativeFinal
            }
            
            return ChartDataPoint(
                date: gamePoint.date,
                value: value,
                gameBuyin: gamePoint.buyin,
                gameCashout: gamePoint.cashout,
                gameFinal: gamePoint.final
            )
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Переключатель типа статистики
                    Picker("Тип статистики", selection: $selectedStatType) {
                        ForEach(StatisticsType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // График
                    if chartData.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("Нет данных для графика")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("График \(selectedStatType.rawValue.lowercased())")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(chartData) { dataPoint in
                                LineMark(
                                    x: .value("Дата", dataPoint.date),
                                    y: .value("Значение", dataPoint.value)
                                )
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Дата", dataPoint.date),
                                    y: .value("Значение", dataPoint.value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.3), .blue.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                                
                                PointMark(
                                    x: .value("Дата", dataPoint.date),
                                    y: .value("Значение", dataPoint.value)
                                )
                                .foregroundStyle(selectedDataPoint?.id == dataPoint.id ? .red : .blue)
                                .symbolSize(selectedDataPoint?.id == dataPoint.id ? 100 : 50)
                            }
                            .chartXSelection(value: Binding(
                                get: { selectedDataPoint?.date },
                                set: { newDate in
                                    if let date = newDate {
                                        selectedDataPoint = chartData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
                                    } else {
                                        selectedDataPoint = nil
                                    }
                                }
                            ))
                            .chartBackground { chartProxy in
                                GeometryReader { geometry in
                                    if let selected = selectedDataPoint {
                                        let xPosition = chartProxy.position(forX: selected.date) ?? 0
                                        VStack(spacing: 4) {
                                            Text(formatDate(selected.date))
                                                .font(.caption)
                                                .bold()
                                            Text(formatValue(getGameValue(for: selected)))
                                                .font(.caption)
                                                .foregroundColor(valueColor(for: getGameValue(for: selected)))
                                        }
                                        .padding(6)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(6)
                                        .shadow(radius: 3)
                                        .position(x: xPosition, y: 20)
                                    }
                                }
                            }
                            .frame(height: 300)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Детальная статистика
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Детальная статистика")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(gameData, id: \.id) { gamePoint in
                            HStack {
                                Text(formatDate(gamePoint.date))
                                    .font(.subheadline)
                                    .frame(width: 80, alignment: .leading)
                                
                                Spacer()
                                
                                Text(formatValue(getGameValue(for: gamePoint)))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(valueColor(for: getGameValue(for: gamePoint)))
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(selectedDataPoint?.date == gamePoint.date ? Color.blue.opacity(0.2) : Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .onTapGesture {
                                // Находим соответствующую точку в chartData
                                if let chartPoint = chartData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: gamePoint.date) }) {
                                    selectedDataPoint = chartPoint
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(player.name ?? "Статистика")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: date)
    }
    
    private func formatValue(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    private func valueColor(for value: Int64) -> Color {
        switch selectedStatType {
        case .buyin:
            return .blue
        case .cashout:
            return .green
        case .final:
            return value >= 0 ? .green : .red
        }
    }
    
    private func getGameValue(for dataPoint: ChartDataPoint) -> Int64 {
        switch selectedStatType {
        case .buyin:
            return dataPoint.gameBuyin
        case .cashout:
            return dataPoint.gameCashout
        case .final:
            return dataPoint.gameFinal
        }
    }
    
    private func getGameValue(for gamePoint: GameDataPoint) -> Int64 {
        switch selectedStatType {
        case .buyin:
            return gamePoint.buyin
        case .cashout:
            return gamePoint.cashout
        case .final:
            return gamePoint.final
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int64 // Накопительное значение для графика
    let gameBuyin: Int64 // Значение за конкретную игру
    let gameCashout: Int64
    let gameFinal: Int64
}

struct GameDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let buyin: Int64
    let cashout: Int64
    let final: Int64
}

