import Foundation
import Shared
import XCTest

@testable import MobileSync

final class MobileSyncTextLengthLimitErrorTests: XCTestCase {
  func testMapsShortNoteBody() {
    let error = bridgedError(
      TextLengthLimitException(field: .noteBody, bound: .tooShort, limit: 6, length: 2))

    XCTAssertEqual(
      MobileSyncTextLengthLimitError(bridgedError: error),
      MobileSyncTextLengthLimitError(field: .noteBody, bound: .tooShort, limit: 6, length: 2))
  }

  func testMapsLongNoteBody() {
    let error = bridgedError(
      TextLengthLimitException(field: .noteBody, bound: .tooLong, limit: 10000, length: 10005))

    XCTAssertEqual(
      MobileSyncTextLengthLimitError(bridgedError: error),
      MobileSyncTextLengthLimitError(field: .noteBody, bound: .tooLong, limit: 10000, length: 10005))
  }

  func testMapsShortCollectionName() {
    let error = bridgedError(
      TextLengthLimitException(field: .collectionName, bound: .tooShort, limit: 1, length: 0))

    XCTAssertEqual(
      MobileSyncTextLengthLimitError(bridgedError: error),
      MobileSyncTextLengthLimitError(field: .collectionName, bound: .tooShort, limit: 1, length: 0))
  }

  func testMapsLongCollectionName() {
    let error = bridgedError(
      TextLengthLimitException(field: .collectionName, bound: .tooLong, limit: 255, length: 300))

    XCTAssertEqual(
      MobileSyncTextLengthLimitError(bridgedError: error),
      MobileSyncTextLengthLimitError(field: .collectionName, bound: .tooLong, limit: 255, length: 300))
  }

  func testMapsEveryKotlinFieldAndBound() throws {
    for field in TextLengthField.entries {
      for bound in TextLengthBound.entries {
        let error = bridgedError(TextLengthLimitException(field: field, bound: bound, limit: 1, length: 2))

        let mapped = try XCTUnwrap(
          MobileSyncTextLengthLimitError(bridgedError: error), "\(field.name) \(bound.name) is not mapped")
        XCTAssertEqual("\(mapped.field)".lowercased(), field.name.replacingOccurrences(of: "_", with: "").lowercased())
        XCTAssertEqual("\(mapped.bound)".lowercased(), bound.name.replacingOccurrences(of: "_", with: "").lowercased())
      }
    }
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
