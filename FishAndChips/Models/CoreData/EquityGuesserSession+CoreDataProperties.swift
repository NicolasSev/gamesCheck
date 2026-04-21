import Foundation
import CoreData

extension EquityGuesserSession {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<EquityGuesserSession> {
        NSFetchRequest<EquityGuesserSession>(entityName: "EquityGuesserSession")
    }

    @NSManaged public var id: UUID
    @NSManaged public var userId: UUID
    @NSManaged public var startedAt: Date
    @NSManaged public var completedAt: Date?
    @NSManaged public var configJSON: String
    @NSManaged public var totalScore: Int32
    @NSManaged public var roundsPlayed: Int32
    @NSManaged public var averageDelta: Double
    @NSManaged public var bestStreak: Int32
    @NSManaged public var syncedAt: Date?
    @NSManaged public var rounds: NSSet?
}
