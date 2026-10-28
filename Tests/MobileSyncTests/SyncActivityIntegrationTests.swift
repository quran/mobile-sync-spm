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

  func testUnsyncedItemCountSequenceCountsANewNote() async throws {
    let service = database.quranDataService
    var counts: [Int] = []
    for try await count in service.unsyncedItemCountSequence() {
      counts.append(count)
      guard counts.count == 1 else {
        break
      }
      try await service.createNote(
        body: "Reflection", startSura: 2, startAyah: 1, endSura: 2, endAyah: 5, timestamp: Date())
    }

    XCTAssertEqual(counts, [0, 1])
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }
}
