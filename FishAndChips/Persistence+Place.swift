import CoreData

extension PersistenceController {
    func fetchAllPlaces(context: NSManagedObjectContext? = nil) -> [Place] {
        let ctx = context ?? container.viewContext
        let request: NSFetchRequest<Place> = Place.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Place.name, ascending: true)]
        do {
            return try ctx.fetch(request)
        } catch {
            debugLog("Error fetching places: \(error)")
            return []
        }
    }

    func fetchPlace(byId placeId: UUID, context: NSManagedObjectContext? = nil) -> Place? {
        let ctx = context ?? container.viewContext
        let request: NSFetchRequest<Place> = Place.fetchRequest()
        request.predicate = NSPredicate(format: "placeId == %@", placeId as CVarArg)
        request.fetchLimit = 1
        do {
            return try ctx.fetch(request).first
        } catch {
            debugLog("Error fetching place by id: \(error)")
            return nil
        }
    }

    func fetchPlace(byName name: String, context: NSManagedObjectContext? = nil) -> Place? {
        let ctx = context ?? container.viewContext
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request: NSFetchRequest<Place> = Place.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", trimmed)
        request.fetchLimit = 1
        do {
            return try ctx.fetch(request).first
        } catch {
            debugLog("Error fetching place by name: \(error)")
            return nil
        }
    }

    /// Создаёт место локально и в Supabase. Возвращает локальный объект Place.
    @discardableResult
    func createPlace(name: String, createdByUserId: UUID?) -> Place? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let existing = fetchPlace(byName: trimmed) {
            return existing
        }

        let context = container.viewContext
        let place = Place(context: context)
        place.placeId = UUID()
        place.name = trimmed
        place.createdByUserId = createdByUserId
        place.createdAt = Date()
        saveContext()

        Task {
            await SyncCoordinator.shared.quickSyncPlace(place)
        }

        return place
    }
}
