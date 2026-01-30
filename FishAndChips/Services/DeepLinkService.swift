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
    
    func handleURL(_ url: URL) {
        print("🔗 DeepLinkService: Handling URL: \(url)")
        activeDeepLink = DeepLink.parse(from: url)
    }
    
    func clearDeepLink() {
        activeDeepLink = .none
    }
}
