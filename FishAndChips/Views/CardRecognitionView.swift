//
//  CardRecognitionView.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import SwiftUI
import CoreData

struct CardRecognitionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let initialCards: [Card]
    
    @State private var detectedCards: [Card] = []
    @State private var holeCards: [Card] = []
    @State private var boardCards: [Card] = []
    @State private var showManualEdit = false
    
    init(initialCards: [Card] = []) {
        self.initialCards = initialCards
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Информация о распознавании
                if detectedCards.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Наведите камеру на карты")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Распознанные карты появятся здесь")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Распознанные карты
                            Section(header: Text("Распознанные карты (\(detectedCards.count))")) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                                    ForEach(detectedCards) { card in
                                        CardView(card: card)
                                            .onTapGesture {
                                                toggleCardSelection(card)
                                            }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Карты в руке
                            Section(header: Text("Карты в руке (2 карты)")) {
                                if holeCards.isEmpty {
                                    Text("Нажмите на карты выше, чтобы добавить их в руку")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    HStack(spacing: 12) {
                                        ForEach(holeCards) { card in
                                            CardView(card: card)
                                                .onTapGesture {
                                                    holeCards.removeAll { $0.id == card.id }
                                                }
                                        }
                                        
                                        if holeCards.count < 2 {
                                            Button(action: { showManualEdit = true }) {
                                                Image(systemName: "plus.circle")
                                                    .font(.title)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Карты на столе
                            Section(header: Text("Карты на столе (Flop/Turn/River)")) {
                                if boardCards.isEmpty {
                                    Text("Нажмите на карты выше, чтобы добавить их на стол")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                                        ForEach(boardCards) { card in
                                            CardView(card: card)
                                                .onTapGesture {
                                                    boardCards.removeAll { $0.id == card.id }
                                                }
                                        }
                                        
                                        if boardCards.count < 5 {
                                            Button(action: { showManualEdit = true }) {
                                                Image(systemName: "plus.circle")
                                                    .font(.title)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Кнопки действий
                HStack(spacing: 16) {
                    Button("Очистить все") {
                        detectedCards.removeAll()
                        holeCards.removeAll()
                        boardCards.removeAll()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Сохранить раздачу") {
                        saveHand()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(holeCards.count != 2)
                }
                .padding()
            }
            .navigationTitle("Распознавание карт")
            .onAppear {
                detectedCards = initialCards
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ручной ввод") {
                        showManualEdit = true
                    }
                }
            }
            .sheet(isPresented: $showManualEdit) {
                ManualCardInputView(
                    onCardAdded: { card in
                        if holeCards.count < 2 {
                            holeCards.append(card)
                        } else if boardCards.count < 5 {
                            boardCards.append(card)
                        }
                    }
                )
            }
        }
    }
    
    private func toggleCardSelection(_ card: Card) {
        // Если карта уже в руке или на столе, убираем её
        if let index = holeCards.firstIndex(where: { $0.id == card.id }) {
            holeCards.remove(at: index)
            return
        }
        if let index = boardCards.firstIndex(where: { $0.id == card.id }) {
            boardCards.remove(at: index)
            return
        }
        
        // Добавляем в руку, если там меньше 2 карт
        if holeCards.count < 2 {
            holeCards.append(card)
        } else if boardCards.count < 5 {
            // Иначе добавляем на стол
            boardCards.append(card)
        }
    }
    
    private func saveHand() {
        guard holeCards.count == 2 else { return }
        
        // Здесь можно сохранить раздачу в CoreData
        // Пока просто закрываем
        dismiss()
    }
}

struct CardView: View {
    let card: Card
    
    var body: some View {
        VStack(spacing: 2) {
            // Название карты над карточкой
            Text(card.displayName)
                .font(.headline)
                .bold()
                .foregroundColor(card.suit == .hearts || card.suit == .diamonds ? .red : .primary)
                .padding(.bottom, 4)
            
            // Визуализация карты
            VStack(spacing: 4) {
                Text(card.rank.rawValue)
                    .font(.title2)
                    .bold()
                    .foregroundColor(card.suit == .hearts || card.suit == .diamonds ? .red : .black)
                Text(card.suit.symbol)
                    .font(.system(size: 32))
                    .foregroundColor(card.suit == .hearts || card.suit == .diamonds ? .red : .black)
            }
            .frame(width: 70, height: 100)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(card.suit == .hearts || card.suit == .diamonds ? Color.red : Color.black, lineWidth: 2)
            )
            
            // Уверенность модели
            Text(String(format: "%.0f%%", card.confidence * 100))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
    }
}

struct ManualCardInputView: View {
    @Environment(\.dismiss) var dismiss
    let onCardAdded: (Card) -> Void
    
    @State private var selectedRank: CardRank = .ace
    @State private var selectedSuit: CardSuit = .spades
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Достоинство")) {
                    Picker("Достоинство", selection: $selectedRank) {
                        ForEach(CardRank.allCases, id: \.self) { rank in
                            Text(rank.rawValue).tag(rank)
                        }
                    }
                }
                
                Section(header: Text("Масть")) {
                    Picker("Масть", selection: $selectedSuit) {
                        ForEach(CardSuit.allCases, id: \.self) { suit in
                            Text(suit.symbol).tag(suit)
                        }
                    }
                }
                
                Section {
                    Button("Добавить карту") {
                        let card = Card(rank: selectedRank, suit: selectedSuit, confidence: 1.0)
                        onCardAdded(card)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Ручной ввод карты")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}

