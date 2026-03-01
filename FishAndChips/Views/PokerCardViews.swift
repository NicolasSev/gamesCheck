//
//  PokerCardViews.swift
//  FishAndChips
//

import SwiftUI

struct CardDisplayView: View {
    let notation: String
    
    private var card: Card? {
        try? Card(notation: notation)
    }
    
    var body: some View {
        if let card = card {
            VStack(spacing: 2) {
                Text(card.rank.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(card.displayColor)
                
                Text(card.suit.symbol)
                    .font(.system(size: 12))
                    .foregroundColor(card.displayColor)
            }
            .frame(width: 35, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
            )
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 35, height: 50)
                .cornerRadius(6)
        }
    }
    
}

struct HandDetailBoardCardView: View {
    let notation: String
    
    private var card: Card? {
        try? Card(notation: notation)
    }
    
    var body: some View {
        if let card = card {
            VStack(spacing: 2) {
                Text(card.rank.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(card.displayColor)
                
                Text(card.suit.symbol)
                    .font(.system(size: 14))
                    .foregroundColor(card.displayColor)
            }
            .frame(width: 44, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
            )
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 44, height: 64)
        }
    }
    
}

struct HandDetailPlayerCardView: View {
    let notation: String
    
    private var card: Card? {
        try? Card(notation: notation)
    }
    
    var body: some View {
        if let card = card {
            VStack(spacing: 2) {
                Text(card.rank.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(card.displayColor)
                
                Text(card.suit.symbol)
                    .font(.system(size: 11))
                    .foregroundColor(card.displayColor)
            }
            .frame(width: 36, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white)
            )
        } else {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 52)
        }
    }
    
}

struct MiniCardView: View {
    let notation: String
    
    private var card: Card? {
        try? Card(notation: notation)
    }
    
    var body: some View {
        if let card = card {
            HStack(spacing: 1) {
                Text(card.rank.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(card.displayColor)
                
                Text(card.suit.symbol)
                    .font(.system(size: 9))
                    .foregroundColor(card.displayColor)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
            )
        }
    }
}

struct HandRowCardView: View {
    let notation: String
    
    private var card: Card? {
        try? Card(notation: notation)
    }
    
    var body: some View {
        if let card = card {
            HStack(spacing: 2) {
                Text(card.rank.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(card.displayColor)
                
                Text(card.suit.symbol)
                    .font(.system(size: 10))
                    .foregroundColor(card.displayColor)
            }
            .frame(width: 32, height: 20)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
            )
            .frame(width: 42, height: 26)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 42, height: 26)
        }
    }
}
