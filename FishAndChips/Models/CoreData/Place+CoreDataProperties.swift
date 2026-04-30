import Foundation
import CoreData


extension Place {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Place> {
        return NSFetchRequest<Place>(entityName: "Place")
    }

    @NSManaged public var placeId: UUID
    @NSManaged public var name: String?
    @NSManaged public var createdByUserId: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var games: NSSet?

}

// MARK: Generated accessors for games
extension Place {

    @objc(addGamesObject:)
    @NSManaged public func addToGames(_ value: Game)

    @objc(removeGamesObject:)
    @NSManaged public func removeFromGames(_ value: Game)

    @objc(addGames:)
    @NSManaged public func addToGames(_ values: NSSet)

    @objc(removeGames:)
    @NSManaged public func removeFromGames(_ values: NSSet)

}

extension Place: Identifiable {}
