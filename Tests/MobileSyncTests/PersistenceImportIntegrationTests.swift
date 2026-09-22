import Foundation
import MobileSync
import XCTest

final class PersistenceImportIntegrationTests: XCTestCase {
  private let database = ImportTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.service.logout(clearLocalData: true)
  }

  override func tearDown() async throws {
    try await database.service.logout(clearLocalData: true)
    try await super.tearDown()
  }

  func testDefaultImportDoesNotRecordHistory() async throws {
    let data = noteData()

    let inserted = try await database.service.importData(data: data)
    let matched = try await database.service.importData(data: data, trackHistory: true)
    let replay = try await database.service.importData(data: data, trackHistory: true)

    XCTAssertEqual(inserted.notesImported, 1)
    XCTAssertTrue(inserted.changed)
    XCTAssertEqual(matched.matched, 1)
    XCTAssertEqual(matched.alreadyProcessed, 0)
    XCTAssertFalse(matched.changed)
    XCTAssertEqual(replay.alreadyProcessed, 1)
    XCTAssertFalse(replay.changed)
    let notes = try await storedNotes()
    XCTAssertEqual(notes.count, 1)
    XCTAssertEqual(notes.first?.body, "Legacy note")
  }

  func testTrackedImportDoesNotRestoreDeletedNote() async throws {
    let data = noteData()
    _ = try await database.service.importData(data: data, trackHistory: true)
    let notes = try await storedNotes()
    let note = try XCTUnwrap(notes.first)
    try await database.service.removeNote(id: note.id)

    let result = try await database.service.importData(data: data, trackHistory: true)

    XCTAssertEqual(result.alreadyProcessed, 1)
    XCTAssertFalse(result.changed)
    let remainingNotes = try await storedNotes()
    XCTAssertTrue(remainingNotes.isEmpty)
  }

  func testReplacementCannotTrackHistoryAndPreservesDataOnFailure() async throws {
    _ = try await database.service.importData(data: noteData())

    do {
      _ = try await database.service.importData(
        data: PersistenceImportData(
          collections: [], collectionBookmarks: [], readingSessions: [], notes: [],
          highlights: [], readingBookmarks: []),
        deleteExisting: true, trackHistory: true)
      XCTFail("Expected incompatible import options to throw")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("deleteExisting and trackHistory"))
    }

    let notes = try await storedNotes()
    XCTAssertEqual(notes.count, 1)
  }

  func testReadingBookmarkImportUsesCurrentSlotsAndSkipsTrackedReplay() async throws {
    let timestamp = Date(timeIntervalSince1970: 123)
    let bookmark = ImportReadingBookmark.Page(
      page: 42, lastUpdated: timestamp, slot: .green, name: "Morning")
    let data = PersistenceImportData(
      collections: [], collectionBookmarks: [], readingSessions: [], notes: [],
      highlights: [], readingBookmarks: [bookmark])

    let inserted = try await database.service.importData(data: data, trackHistory: true)
    let replay = try await database.service.importData(data: data, trackHistory: true)

    XCTAssertEqual(inserted.readingBookmarksImported, 1)
    XCTAssertEqual(replay.alreadyProcessed, 1)
    XCTAssertFalse(replay.changed)
    let iterator = database.service.readingBookmarksSequence().makeAsyncIterator()
    let bookmarks = try await iterator.next()
    let stored = try XCTUnwrap(bookmarks?.first { $0.slot == .green } as? PageReadingBookmark)
    XCTAssertEqual(stored.page, 42)
    XCTAssertEqual(stored.name, "Morning")
    XCTAssertEqual(stored.lastUpdated, timestamp)
  }

  private func noteData() -> PersistenceImportData {
    PersistenceImportData(
      collections: [], collectionBookmarks: [], readingSessions: [],
      notes: [
        ImportNote(
          body: "Legacy note", startSura: 2, startAyah: 1, endSura: 2, endAyah: 3,
          lastUpdated: Date(timeIntervalSince1970: 100),
          createdAt: Date(timeIntervalSince1970: 50)
        )
      ],
      highlights: [], readingBookmarks: []
    )
  }

  private func storedNotes() async throws -> [Note_] {
    let iterator = database.service.notesSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }
}

// Kotlin owns the service's synchronization; XCTest resets the shared database before and after each test.
private final class ImportTestDatabase: @unchecked Sendable {
  static let shared = ImportTestDatabase()
  let service: QuranDataService

  private init() {
    Self.removeDatabaseFiles()
    AuthFlowFactoryProvider.shared.doInitialize()
    service =
      SharedDependencyGraph.shared.doInit(
        driverFactory: DriverFactory(),
        storage: AppleMobileSyncStorageFactory.shared.create(),
        clientId: "",
        clientSecret: nil
      ).quranDataService
  }

  private static func removeDatabaseFiles() {
    guard
      let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
    else {
      return
    }
    // The XCTest runner persists this database between runs of different local frameworks.
    let databaseURL = applicationSupport.appendingPathComponent("databases/quran.db")
    for suffix in ["", "-shm", "-wal"] {
      try? FileManager.default.removeItem(atPath: databaseURL.path + suffix)
    }
  }
}
