//
//  PerformanceMonitor.swift
//  FishAndChips
//
//  Phase 2: Измерение производительности операций
//

import Foundation

enum PerformanceMonitor {
    /// Измерить время выполнения асинхронной операции
    static func measure<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let start = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(start)
        debugLog("⏱️ [\(operation)] took \(String(format: "%.2f", duration))s")
        return result
    }

    /// Синхронный вариант
    static func measureSync<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let start = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(start)
        debugLog("⏱️ [\(operation)] took \(String(format: "%.2f", duration))s")
        return result
    }
}
