//
//  PlayerClaim+CoreDataClass.swift
//  PokerCardRecognizer
//

import Foundation
import CoreData

@objc(PlayerClaim)
public class PlayerClaim: NSManagedObject {
    /// `scope == "bulk"` (сервер).
    var isBulk: Bool {
        String(scope ?? "single") == "bulk"
    }
}
