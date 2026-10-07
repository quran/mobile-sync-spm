import Foundation
import Shared
import XCTest

@testable import MobileSync

final class MobileSyncDatabaseErrorTests: XCTestCase {
  func testMapsKotlinStorageFullAndPreservesUnderlyingError() {
    let error = bridgedError(
      DatabaseStorageFullException(cause: KotlinException(message: "database or disk is full")))

    guard case .storageFull(let underlyingError) = MobileSyncDatabaseError(bridgedError: error)
    else {
      return XCTFail("Expected storage full")
    }
    XCTAssertEqual(underlyingError as NSError, error)
  }

  func testMapsOtherKotlinFailuresToOpenFailed() {
    let error = bridgedError(KotlinException(message: "unable to open database file"))

    guard case .openFailed(let underlyingError) = MobileSyncDatabaseError(bridgedError: error)
    else {
      return XCTFail("Expected open failure")
    }
    XCTAssertEqual(underlyingError as NSError, error)
  }

  private func bridgedError(_ exception: KotlinException) -> NSError {
    NSError(
      domain: "KotlinException",
      code: 0,
      userInfo: [
        "KotlinException": exception,
        NSLocalizedDescriptionKey: exception.message ?? "",
      ]
    )
  }
}
