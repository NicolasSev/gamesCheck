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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
