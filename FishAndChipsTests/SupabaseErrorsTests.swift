import Foundation
import Testing
@testable import FishAndChips

struct SupabaseErrorsTests {

    @Test func error_isRetryable_networkError() async throws {
        let error = SupabaseServiceError.networkError(underlying: URLError(.notConnectedToInternet))
        #expect(error.isRetryable == true)
        #expect(error.retryDelay == 2.0)
    }

    @Test func error_isRetryable_rateLimited() async throws {
        let error = SupabaseServiceError.rateLimited(retryAfter: 10.0)
        #expect(error.isRetryable == true)
        #expect(error.retryDelay == 10.0)
    }

    @Test func error_isRetryable_rateLimitedNoRetryAfter() async throws {
        let error = SupabaseServiceError.rateLimited(retryAfter: nil)
        #expect(error.isRetryable == true)
        #expect(error.retryDelay == 5.0)
    }

    @Test func error_isNotRetryable_notAuthenticated() async throws {
        let error = SupabaseServiceError.notAuthenticated
        #expect(error.isRetryable == false)
    }

    @Test func error_isNotRetryable_conflict() async throws {
        let error = SupabaseServiceError.conflict(message: "duplicate key")
        #expect(error.isRetryable == false)
    }

    @Test func error_isRetryable_serviceUnavailable() async throws {
        let error = SupabaseServiceError.serverError(statusCode: 503, message: "Service Unavailable")
        #expect(error.isRetryable == true)
        #expect(error.retryDelay == 3.0)
    }

    @Test func error_isNotRetryable_otherServerError() async throws {
        let error = SupabaseServiceError.serverError(statusCode: 500, message: "Internal Server Error")
        #expect(error.isRetryable == false)
    }

    @Test func error_localizedDescriptions() async throws {
        #expect(SupabaseServiceError.notAuthenticated.errorDescription?.contains("авториза") == true)
        #expect(SupabaseServiceError.rateLimited(retryAfter: nil).errorDescription?.contains("много запросов") == true)

        let notFound = SupabaseServiceError.notFound(table: "games", id: UUID())
        #expect(notFound.errorDescription?.contains("не найден") == true)
    }
}
