import Foundation
import Supabase
import PostgREST

/// Обёртка над Supabase Client для CRUD-операций с обработкой ошибок и retry
final class SupabaseService: @unchecked Sendable {
    static let shared = SupabaseService()

    private let client: SupabaseClient
    private let maxRetries = 3

    private init(client: SupabaseClient = SupabaseConfig.client) {
        self.client = client
    }

    // MARK: - For testing
    init(testClient: SupabaseClient) {
        self.client = testClient
        debugLog("SupabaseService init with test client")
    }

    // MARK: - Access to client subsystems

    var auth: AuthClient { client.auth }
    var realtime: RealtimeClientV2 { client.realtimeV2 }

    // MARK: - Availability

    func isAvailable() async -> Bool {
        do {
            let session = try await client.auth.session
            return session.user.id != UUID()
        } catch {
            debugLog("Supabase not available: \(error)")
            return false
        }
    }

    func currentUserId() async -> UUID? {
        try? await client.auth.session.user.id
    }

    // MARK: - INSERT

    func insert<T: Codable & Sendable>(
        table: String,
        values: T
    ) async throws -> T {
        try await withRetry {
            try await self.client
                .from(table)
                .insert(values)
                .select()
                .single()
                .execute()
                .value
        }
    }

    // MARK: - UPSERT

    func upsert<T: Codable & Sendable>(
        table: String,
        values: T
    ) async throws -> T {
        try await withRetry {
            try await self.client
                .from(table)
                .upsert(values)
                .select()
                .single()
                .execute()
                .value
        }
    }

    func batchUpsert<T: Codable & Sendable>(
        table: String,
        values: [T]
    ) async throws -> [T] {
        guard !values.isEmpty else { return [] }
        return try await withRetry {
            try await self.client
                .from(table)
                .upsert(values)
                .select()
                .execute()
                .value
        }
    }

    // MARK: - SELECT

    func fetchAll<T: Codable & Sendable>(
        table: String
    ) async throws -> [T] {
        try await withRetry {
            try await self.client
                .from(table)
                .select()
                .execute()
                .value
        }
    }

    func fetchById<T: Codable & Sendable>(
        table: String,
        id: UUID
    ) async throws -> T? {
        let results: [T] = try await withRetry {
            try await self.client
                .from(table)
                .select()
                .eq("id", value: id)
                .limit(1)
                .execute()
                .value
        }
        return results.first
    }

    func fetchByColumn<T: Codable & Sendable>(
        table: String,
        column: String,
        value: some URLQueryRepresentable
    ) async throws -> [T] {
        try await withRetry {
            try await self.client
                .from(table)
                .select()
                .eq(column, value: value)
                .execute()
                .value
        }
    }

    func fetchByFilter<T: Codable & Sendable>(
        table: String,
        build: (PostgrestFilterBuilder) -> PostgrestTransformBuilder
    ) async throws -> [T] {
        try await withRetry {
            let query = self.client.from(table).select()
            return try await build(query).execute().value
        }
    }

    func fetchSince<T: Codable & Sendable>(
        table: String,
        since: Date,
        column: String = "updated_at"
    ) async throws -> [T] {
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: since)
        return try await withRetry {
            try await self.client
                .from(table)
                .select()
                .gte(column, value: dateString)
                .execute()
                .value
        }
    }

    // MARK: - UPDATE

    func update<T: Codable & Sendable>(
        table: String,
        id: UUID,
        values: T
    ) async throws -> T {
        try await withRetry {
            try await self.client
                .from(table)
                .update(values)
                .eq("id", value: id)
                .select()
                .single()
                .execute()
                .value
        }
    }

    // MARK: - DELETE

    func delete(table: String, id: UUID) async throws {
        try await withRetry {
            try await self.client
                .from(table)
                .delete()
                .eq("id", value: id)
                .execute()
        }
    }

    func deleteByColumn(
        table: String,
        column: String,
        value: some URLQueryRepresentable
    ) async throws {
        try await withRetry {
            try await self.client
                .from(table)
                .delete()
                .eq(column, value: value)
                .execute()
        }
    }

    // MARK: - RPC (Database Functions)

    func rpc<T: Codable & Sendable>(
        _ function: String,
        params: some Codable & Sendable
    ) async throws -> T {
        try await withRetry {
            try await self.client
                .rpc(function, params: params)
                .execute()
                .value
        }
    }

    func rpc(_ function: String, params: some Codable & Sendable) async throws {
        try await withRetry {
            try await self.client
                .rpc(function, params: params)
                .execute()
        }
    }

    // MARK: - Retry Logic

    private func withRetry<T>(
        attempt: Int = 0,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            let serviceError = mapError(error)
            if serviceError.isRetryable && attempt < maxRetries {
                let delay = serviceError.retryDelay * Double(attempt + 1)
                debugLog("Supabase retry \(attempt + 1)/\(maxRetries) after \(delay)s: \(serviceError.localizedDescription)")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await withRetry(attempt: attempt + 1, operation: operation)
            }
            throw serviceError
        }
    }

    // MARK: - Error Mapping

    func mapError(_ error: Error) -> SupabaseServiceError {
        if let urlError = error as? URLError {
            return .networkError(underlying: urlError)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .networkError(underlying: error)
        }

        let description = error.localizedDescription.lowercased()
        if description.contains("jwt") || description.contains("auth") || description.contains("401") {
            return .notAuthenticated
        }
        if description.contains("409") || description.contains("conflict") || description.contains("duplicate") {
            return .conflict(message: error.localizedDescription)
        }
        if description.contains("429") || description.contains("rate") {
            return .rateLimited(retryAfter: nil)
        }
        if description.contains("404") || description.contains("not found") {
            return .notFound(table: "unknown", id: UUID())
        }

        return .unknown(underlying: error)
    }
}
