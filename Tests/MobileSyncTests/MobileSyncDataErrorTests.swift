import Foundation
import Shared
import XCTest

@testable import MobileSync

final class MobileSyncDataErrorTests: XCTestCase {
  func testMapsSessionResetToSessionResetInProgress() {
    let error = bridgedError(SessionResetInProgressException())

    guard case .sessionResetInProgress = MobileSyncDataError(bridgedError: error) else {
      return XCTFail("Expected a session reset")
    }
  }

  func testMapsOtherFailuresToFailed() {
    let error = bridgedError(KotlinIllegalStateException(message: "database is locked"))

    guard case .failed(let underlying) = MobileSyncDataError(bridgedError: error) else {
      return XCTFail("Expected a failure")
    }
    XCTAssertEqual(underlying as NSError, error)
  }

  func testCategoryNamesTheKotlinExceptionWithoutItsMessage() {
    let error = MobileSyncDataError(
      bridgedError: bridgedError(KotlinIllegalArgumentException(message: "Private note text")))

    XCTAssertEqual(error.category, "SharedKotlinIllegalArgumentException")
  }

  func testCategoryNamesTheDomainAndCodeOfOtherErrors() {
    let error = MobileSyncDataError(bridgedError: NSError(domain: NSCocoaErrorDomain, code: 640))

    XCTAssertEqual(error.category, "\(NSCocoaErrorDomain)#640")
  }

  func testBridgingMapsKotlinCancellationToSwiftCancellation() {
    let error = bridgedError(KotlinCancellationException(message: "Job was cancelled"))

    XCTAssertTrue(dataError(bridging: error) is CancellationError)
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
