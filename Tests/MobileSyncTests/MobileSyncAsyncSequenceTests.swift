import XCTest
@testable import MobileSync

final class MobileSyncAsyncSequenceTests: XCTestCase {
  func testForwardsValuesFromWrappedSequence() async throws {
    let source = AsyncStream<Int> { continuation in
      continuation.yield(1)
      continuation.yield(2)
      continuation.finish()
    }
    var iterator = MobileSyncAsyncSequence(source).makeAsyncIterator()

    let first = try await iterator.next()
    let second = try await iterator.next()
    let end = try await iterator.next()

    XCTAssertEqual(first, 1)
    XCTAssertEqual(second, 2)
    XCTAssertNil(end)
  }
}
