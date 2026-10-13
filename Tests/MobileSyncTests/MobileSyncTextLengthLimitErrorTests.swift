import Foundation
import Shared
import XCTest

@testable import MobileSync

final class MobileSyncTextLengthLimitErrorTests: XCTestCase {
  func testMapsShortNoteBody() throws {
    let error = bridgedError(
      TextLengthLimitException(field: .noteBody, bound: .tooShort, limit: 6, length: 2))

    let mapped = try XCTUnwrap(MobileSyncTextLengthLimitError(bridgedError: error))

    XCTAssertEqual(mapped.field, .noteBody)
    XCTAssertEqual(mapped.bound, .tooShort)
    XCTAssertEqual(mapped.limit, 6)
    XCTAssertEqual(mapped.length, 2)
  }

  func testMapsLongNoteBody() throws {
    let error = bridgedError(
      TextLengthLimitException(field: .noteBody, bound: .tooLong, limit: 10000, length: 10005))

    let mapped = try XCTUnwrap(MobileSyncTextLengthLimitError(bridgedError: error))

    XCTAssertEqual(mapped.field, .noteBody)
    XCTAssertEqual(mapped.bound, .tooLong)
    XCTAssertEqual(mapped.limit, 10000)
    XCTAssertEqual(mapped.length, 10005)
  }

  func testMapsShortCollectionName() throws {
    let error = bridgedError(
      TextLengthLimitException(field: .collectionName, bound: .tooShort, limit: 1, length: 0))

    let mapped = try XCTUnwrap(MobileSyncTextLengthLimitError(bridgedError: error))

    XCTAssertEqual(mapped.field, .collectionName)
    XCTAssertEqual(mapped.bound, .tooShort)
    XCTAssertEqual(mapped.limit, 1)
    XCTAssertEqual(mapped.length, 0)
  }

  func testMapsLongCollectionName() throws {
    let error = bridgedError(
      TextLengthLimitException(field: .collectionName, bound: .tooLong, limit: 255, length: 300))

    let mapped = try XCTUnwrap(MobileSyncTextLengthLimitError(bridgedError: error))

    XCTAssertEqual(mapped.field, .collectionName)
    XCTAssertEqual(mapped.bound, .tooLong)
    XCTAssertEqual(mapped.limit, 255)
    XCTAssertEqual(mapped.length, 300)
  }

  func testIgnoresOtherKotlinExceptions() {
    let error = bridgedError(KotlinIllegalArgumentException(message: "Note body is invalid"))

    XCTAssertNil(MobileSyncTextLengthLimitError(bridgedError: error))
  }

  func testIgnoresErrorsWithoutAKotlinException() {
    XCTAssertNil(MobileSyncTextLengthLimitError(bridgedError: CancellationError()))
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
