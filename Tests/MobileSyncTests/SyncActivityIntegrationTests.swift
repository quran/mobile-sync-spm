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
    let status = try await first { $0.syncStatusSequence() }

    XCTAssertEqual(status, .idle)
  }

  func testSyncHistoryIsEmptyWithoutASync() async throws {
    let runs = try await first { $0.syncHistorySequence() }

    XCTAssertEqual(runs, [])
  }

  func testHeldItemsAreEmptyWithoutASync() async throws {
    // Only a push holds an item.
    try await database.quranDataService.createNote(
      body: "Reflection", startSura: 2, startAyah: 1, endSura: 2, endAyah: 5, timestamp: date(100))

    let held = try await first { $0.heldItemsSequence() }

    XCTAssertEqual(held, [])
  }

  func testUnsyncedItemCountSequenceCountsANewNote() async throws {
    let service = database.quranDataService
    let observation = Task {
      var counts: [Int] = []
      do {
        for try await count in service.unsyncedItemCountSequence() {
          counts.append(count)
          if counts.count == 1 {
            try await service.createNote(
              body: "Reflection", startSura: 2, startAyah: 1, endSura: 2, endAyah: 5, timestamp: Date())
          } else {
            // Cancelling, not breaking out, stops the collector; the loop then ends.
            withUnsafeCurrentTask { $0?.cancel() }
          }
        }
      } catch is CancellationError {}
      return counts
    }

    let counts = try await observation.value
    XCTAssertEqual(counts, [0, 1])
  }

  func testUnsyncedItemCountReadsTheCountOnce() async throws {
    let before = try await database.quranDataService.unsyncedItemCount()

    try await database.quranDataService.createNote(
      body: "Reflection", startSura: 2, startAyah: 1, endSura: 2, endAyah: 5, timestamp: date(100))

    let after = try await database.quranDataService.unsyncedItemCount()
    XCTAssertEqual(before, 0)
    XCTAssertEqual(after, 1)
  }

  /// The first value, cancelling the collector afterward so it doesn't keep reading.
  private func first<Element: Sendable>(
    _ makeSequence: @escaping @Sendable (MobileSyncDataService) -> MobileSyncAsyncSequence<Element>
  ) async throws -> Element? {
    let service = database.quranDataService
    return try await firstValue { makeSequence(service) }
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }
}
