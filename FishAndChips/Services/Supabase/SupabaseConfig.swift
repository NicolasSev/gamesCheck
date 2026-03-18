import Foundation
import Supabase

enum SupabaseConfig {
    // MARK: - Environment

    /// Supabase Project URL из Info.plist или Environment
    static var url: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlString) else {
            #if DEBUG
            return URL(string: "https://YOUR_PROJECT_ID.supabase.co")!
            #else
            fatalError("SUPABASE_URL not configured in Info.plist")
            #endif
        }
        return url
    }

    /// Supabase Anon Key из Info.plist или Environment
    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            #if DEBUG
            return "YOUR_ANON_KEY"
            #else
            fatalError("SUPABASE_ANON_KEY not configured in Info.plist")
            #endif
        }
        return key
    }

    // MARK: - Client

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey
    )
}
