import Foundation
import XCTest

struct ScreenshotCapture {
    let screenshotsDirectory: URL
    let testCase: XCTestCase

    init(testCase: XCTestCase) {
        self.testCase = testCase
        let root = Self.resolveArtifactsRoot()
        self.screenshotsDirectory = root.appendingPathComponent("screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
    }

    /// Каталог `artifacts/ui-audit` (родитель screenshots + screenflow.json).
    static func resolveArtifactsRoot() -> URL {
        if let env = ProcessInfo.processInfo.environment["UI_AUDIT_ARTIFACTS_ROOT"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        // Как UITestCredentials: xcodebuild часто не передаёт env — пишем в gamesCheck/artifacts/ui-audit.
        let fromSources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let audit = fromSources.appendingPathComponent("artifacts/ui-audit", isDirectory: true)
        return audit
    }

    @discardableResult
    func savePNG(order: Int, screenId: String) throws -> String {
        let safe = screenId.replacingOccurrences(of: ".", with: "_")
        let filename = String(format: "%02d_%@.png", order, safe)
        let url = screenshotsDirectory.appendingPathComponent(filename)
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: url)
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
        return filename
    }
}
