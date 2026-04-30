import Testing
@testable import FishAndChips

/// Realtime-подключение не поднимаем в юнит-тестах (сеть / JWT).
struct PlayerMergeListenerServiceTests {

    @Test @MainActor
    func stopListening_when_never_started_does_not_crash() async throws {
        await PlayerMergeListenerService.shared.stopListening()
    }
}
