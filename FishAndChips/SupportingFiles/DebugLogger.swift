//
//  DebugLogger.swift
//  FishAndChips
//

import Foundation

/// Logs only in DEBUG builds — avoids exposing credentials in release
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}
