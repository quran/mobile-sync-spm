import Foundation
import Shared
import XCTest

@testable import MobileSync

final class MobileSyncCollectionErrorsTests: XCTestCase {
  func testMapsReadOnlyCollection() {
    let error = bridgedError(ReadOnlyCollectionException(id: "7"))

    XCTAssertEqual(
      MobileSyncReadOnlyCollectionError(bridgedError: error),
      MobileSyncReadOnlyCollectionError(id: "7"))
    XCTAssertNil(MobileSyncDuplicateCollectionNameError(bridgedError: error))
  }

  func testMapsDuplicateCollectionName() {
    let error = bridgedError(DuplicateCollectionNameException(name: "Study"))

    XCTAssertEqual(
      MobileSyncDuplicateCollectionNameError(bridgedError: error),
      MobileSyncDuplicateCollectionNameError(name: "Study"))
    XCTAssertNil(MobileSyncReadOnlyCollectionError(bridgedError: error))
  }

  func testIgnoresOtherKotlinExceptions() {
    let error = bridgedError(KotlinIllegalArgumentException(message: "Collection is invalid"))

    XCTAssertNil(MobileSyncReadOnlyCollectionError(bridgedError: error))
    XCTAssertNil(MobileSyncDuplicateCollectionNameError(bridgedError: error))
  }

  func testIgnoresErrorsWithoutAKotlinException() {
    XCTAssertNil(MobileSyncReadOnlyCollectionError(bridgedError: CancellationError()))
    XCTAssertNil(MobileSyncDuplicateCollectionNameError(bridgedError: CancellationError()))
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
