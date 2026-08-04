import Foundation
import Shared
import XCTest

@testable import MobileSync

final class MobileSyncAuthenticationErrorTests: XCTestCase {
  func testMapsKotlinCancellationToSwiftCancellation() {
    let error = bridgedError(AuthenticationCancelledException(cause: nil))

    guard case .cancelled = MobileSyncAuthenticationError(bridgedError: error) else {
      return XCTFail("Expected cancellation")
    }
  }

  func testMapsKotlinNetworkFailureAndPreservesUnderlyingError() {
    let error = bridgedError(
      AuthenticationNetworkException(cause: KotlinException(message: "offline")))

    guard
      case .networkFailure(let underlyingError) = MobileSyncAuthenticationError(bridgedError: error)
    else {
      return XCTFail("Expected network failure")
    }
    XCTAssertEqual((underlyingError as NSError).localizedDescription, "offline")
  }

  func testMapsKotlinAuthenticationFailureAndPreservesUnderlyingError() {
    let error = bridgedError(
      AuthenticationFailedException(cause: KotlinException(message: "invalid grant")))

    guard
      case .authenticationFailed(let underlyingError) = MobileSyncAuthenticationError(
        bridgedError: error)
    else {
      return XCTFail("Expected authentication failure")
    }
    XCTAssertEqual((underlyingError as NSError).localizedDescription, "invalid grant")
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
