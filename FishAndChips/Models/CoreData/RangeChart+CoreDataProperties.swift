import Foundation
import CoreData

extension RangeChart {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<RangeChart> {
        NSFetchRequest<RangeChart>(entityName: "RangeChart")
    }

    @NSManaged public var id: UUID
    @NSManaged public var userId: UUID
    @NSManaged public var position: String
    @NSManaged public var selectedHandsJson: String
    @NSManaged public var updatedAt: Date
    @NSManaged public var dirty: Bool
}
