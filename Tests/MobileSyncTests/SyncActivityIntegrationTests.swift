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
    let status = try await first(database.quranDataService.syncStatusSequence())

    XCTAssertEqual(status, .idle)
  }

  func testSyncHistoryIsEmptyWithoutASync() async throws {
    let runs = try await first(database.quranDataService.syncHistorySequence())

    XCTAssertEqual(runs, [])
  }

  func testHeldItemsAreEmptyWithoutASync() async throws {
    // Only a push holds an item.
    try await database.quranDataService.createNote(
      body: "Reflection", startSura: 2, startAyah: 1, endSura: 2, endAyah: 5, timestamp: date(100))

    let held = try await first(database.quranDataService.heldItemsSequence())

    XCTAssertEqual(held, [])
  }

  func testUnsyncedItemCountCountsANewNote() async throws {
    let counts = database.quranDataService.unsyncedItemCountSequence().makeAsyncIterator()
    let before = try await counts.next()

    try await database.quranDataService.createNote(
      body: "Reflection", startSura: 2, startAyah: 1, endSura: 2, endAyah: 5, timestamp: date(100))

    let after = try await counts.next()
    XCTAssertEqual(before, 0)
    XCTAssertEqual(after, 1)
  }

  func testTriggeringASyncWithoutASessionRecordsNoRun() async throws {
    database.quranDataService.triggerSync(immediately: true)

    let runs = try await first(database.quranDataService.syncHistorySequence())

    XCTAssertEqual(runs, [])
  }

  private func first<Element>(_ sequence: MobileSyncAsyncSequence<Element>) async throws -> Element? {
    try await sequence.makeAsyncIterator().next()
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }
}
