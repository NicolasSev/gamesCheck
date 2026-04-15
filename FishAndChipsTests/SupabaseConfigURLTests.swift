import Foundation
import Testing
@testable import FishAndChips

struct SupabaseConfigURLTests {
    private let canonicalHost = "uffgwdmwufqududpyhbg.supabase.co"

    @Test func normalizedURLString_knownTyposBecomeCanonicalHost() {
        let typos = [
            "https://uffgwdswufqududpyhbg.supabase.co",
            "https://uffgwfmwufqududpyhbg.supabase.co",
            "https://uffgwdmrufqwdudpyhbg.supabase.co",
            "https://uffgwdxwufqududpyhbg.supabase.co",
        ]
        for raw in typos {
            let normalized = SupabaseConfig.normalizedSupabaseURLString(raw)
            let u = URL(string: normalized)
            #expect(u?.host?.lowercased() == canonicalHost)
        }
    }
}
