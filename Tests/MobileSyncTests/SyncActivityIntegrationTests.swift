import Foundation
import MobileSync
import MobileSyncTestSupport
import XCTest

// Sync activity through the public API, with no one signed in, so no sync reaches a server.
final class SyncActivityIntegrationTests: XCTestCase {
  private let database = MobileSyncTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.reset()
  }

  override func tearDown() async throws {
    try await database.reset()
    try await super.tearDown()
  }

  func testSyncStatusIsIdleWithoutASync() async throws {
    let status = try await database.quranDataService.syncStatusSequence().first { _ in true }

    XCTAssertEqual(status, .idle)
  }

  func testSyncHistoryIsEmptyWithoutASync() async throws {
    let runs = try await database.quranDataService.syncHistorySequence().first { _ in true }

    XCTAssertEqual(runs, [])
  }

  func testHeldItemsAreEmptyWithoutASync() async throws {
    // Only a push holds an item.
    try await database.quranDataService.createNote(
      body: "Reflection", startSura: 2, startAyah: 1, endSura: 2, endAyah: 5, timestamp: date(100))

    let held = try await database.quranDataService.heldItemsSequence().first { _ in true }

    XCTAssertEqual(held, [])
  }

  func testUnsyncedItemsSequenceCountsANewNoteAsPending() async throws {
    let service = database.quranDataService
    var counts: [MobileSyncUnsyncedItemCounts] = []
    for try await count in service.unsyncedItemsSequence() {
      counts.append(count)
      guard counts.count == 1 else {
        break
      }
      try await service.createNote(
        body: "Reflection", startSura: 2, startAyah: 1, endSura: 2, endAyah: 5, timestamp: Date())
    }

    XCTAssertEqual(counts, [.init(pending: 0, held: 0), .init(pending: 1, held: 0)])
  }

  // MARK: Stopping collectors

  func testFirstLeavesLiveObserversUpdating() async throws {
    let service = database.quranDataService
    for _ in 0..<3 {
      _ = try await service.heldItemsSequence().first { _ in true }
      _ = try await service.unsyncedItemsSequence().first { _ in true }
    }

    try await assertLiveObserverCountsEveryNote()
  }

  func testBreakingOutOfALoopLeavesLiveObserversUpdating() async throws {
    let service = database.quranDataService
    for _ in 0..<3 {
      for try await _ in service.unsyncedItemsSequence() {
        break
      }
    }

    try await assertLiveObserverCountsEveryNote()
  }

  func testDroppingAnIteratorWithAValueWaitingLeavesLiveObserversUpdating() async throws {
    let service = database.quranDataService
    for ayah in 1...3 {
      let iterator = service.unsyncedItemsSequence().makeAsyncIterator()
      _ = try await iterator.next()
      // A change reaches this collector, which then waits for the iterator to take it. Nothing says when it has
      // arrived, so give it time; arriving late only lets this test pass without covering the waiting value.
      try await service.createNote(
        body: "Waiting", startSura: 3, startAyah: ayah, endSura: 3, endAyah: ayah, timestamp: Date())
      try await Task.sleep(nanoseconds: 500_000_000)
      withExtendedLifetime(iterator) {}
    }

    try await assertLiveObserverCountsEveryNote()
  }

  /// Creates notes one at a time, each once a live observer counts the last. MobileSync shares one held-items reader
  /// among collectors; once a collector stops taking values, the reader's buffer fills and stops it for all of them.
  private func assertLiveObserverCountsEveryNote() async throws {
    let service = database.quranDataService
    // More changes than the shared reader buffers.
    let notes = 70
    let observing = XCTestExpectation(description: "The observer has the count")
    let counted = (1...notes).map { XCTestExpectation(description: "The observer counts note \($0)") }
    let observation = Task {
      var initial: Int?
      for try await count in service.unsyncedItemsSequence().map(\.pending) {
        guard let initial else {
          initial = count
          observing.fulfill()
          continue
        }
        if counted.indices.contains(count - initial - 1) {
          counted[count - initial - 1].fulfill()
        }
      }
    }
    defer { observation.cancel() }

    await fulfillment(of: [observing], timeout: 10)
    for (ayah, noteCounted) in zip(1..., counted) {
      try await service.createNote(
        body: "Reflection", startSura: 2, startAyah: ayah, endSura: 2, endAyah: ayah, timestamp: Date())
      guard await XCTWaiter().fulfillment(of: [noteCounted], timeout: 10) == .completed else {
        XCTFail("The observer stopped counting after \(ayah - 1) of \(notes) notes")
        return
      }
    }
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }
}
