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

  func testMembershipsShareParentAndBridgeDates() async throws {
    let data = importData(
      collections: [
        ImportCollection(importId: "favorites", name: " favorites ", lastUpdated: date(200), createdAt: date(40)),
        ImportCollection(importId: "study", name: "Study", lastUpdated: date(300), createdAt: date(60)),
      ],
      collectionBookmarks: [
        ImportCollectionAyahBookmark(
          collectionImportId: "favorites", sura: 2, ayah: 255, lastUpdated: date(200), createdAt: date(50)),
        ImportCollectionAyahBookmark(
          collectionImportId: "study", sura: 2, ayah: 255, lastUpdated: date(300), createdAt: date(75)),
      ]
    )

    let inserted = try await database.service.importData(data: data, trackHistory: true)
    let replay = try await database.service.importData(data: data, trackHistory: true)

    XCTAssertEqual(inserted.bookmarksImported, 1)
    XCTAssertEqual(inserted.collectionsImported, 1)
    XCTAssertEqual(inserted.collectionBookmarksImported, 2)
    XCTAssertEqual(replay.alreadyProcessed, 2)
    XCTAssertFalse(replay.changed)
    let collections = try await storedCollections()
    let favorites = try XCTUnwrap(collections.first { $0.collection.isDefault })
    let study = try XCTUnwrap(collections.first { $0.collection.name == "Study" })
    XCTAssertEqual(study.collection.lastUpdated, date(300))
    let favoriteBookmark = try XCTUnwrap(favorites.bookmarks.first)
    let studyBookmark = try XCTUnwrap(study.bookmarks.first)
    XCTAssertEqual(favorites.bookmarks.count, 1)
    XCTAssertEqual(study.bookmarks.count, 1)
    XCTAssertEqual(favoriteBookmark.bookmarkId, studyBookmark.bookmarkId)
    XCTAssertEqual(studyBookmark.sura, 2)
    XCTAssertEqual(studyBookmark.ayah, 255)
    XCTAssertEqual(studyBookmark.bookmarkAddedDate, date(50))
  }

  func testNewestHighlightWinsAndReplayIsSkipped() async throws {
    let data = importData(highlights: [
      ImportAyahHighlight(sura: 2, ayah: 255, color: .blue, lastUpdated: date(100), createdAt: nil),
      ImportAyahHighlight(sura: 2, ayah: 255, color: .yellow, lastUpdated: date(200), createdAt: nil),
    ])

    let inserted = try await database.service.importData(data: data, trackHistory: true)
    let replay = try await database.service.importData(data: data, trackHistory: true)

    XCTAssertEqual(inserted.highlightsImported, 1)
    XCTAssertEqual(inserted.keptExisting, 1)
    XCTAssertEqual(replay.alreadyProcessed, 2)
    XCTAssertFalse(replay.changed)
    let highlights = try await storedHighlights()
    XCTAssertEqual(highlights.count, 1)
    XCTAssertEqual(highlights.first?.color, .yellow)
  }

  func testReadingSessionImportBridgesDatesAndSkipsReplay() async throws {
    let data = importData(readingSessions: [
      ImportReadingSession(sura: 2, ayah: 255, lastUpdated: date(200), createdAt: date(100))
    ])

    let inserted = try await database.service.importData(data: data, trackHistory: true)
    let replay = try await database.service.importData(data: data, trackHistory: true)

    XCTAssertEqual(inserted.readingSessionsImported, 1)
    XCTAssertEqual(replay.alreadyProcessed, 1)
    XCTAssertFalse(replay.changed)
    let sessions = try await storedReadingSessions()
    let session = try XCTUnwrap(sessions.first)
    XCTAssertEqual(session.sura, 2)
    XCTAssertEqual(session.ayah, 255)
    XCTAssertEqual(session.lastUpdated, date(200))
  }

  func testCancelledImportThrowsWithoutWritingData() async throws {
    let task = Task { try await importNoteAfterCancellation() }
    task.cancel()

    do {
      try await task.value
      XCTFail("Expected the cancelled import to throw")
    } catch is CancellationError {}

    let notes = try await storedNotes()
    XCTAssertTrue(notes.isEmpty)
    let retry = try await database.service.importData(data: cancelledNoteData(), trackHistory: true)
    XCTAssertEqual(retry.alreadyProcessed, 0)
    XCTAssertEqual(retry.notesImported, 1)
  }

  func testInvalidReferenceThrowsBoundedErrorWithoutWriting() async throws {
    let data = importData(
      collectionBookmarks: [
        ImportCollectionAyahBookmark(
          collectionImportId: "missing", sura: 2, ayah: 255, lastUpdated: date(100), createdAt: nil)
      ],
      notes: [
        ImportNote(
          body: "Private note text", startSura: 2, startAyah: 1, endSura: 2, endAyah: 1,
          lastUpdated: date(100), createdAt: nil)
      ]
    )

    do {
      _ = try await database.service.importData(data: data, trackHistory: true)
      XCTFail("Expected an unknown collection reference to throw")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("unknown collection"))
      XCTAssertFalse(error.localizedDescription.contains("Private note text"))
    }

    let notes = try await storedNotes()
    XCTAssertTrue(notes.isEmpty)
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

  private func importData(
    collections: [ImportCollection] = [],
    collectionBookmarks: [ImportCollectionAyahBookmark] = [],
    readingSessions: [ImportReadingSession] = [],
    notes: [ImportNote] = [],
    highlights: [ImportAyahHighlight] = []
  ) -> PersistenceImportData {
    PersistenceImportData(
      collections: collections, collectionBookmarks: collectionBookmarks,
      readingSessions: readingSessions, notes: notes, highlights: highlights, readingBookmarks: [])
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }

  private func storedNotes() async throws -> [Note_] {
    let iterator = database.service.notesSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }

  private func storedCollections() async throws -> [CollectionWithAyahBookmarks] {
    let iterator = database.service.collectionsWithBookmarksSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }

  private func storedHighlights() async throws -> [AyahHighlight] {
    let iterator = database.service.highlightsSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }

  private func storedReadingSessions() async throws -> [ReadingSession] {
    let iterator = database.service.readingSessionsSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }
}

private func importNoteAfterCancellation() async throws {
  // The stream never yields and ends on cancellation, so the import starts in a cancelled task.
  for await _ in AsyncStream(Void.self, { _ in }) {}
  _ = try await ImportTestDatabase.shared.service.importData(data: cancelledNoteData(), trackHistory: true)
}

private func cancelledNoteData() -> PersistenceImportData {
  PersistenceImportData(
    collections: [], collectionBookmarks: [], readingSessions: [],
    notes: [
      ImportNote(
        body: "Cancelled note", startSura: 2, startAyah: 1, endSura: 2, endAyah: 1,
        lastUpdated: Date(timeIntervalSince1970: 100), createdAt: nil)
    ],
    highlights: [], readingBookmarks: [])
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
