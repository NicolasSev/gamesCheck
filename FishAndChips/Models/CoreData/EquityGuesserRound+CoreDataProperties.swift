import Foundation
import CoreData

extension EquityGuesserRound {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<EquityGuesserRound> {
        NSFetchRequest<EquityGuesserRound>(entityName: "EquityGuesserRound")
    }

    @NSManaged public var id: UUID
    @NSManaged public var roundIndex: Int32
    @NSManaged public var scenarioJSON: String
    @NSManaged public var userGuess: Double
    @NSManaged public var actualEquity: Double
    @NSManaged public var delta: Double
    @NSManaged public var score: Int32
    @NSManaged public var accuracyLabel: String
    @NSManaged public var timeSpentMs: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var session: EquityGuesserSession?
}
