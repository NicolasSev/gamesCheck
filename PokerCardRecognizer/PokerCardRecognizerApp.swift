//
//  PokerCardRecognizerApp.swift
//  PokerCardRecognizer
//
//  Created by Николас on 24.03.2025.
//

import SwiftUI

@main
struct PokerCardRecognizerApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        // Миграция игр (Task 1.2) — один раз после обновления модели
        let hasMigratedGames = UserDefaults.standard.bool(forKey: "hasMigratedGamesToV2")
        if !hasMigratedGames {
            persistenceController.migrateExistingGames()
            UserDefaults.standard.set(true, forKey: "hasMigratedGamesToV2")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
