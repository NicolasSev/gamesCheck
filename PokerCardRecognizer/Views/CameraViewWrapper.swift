//
//  CameraViewWrapper.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import SwiftUI

struct CameraViewWrapper: View {
    @StateObject private var coordinator = CardDetectionCoordinator()
    @State private var showCardRecognition = false
    
    var body: some View {
        ZStack {
            CameraView(coordinator: coordinator)
            
            // Кнопка для перехода к управлению картами
            if !coordinator.detectedCards.isEmpty {
                VStack {
                    Spacer()
                    Button(action: {
                        showCardRecognition = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Управление картами (\(coordinator.detectedCards.count))")
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showCardRecognition) {
            CardRecognitionView(initialCards: coordinator.detectedCards)
        }
    }
}

