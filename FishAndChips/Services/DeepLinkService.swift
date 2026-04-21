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
        // https://host/app/games/{gameId}  (SPA пользователя; совпадает с fishchips-web)
        if let gameId = DeepLinkParsing.gameIdFromWebPath(url: url) {
            debugLog("✅ DeepLink parsed (SPA /app/games): game(\(gameId))")
            return .game(gameId)
        }

        // pokertracker://game/{gameId}
        // fishandchips://game/{gameId}
        guard let host = url.host else {
            debugLog("❌ DeepLink: No host in URL: \(url)")
            return .none
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        debugLog("🔗 DeepLink parsing: host=\(host), path=\(pathComponents)")

        if host == "game" {
            if let gameIdString = pathComponents.first,
               let gameId = UUID(uuidString: gameIdString) {
                debugLog("✅ DeepLink parsed: game(\(gameId))")
                return .game(gameId)
            }
        }

        debugLog("❌ DeepLink: Unable to parse URL: \(url)")
        return .none
    }
}

/// ObservableObject для управления deep linking через всё приложение
class DeepLinkService: ObservableObject {
    @Published var activeDeepLink: DeepLink = .none
    @Published var isLoadingGame = false
    @Published var loadError: String?
    
    func handleURL(_ url: URL) {
        debugLog("🔗 DeepLinkService: Handling URL: \(url)")
        let deepLink = DeepLink.parse(from: url)
        
        // Ссылка на игру: локальный кэш или pull с Supabase через SyncCoordinator
        if case .game(let gameId) = deepLink {
            Task {
                await handleGameDeepLink(gameId: gameId)
            }
        } else {
            activeDeepLink = deepLink
        }
    }
    
    private func handleGameDeepLink(gameId: UUID) async {
        debugLog("🔗 [DEEPLINK] Handling game deeplink: \(gameId)")
        
        // Проверяем, есть ли игра локально
        let persistence = PersistenceController.shared
        if let localGame = persistence.fetchGame(byId: gameId) {
            // Игра найдена локально
            let playerCount = (localGame.gameWithPlayers as? Set<GameWithPlayer>)?.count ?? 0
            debugLog("✅ [DEEPLINK] Game \(gameId) found locally with \(playerCount) players")
            
            await MainActor.run {
                activeDeepLink = .game(gameId)
            }
            return
        }
        
        debugLog("🔄 [DEEPLINK] Game \(gameId) not found locally, fetching from Supabase...")
        await MainActor.run {
            isLoadingGame = true
            loadError = nil
        }
        
        do {
            if let fetchedGame = try await SyncCoordinator.shared.fetchGame(byId: gameId) {
                let playerCount = (fetchedGame.gameWithPlayers as? Set<GameWithPlayer>)?.count ?? 0
                debugLog("✅ [DEEPLINK] Game \(gameId) fetched with \(playerCount) players")
                
                await MainActor.run {
                    isLoadingGame = false
                    activeDeepLink = .game(gameId)
                }
                
                if playerCount == 0 {
                    debugLog("⚠️ [DEEPLINK] WARNING: Game has NO players after fetch.")
                }
            } else {
                await MainActor.run {
                    isLoadingGame = false
                    loadError = "Игра не найдена. Возможно, она была удалена или ссылка устарела."
                }
                debugLog("❌ [DEEPLINK] Game \(gameId) not found on server")
            }
        } catch {
            await MainActor.run {
                isLoadingGame = false
                
                loadError = "Ошибка загрузки игры. Проверьте подключение к интернету и что игра публична или вы участник."
            }
            debugLog("❌ [DEEPLINK] Error fetching game \(gameId): \(error)")
            debugLog("❌ [DEEPLINK] Error details: \(error.localizedDescription)")
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
