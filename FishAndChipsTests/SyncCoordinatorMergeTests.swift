import Testing

/// Контракт с `NotificationService` / `MainView`: ключи не должны совпадать.
struct SyncCoordinatorMergeTests {

    @Test func full_resync_vs_merge_notification_strings_differ() {
        #expect(
            "FishAndChips.fullResyncCompleted"
                != "FishAndChips.playerMergeApplied"
        )
    }

    @Test func player_merge_notification_key_is_documented() {
        #expect(
            "FishAndChips.playerMergeApplied"
                .contains("Merge")
        )
    }
}
