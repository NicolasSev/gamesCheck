import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Добавляем тестовые игры в Core Data
        for _ in 0..<10 {
            let newGame = Game(context: viewContext)
            newGame.timestamp = Date()
            newGame.gameId = UUID()
            newGame.softDeleted = false
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FishAndChips") // Убедись, что имя совпадает с .xcdatamodeld
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Включаем lightweight migration для автоматической миграции совместимых изменений
            let description = container.persistentStoreDescriptions.first
            description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: NSError?
        var storeURL: URL?
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                loadError = error
                storeURL = description.url
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        // Если была ошибка миграции схемы (134110), удаляем старую базу и пытаемся загрузить снова
        if let error = loadError, error.code == 134110, let url = storeURL {
            debugLog("Core Data migration error detected (code 134110). Removing old database...")
            removeOldDatabaseFiles(at: url)
            
            // Пытаемся загрузить снова после удаления файлов
            let retrySemaphore = DispatchSemaphore(value: 0)
            var retryError: NSError?
            
            container.loadPersistentStores { _, error in
                if let error = error as NSError? {
                    retryError = error
                } else {
                    debugLog("Successfully recreated database after migration")
                }
                retrySemaphore.signal()
            }
            
            retrySemaphore.wait()
            
            if let error = retryError {
                fatalError("Failed to recreate database after migration error: \(error), \(error.userInfo)")
            }
        } else if let error = loadError {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }
    
    private func removeOldDatabaseFiles(at url: URL) {
        let fileManager = FileManager.default
        let storeDirectory = url.deletingLastPathComponent()
        let storeName = url.deletingPathExtension().lastPathComponent
        
        // Удаляем все файлы базы данных (sqlite, sqlite-wal, sqlite-shm)
        do {
            let storeFiles = try fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
            for file in storeFiles {
                let fileName = file.deletingPathExtension().lastPathComponent
                if fileName == storeName && (file.pathExtension == "sqlite" || file.pathExtension == "sqlite-wal" || file.pathExtension == "sqlite-shm") {
                    try fileManager.removeItem(at: file)
                    debugLog("Removed old database file: \(file.lastPathComponent)")
                }
            }
        } catch {
            debugLog("Warning: Failed to remove some old database files: \(error)")
        }
    }
}

// MARK: - Convenience Save
extension PersistenceController {
    func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            debugLog("Error saving context: \(error)")
        }
    }
}

