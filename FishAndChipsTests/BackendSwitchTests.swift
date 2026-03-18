import Foundation
import Testing
@testable import FishAndChips

struct BackendSwitchTests {

    @Test func backendSwitch_fullLifecycle() async throws {
        // 1. Reset to default
        UserDefaults.standard.removeObject(forKey: "activeBackend")
        #expect(BackendSwitch.isCloudKit == true)
        #expect(BackendSwitch.isSupabase == false)

        // 2. Switch to Supabase
        BackendSwitch.switchToSupabase()
        #expect(BackendSwitch.isSupabase == true)
        #expect(BackendSwitch.isCloudKit == false)
        #expect(BackendSwitch.active == .supabase)
        #expect(UserDefaults.standard.string(forKey: "activeBackend") == "supabase")

        // 3. Switch back to CloudKit
        BackendSwitch.switchToCloudKit()
        #expect(BackendSwitch.isCloudKit == true)
        #expect(BackendSwitch.isSupabase == false)
        #expect(UserDefaults.standard.string(forKey: "activeBackend") == "cloudKit")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "activeBackend")
    }
}
