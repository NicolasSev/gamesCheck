import Foundation

/// Элемент манифеста `artifacts/ui-audit/screenflow.json` (схема из UI-audit плана).
struct ScreenFlowEntry: Codable, Equatable {
    let order: Int
    let screen_id: String
    let screen_title: String
    let screenshot: String
    let parent_screen_id: String?
    let navigation_action: String
    let screen_type: String
    let notes: String?
}

enum ScreenFlowScreenType: String {
    case root
    case tab
    case detail
    case modal
    case sheet
    case dialog
    case form
    case empty_state
}
