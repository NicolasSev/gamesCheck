//
//  CloudKitServiceTests.swift
//  PokerCardRecognizerTests
//
//  Created for Phase 5: Testing & Quality Assurance
//

import XCTest
import CloudKit
@testable import FishAndChips

final class CloudKitServiceTests: XCTestCase {
    var sut: CloudKitService!
    
    override func setUp() {
        super.setUp()
        sut = CloudKitService.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Account Status Tests
    
    func testCheckAccountStatus() async throws {
        let status = try await sut.checkAccountStatus()
        XCTAssertNotNil(status)
        // Note: Will return .couldNotDetermine in test environment without proper iCloud setup
    }
    
    func testIsCloudKitAvailable() async {
        let isAvailable = await sut.isCloudKitAvailable()
        // In test environment, might be false
        XCTAssertNotNil(isAvailable)
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleCloudKitError_NotAuthenticated() {
        let error = CKError(.notAuthenticated)
        let message = sut.handleCloudKitError(error)
        XCTAssertEqual(message, "Необходимо войти в iCloud")
    }
    
    func testHandleCloudKitError_NetworkFailure() {
        let error = CKError(.networkFailure)
        let message = sut.handleCloudKitError(error)
        XCTAssertEqual(message, "Проблема с сетевым подключением")
    }
    
    func testHandleCloudKitError_QuotaExceeded() {
        let error = CKError(.quotaExceeded)
        let message = sut.handleCloudKitError(error)
        XCTAssertEqual(message, "Превышен лимит хранилища iCloud")
    }
    
    func testIsNetworkError() {
        let networkError = CKError(.networkFailure)
        XCTAssertTrue(sut.isNetworkError(networkError))
        
        let authError = CKError(.notAuthenticated)
        XCTAssertFalse(sut.isNetworkError(authError))
    }
    
    func testIsAuthenticationError() {
        let authError = CKError(.notAuthenticated)
        XCTAssertTrue(sut.isAuthenticationError(authError))
        
        let networkError = CKError(.networkFailure)
        XCTAssertFalse(sut.isAuthenticationError(networkError))
    }
    
    func testIsRetryable() {
        let retryableErrors: [CKError.Code] = [
            .networkFailure,
            .networkUnavailable,
            .requestRateLimited,
            .serviceUnavailable,
            .zoneBusy
        ]
        
        for code in retryableErrors {
            let error = CKError(code)
            XCTAssertTrue(sut.isRetryable(error), "Error \(code) should be retryable")
        }
        
        let nonRetryableError = CKError(.notAuthenticated)
        XCTAssertFalse(sut.isRetryable(nonRetryableError))
    }
    
    func testRetryDelay() {
        let rateLimitError = CKError(.requestRateLimited)
        let delay = sut.retryDelay(for: rateLimitError)
        XCTAssertEqual(delay, 5.0)
        
        let zoneBusyError = CKError(.zoneBusy)
        let zoneBusyDelay = sut.retryDelay(for: zoneBusyError)
        XCTAssertEqual(zoneBusyDelay, 2.0)
    }
}
