//
//  JoinGameByCodeSheet.swift
//  FishAndChips
//
//  Created for joining games by code
//

import SwiftUI

struct JoinGameByCodeSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deepLinkService: DeepLinkService
    
    @State private var gameCode: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Иконка
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                // Заголовок
                VStack(spacing: 8) {
                    Text("Присоединиться к игре")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Вставьте код игры, которым с вами поделились")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Поле ввода кода
                VStack(alignment: .leading, spacing: 8) {
                    Text("Код игры")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("6566CB8E-6D9E-4C4A-A87F-...", text: $gameCode)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                // Ошибка
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Кнопка "Открыть игру"
                Button {
                    openGame()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isLoading ? "Поиск игры..." : "Открыть игру")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(gameCode.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(gameCode.isEmpty || isLoading)
                .padding(.horizontal)
                
                // Инструкция
                VStack(alignment: .leading, spacing: 12) {
                    Text("💡 Как получить код игры:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                                .foregroundColor(.white.opacity(0.7))
                            Text("Хост игры нажимает \"Поделиться ссылкой\"")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .foregroundColor(.white.opacity(0.7))
                            Text("Вы получаете сообщение с кодом игры")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("3.")
                                .foregroundColor(.white.opacity(0.7))
                            Text("Долгое нажатие на код → Скопировать")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("4.")
                                .foregroundColor(.white.opacity(0.7))
                            Text("Вставьте код в поле выше")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Присоединиться")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .background(
                Group {
                    if let image = UIImage(named: "casino-background") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.4),
                                        Color.black.opacity(0.6)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .ignoresSafeArea()
                            )
                    } else {
                        Color.black.ignoresSafeArea()
                    }
                }
            )
        }
    }
    
    private func openGame() {
        // Очистить ошибку
        errorMessage = nil
        isLoading = true
        
        // Проверить формат UUID
        guard let gameId = UUID(uuidString: gameCode.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Неверный формат кода. Код должен быть в формате UUID."
            isLoading = false
            return
        }
        
        // Проверить, существует ли игра
        guard let game = PersistenceController.shared.fetchGame(byId: gameId) else {
            errorMessage = "Игра не найдена. Убедитесь, что код правильный."
            isLoading = false
            return
        }
        
        print("✅ JoinGameByCodeSheet: Found game \(gameId), opening via DeepLinkService")
        
        // Использовать DeepLinkService для открытия игры
        deepLinkService.activeDeepLink = .game(gameId)
        
        // Закрыть sheet
        dismiss()
    }
}
