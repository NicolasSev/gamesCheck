//
//  OddsResultCard.swift
//  FishAndChips
//

import SwiftUI

struct OddsResultCard: View {
    let result: OddsResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Результаты расчета")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(result.equities, id: \.playerIndex) { equity in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(equity.hand)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 4) {
                            Text("Побед:")
                            Text("\(equity.wins)")
                                .fontWeight(.medium)
                            
                            Text("Ничьих:")
                            Text("\(equity.ties)")
                                .fontWeight(.medium)
                        }
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text(equity.getEquityPercentage())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
            }
            
            Text("Симуляций: \(result.iterations), Время: \(String(format: "%.0f", result.executionTime * 1000))ms")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
}
