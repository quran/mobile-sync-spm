import Foundation
import MobileSync
import MobileSyncTestSupport
import XCTest

// Uses only the public API, so it also checks that a consumer needs nothing else.
final class DataServiceIntegrationTests: XCTestCase {
  private let database = MobileSyncTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.reset()
  }

  override func tearDown() async throws {
    try await database.reset()
    try await super.tearDown()
  }

  func testNotesRoundTrip() async throws {
    try await database.quranDataService.createNote(
      body: "Reflection", startSura: 2, startAyah: 1, endSura: 3, endAyah: 5, timestamp: date(100))
    let notes = try await first(database.quranDataService.notesSequence())
    let created = try XCTUnwrap(notes?.first)

    try await database.quranDataService.updateNote(id: created.id, body: "Updated", timestamp: date(200))

    let updated = try await first(database.quranDataService.notesSequence()) ?? []
    XCTAssertEqual(
      updated,
      [
        MobileSyncNote(
          id: created.id, body: "Updated",
          ranges: [MobileSyncNoteRange(startSura: 2, startAyah: 1, endSura: 3, endAyah: 5)],
          lastUpdated: date(200))
      ])
    let deleted = try await database.quranDataService.deleteNote(id: created.id)
    XCTAssertTrue(deleted)
  }

  func testCollectionsAndMemberships() async throws {
    let collection = try await database.quranDataService.createCollection(named: "Study", timestamp: date(100))
    let bookmark = try await database.quranDataService.addAyahBookmarkToCollection(
      collectionID: collection.id, sura: 2, ayah: 255, timestamp: date(200))

    let renamed = try await database.quranDataService.updateCollection(id: collection.id, name: "Review", timestamp: date(300))
    let stored = try await first(database.quranDataService.collectionsWithBookmarksSequence()) ?? []

    XCTAssertEqual(renamed.name, "Review")
    XCTAssertEqual(renamed.lastUpdated, date(300))
    let study = try XCTUnwrap(stored.first { $0.collection.id == collection.id })
    XCTAssertEqual(study.collection, renamed)
    XCTAssertEqual(study.bookmarks, [bookmark])
    XCTAssertEqual(bookmark.sura, 2)
    XCTAssertEqual(bookmark.ayah, 255)
    let removed = try await database.quranDataService.removeCollection(id: collection.id)
    let removedAgain = try await database.quranDataService.removeCollection(id: collection.id)
    XCTAssertTrue(removed)
    XCTAssertFalse(removedAgain)
  }

  func testHighlights() async throws {
    _ = try await database.quranDataService.setAyahHighlight(sura: 2, ayah: 255, color: .blue, timestamp: date(100))
    let replaced = try await database.quranDataService.setAyahHighlight(
      sura: 2, ayah: 255, color: .purple, timestamp: date(200))

    let stored = try await first(database.quranDataService.highlightsSequence()) ?? []
    let deleted = try await database.quranDataService.deleteAyahHighlight(sura: 2, ayah: 255)
    let deletedAgain = try await database.quranDataService.deleteAyahHighlight(sura: 2, ayah: 255)

    XCTAssertEqual(replaced, MobileSyncAyahHighlight(sura: 2, ayah: 255, color: .purple, lastUpdated: date(200)))
    XCTAssertEqual(stored, [replaced])
    XCTAssertTrue(deleted)
    XCTAssertFalse(deletedAgain)
  }

  func testReadingBookmarks() async throws {
    let ayah = try await database.quranDataService.setAyahReadingBookmark(slot: .teal, sura: 36, ayah: 1, timestamp: date(100))
    let page = try await database.quranDataService.setPageReadingBookmark(
      slot: .orange, page: 42, mushaf: .madani1440, timestamp: date(200))
    let renamed = try await database.quranDataService.renameReadingBookmark(slot: .teal, name: "Daily", mushaf: .madani1440)
    let cleared = try await database.quranDataService.clearReadingBookmark(slot: .orange)
    let named = try await database.quranDataService.renameReadingBookmark(slot: .red, name: "Review", mushaf: .madani1440)

    XCTAssertEqual(ayah.placement, .ayah(sura: 36, ayah: 1))
    XCTAssertEqual(ayah.lastUpdated, date(100))
    XCTAssertEqual(page.placement, .page(42, mushaf: .madani1440))
    XCTAssertEqual(renamed.placement, .ayah(sura: 36, ayah: 1))
    XCTAssertEqual(renamed.name, "Daily")
    XCTAssertEqual(cleared.placement, .unplaced)
    XCTAssertEqual(named.placement, .unplaced)
    XCTAssertEqual(named.name, "Review")
    let stored = try await first(database.quranDataService.readingBookmarksSequence(mushaf: .madani1440)) ?? []
    XCTAssertTrue(stored.contains(renamed))
    XCTAssertTrue(stored.contains(named))
  }

  func testReadingSessions() async throws {
    let first = try await database.quranDataService.addReadingSession(sura: 2, ayah: 1, timestamp: date(100))
    let moved = try await database.quranDataService.updateReadingSession(id: first.id, sura: 3, ayah: 1, timestamp: date(200))

    let stored = try await self.first(database.quranDataService.readingSessionsSequence()) ?? []

    XCTAssertEqual(moved, MobileSyncReadingSession(id: first.id, sura: 3, ayah: 1, lastUpdated: date(200)))
    XCTAssertEqual(stored, [moved])
  }

  func testUnconfiguredAuthentication() async throws {
    let auth = database.authService

    XCTAssertFalse(auth.isLoggedIn)
    let headers = try await auth.authenticationHeaders()
    XCTAssertEqual(headers, [:])
    let refreshed = try await auth.refreshAuthentication()
    XCTAssertFalse(refreshed)
    do {
      try await auth.signInWithReauthentication()
      XCTFail("Expected sign-in to fail without credentials")
    } catch MobileSyncAuthenticationError.authenticationFailed {}
  }

  func testLoggingSendsMobileSyncLogsToTheSink() async throws {
    let sink = LogSinkSpy()
    MobileSyncLogging.configure(sink: sink, minSeverity: .info)
    // Logging is process-wide, so later tests log to the console again rather than to this spy.
    defer { MobileSyncLogging.configure(sink: ConsoleLogSink(), minSeverity: .verbose) }

    _ = try? await database.quranDataService.createCollection(named: "  ")

    // MobileSync logs a write the data rules reject, such as a blank name, at info rather than error.
    let logged = sink.entries.contains { $0.severity == .info && $0.message.hasPrefix("Failed to add collection") }
    XCTAssertTrue(logged)
  }

  private func first<Element>(_ sequence: MobileSyncAsyncSequence<Element>) async throws -> Element? {
    try await sequence.makeAsyncIterator().next()
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }
}

final class LogSinkSpy: MobileSyncLogSink, @unchecked Sendable {
  struct Entry: Equatable {
    let severity: MobileSyncLogSeverity
    let tag: String
    let message: String
  }

  var entries: [Entry] {
    lock.withLock { storedEntries }
  }

  func log(severity: MobileSyncLogSeverity, tag: String, message: String) {
    lock.withLock { storedEntries.append(Entry(severity: severity, tag: tag, message: message)) }
  }

  private let lock = NSLock()
  private var storedEntries: [Entry] = []
}

/// Logs to the console, like MobileSync does before it is configured.
private struct ConsoleLogSink: MobileSyncLogSink {
  func log(severity: MobileSyncLogSeverity, tag: String, message: String) {
    NSLog("%@", "(\(tag)) \(message)")
  }
}
