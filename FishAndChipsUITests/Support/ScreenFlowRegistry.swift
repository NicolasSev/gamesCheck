import Foundation
import XCTest

/// Реестр посещённых экранов + запись `screenflow.json`.
final class ScreenFlowRegistry {
    private(set) var entries: [ScreenFlowEntry] = []
    private var visitedScreenIds = Set<String>()
    private let artifactsRoot: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    init() {
        self.artifactsRoot = ScreenshotCapture.resolveArtifactsRoot()
    }

    var artifactsDirectory: URL { artifactsRoot }

    /// Возвращает `true`, если снимок новый (первый раз для `screen_id`).
    func shouldCapture(screenId: String) -> Bool {
        !visitedScreenIds.contains(screenId)
    }

    func markVisited(screenId: String) {
        visitedScreenIds.insert(screenId)
    }

    func append(
        order: Int,
        screenId: String,
        title: String,
        screenshotFile: String,
        parentScreenId: String?,
        navigationAction: String,
        screenType: ScreenFlowScreenType,
        notes: String? = nil
    ) {
        let entry = ScreenFlowEntry(
            order: order,
            screen_id: screenId,
            screen_title: title,
            screenshot: screenshotFile,
            parent_screen_id: parentScreenId,
            navigation_action: navigationAction,
            screen_type: screenType.rawValue,
            notes: notes
        )
        entries.append(entry)
    }

    func writeManifest() throws {
        try FileManager.default.createDirectory(at: artifactsRoot, withIntermediateDirectories: true)
        let url = artifactsRoot.appendingPathComponent("screenflow.json")
        let data = try encoder.encode(entries)
        try data.write(to: url, options: .atomic)
    }
}
