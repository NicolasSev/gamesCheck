//
//  DayCell.swift
//  PokerCardRecognizer
//
//  Created by Николас on 12.04.2025.
//
import SwiftUI
import CoreData


// Ячейка для одного дня в календаре
struct DayCell: View {
    let date: Date
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber(date))
                .font(.system(size: 14))
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .blue : .primary)
            
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10))
                    .padding(4)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 14, height: 14)
            }
        }
        .frame(width: 36, height: 40)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onTapGesture {
            onTap()
        }
    }
    
    private func dayNumber(_ date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }
}
