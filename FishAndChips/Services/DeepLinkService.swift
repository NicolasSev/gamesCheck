//
//  DeepLinkService.swift
//  FishAndChips
//
//  Created for deep linking support
//

import Foundation
import SwiftUI

enum DeepLink: Equatable {
    case game(UUID)
    case none
    
    static func parse(from url: URL) -> DeepLink {
        // pokertracker://game/{gameId}
        // fishandchips://game/{gameId}
        
        guard let host = url.host else {
            print("❌ DeepLink: No host in URL: \(url)")
            return .none
        }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        print("🔗 DeepLink parsing: host=\(host), path=\(pathComponents)")
        
        // Check for game deep link
        if host == "game" {
            // pokertracker://game/{gameId}
            if let gameIdString = pathComponents.first,
               let gameId = UUID(uuidString: gameIdString) {
                print("✅ DeepLink parsed: game(\(gameId))")
                return .game(gameId)
            }
        }
        
        print("❌ DeepLink: Unable to parse URL: \(url)")
        return .none
    }
}

/// ObservableObject для управления deep linking через всё приложение
class DeepLinkService: ObservableObject {
    @Published var activeDeepLink: DeepLink = .none
    @Published var isLoadingGame = false
    @Published var loadError: String?
    
    func handleURL(_ url: URL) {
        print("🔗 DeepLinkService: Handling URL: \(url)")
        let deepLink = DeepLink.parse(from: url)
        
        // Если это ссылка на игру, проверяем её наличие и загружаем из CloudKit при необходимости
        if case .game(let gameId) = deepLink {
            Task {
                await handleGameDeepLink(gameId: gameId)
            }
        } else {
            activeDeepLink = deepLink
        }
    }
    
    private func handleGameDeepLink(gameId: UUID) async {
        print("🔗 [DEEPLINK] Handling game deeplink: \(gameId)")
        
        // Проверяем, есть ли игра локально
        let persistence = PersistenceController.shared
        if let localGame = persistence.fetchGame(byId: gameId) {
            // Игра найдена локально
            let playerCount = (localGame.gameWithPlayers as? Set<GameWithPlayer>)?.count ?? 0
            print("✅ [DEEPLINK] Game \(gameId) found locally with \(playerCount) players")
            
            await MainActor.run {
                activeDeepLink = .game(gameId)
            }
            return
        }
        
        // Игры нет локально - загружаем из CloudKit
        print("🔄 [DEEPLINK] Game \(gameId) not found locally, fetching from CloudKit...")
        await MainActor.run {
            isLoadingGame = true
            loadError = nil
        }
        
        do {
            if let fetchedGame = try await CloudKitSyncService.shared.fetchGame(byId: gameId) {
                let playerCount = (fetchedGame.gameWithPlayers as? Set<GameWithPlayer>)?.count ?? 0
                print("✅ [DEEPLINK] Game \(gameId) fetched from CloudKit with \(playerCount) players")
                
                await MainActor.run {
                    isLoadingGame = false
                    activeDeepLink = .game(gameId)
                }
                
                if playerCount == 0 {
                    print("⚠️ [DEEPLINK] WARNING: Game has NO players! Check CloudKit sync.")
                }
            } else {
                await MainActor.run {
                    isLoadingGame = false
                    loadError = "Игра не найдена. Возможно, она была удалена или ссылка устарела."
                }
                print("❌ [DEEPLINK] Game \(gameId) not found in CloudKit")
            }
        } catch {
            await MainActor.run {
                isLoadingGame = false
                loadError = "Ошибка загрузки игры. Проверьте подключение к интернету."
            }
            print("❌ [DEEPLINK] Error fetching game \(gameId): \(error)")
            print("❌ [DEEPLINK] Error details: \(error.localizedDescription)")
        }
    }
    
    func clearDeepLink() {
        activeDeepLink = .none
        loadError = nil
    }
    
    func retryLoadGame() {
        if case .game(let gameId) = activeDeepLink {
            Task {
                await handleGameDeepLink(gameId: gameId)
            }
        }
    }
}
