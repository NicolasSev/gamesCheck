import Foundation
import XCTest

/// Связывает нумерацию PNG, манифест и дедупликацию по `screen_id`.
final class UIAuditCoordinator {
    private var orderCounter = 0
    private let registry = ScreenFlowRegistry()
    private let capture: ScreenshotCapture

    init(testCase: XCTestCase) {
        self.capture = ScreenshotCapture(testCase: testCase)
    }

    var artifactsRoot: URL { registry.artifactsDirectory }

    /// Записать уникальный экран: скрин + строка манифеста.
    func recordIfNew(
        screenId: String,
        title: String,
        parentScreenId: String?,
        navigationAction: String,
        screenType: ScreenFlowScreenType,
        notes: String? = nil
    ) throws {
        guard registry.shouldCapture(screenId: screenId) else { return }
        registry.markVisited(screenId: screenId)
        orderCounter += 1
        let file = try capture.savePNG(order: orderCounter, screenId: screenId)
        registry.append(
            order: orderCounter,
            screenId: screenId,
            title: title,
            screenshotFile: file,
            parentScreenId: parentScreenId,
            navigationAction: navigationAction,
            screenType: screenType,
            notes: notes
        )
    }

    func finish() throws {
        try registry.writeManifest()
    }
}
