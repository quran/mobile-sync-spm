import Foundation
import MobileSync
import MobileSyncTestSupport
import XCTest

final class PersistenceImportIntegrationTests: XCTestCase {
  private let database = MobileSyncTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.reset()
  }

  override func tearDown() async throws {
    try await database.reset()
    try await super.tearDown()
  }

  func testOpenDatabaseReusesTheGraphDatabase() throws {
    // setUp already opened the database through the graph.
    try MobileSyncGraph.openDatabase(databaseName: database.databaseName)
    try MobileSyncGraph.openDatabase(databaseName: database.databaseName)
  }

  func testDefaultImportDoesNotRecordHistory() async throws {
    let data = noteData()

    let inserted = try await database.quranDataService.importData(data)
    let matched = try await database.quranDataService.importData(data, trackHistory: true)
    let replay = try await database.quranDataService.importData(data, trackHistory: true)

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
    // A logout keeps the import history, so a body other tests track would already be processed.
    let data = noteData(body: "Deleted legacy note")
    _ = try await database.quranDataService.importData(data, trackHistory: true)
    let notes = try await storedNotes()
    let note = try XCTUnwrap(notes.first)
    try await database.quranDataService.deleteNote(id: note.id)

    let result = try await database.quranDataService.importData(data, trackHistory: true)

    XCTAssertEqual(result.alreadyProcessed, 1)
    XCTAssertFalse(result.changed)
    let remainingNotes = try await storedNotes()
    XCTAssertTrue(remainingNotes.isEmpty)
  }

  func testDeleteNoteReportsWhetherANoteWasDeleted() async throws {
    _ = try await database.quranDataService.importData(noteData())
    let notes = try await storedNotes()
    let note = try XCTUnwrap(notes.first)

    let deleted = try await database.quranDataService.deleteNote(id: note.id)
    let deletedAgain = try await database.quranDataService.deleteNote(id: note.id)

    XCTAssertTrue(deleted)
    XCTAssertFalse(deletedAgain)
  }

  func testRemoveAyahBookmarkFromCollectionByIDsReportsWhetherAMembershipWasRemoved() async throws {
    let collection = try await database.quranDataService.createCollection(named: "Study")
    let bookmark = try await database.quranDataService.addAyahBookmarkToCollection(
      collectionID: collection.id, sura: 2, ayah: 255, timestamp: date(100))

    let removed = try await database.quranDataService.removeAyahBookmarkFromCollection(
      collectionID: collection.id, bookmarkID: bookmark.bookmarkID)
    let removedAgain = try await database.quranDataService.removeAyahBookmarkFromCollection(
      collectionID: collection.id, bookmarkID: bookmark.bookmarkID)

    XCTAssertTrue(removed)
    XCTAssertFalse(removedAgain)
  }

  func testReplacementCannotTrackHistoryAndPreservesDataOnFailure() async throws {
    _ = try await database.quranDataService.importData(noteData())

    do {
      _ = try await database.quranDataService.importData(
        MobileSyncImportData(), deleteExisting: true, trackHistory: true)
      XCTFail("Expected incompatible import options to throw")
    } catch let MobileSyncDataError.invalidArgument(underlying) {
      XCTAssertTrue(underlying.localizedDescription.contains("deleteExisting and trackHistory"))
    }

    let notes = try await storedNotes()
    XCTAssertEqual(notes.count, 1)
  }

  func testReadingBookmarkImportUsesCurrentSlotsAndSkipsTrackedReplay() async throws {
    let timestamp = Date(timeIntervalSince1970: 123)
    let bookmark = MobileSyncImportReadingBookmark(
      slot: .teal, placement: .page(42), lastUpdated: timestamp, name: "Morning")
    let data = MobileSyncImportData(readingBookmarks: [bookmark])

    let inserted = try await database.quranDataService.importData(data, trackHistory: true)
    let replay = try await database.quranDataService.importData(data, trackHistory: true)

    XCTAssertEqual(inserted.readingBookmarksImported, 1)
    XCTAssertEqual(replay.alreadyProcessed, 1)
    XCTAssertFalse(replay.changed)
    let iterator = database.quranDataService.readingBookmarksSequence().makeAsyncIterator()
    let bookmarks = try await iterator.next()
    let stored = try XCTUnwrap(bookmarks?.first { $0.slot == .teal })
    XCTAssertEqual(stored.placement, .page(42, mushafID: MobileSyncReadingBookmark.madaniMushafID))
    XCTAssertEqual(stored.name, "Morning")
    XCTAssertEqual(stored.lastUpdated, timestamp)
  }

  func testMembershipsShareParentAndBridgeDates() async throws {
    let data = importData(
      collections: [
        MobileSyncImportCollection(name: " favorites ", lastUpdated: date(200), createdAt: date(40)),
        MobileSyncImportCollection(name: "Study", lastUpdated: date(300), createdAt: date(60)),
      ],
      collectionBookmarks: [
        MobileSyncImportCollectionBookmark(
          collectionName: "FAVORITES", sura: 2, ayah: 255, lastUpdated: date(200), createdAt: date(50)),
        MobileSyncImportCollectionBookmark(
          collectionName: "Study", sura: 2, ayah: 255, lastUpdated: date(300), createdAt: date(75)),
      ]
    )

    let inserted = try await database.quranDataService.importData(data, trackHistory: true)
    let replay = try await database.quranDataService.importData(data, trackHistory: true)

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
    XCTAssertEqual(favoriteBookmark.bookmarkID, studyBookmark.bookmarkID)
    XCTAssertEqual(studyBookmark.sura, 2)
    XCTAssertEqual(studyBookmark.ayah, 255)
    XCTAssertEqual(studyBookmark.bookmarkAddedDate, date(50))
  }

  func testNewestHighlightWinsAndReplayIsSkipped() async throws {
    let data = importData(highlights: [
      MobileSyncImportHighlight(sura: 2, ayah: 255, color: .blue, lastUpdated: date(100), createdAt: nil),
      MobileSyncImportHighlight(sura: 2, ayah: 255, color: .yellow, lastUpdated: date(200), createdAt: nil),
    ])

    let inserted = try await database.quranDataService.importData(data, trackHistory: true)
    let replay = try await database.quranDataService.importData(data, trackHistory: true)

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
      MobileSyncImportReadingSession(sura: 2, ayah: 255, lastUpdated: date(200), createdAt: date(100))
    ])

    let inserted = try await database.quranDataService.importData(data, trackHistory: true)
    let replay = try await database.quranDataService.importData(data, trackHistory: true)

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
    let retry = try await database.quranDataService.importData(cancelledNoteData(), trackHistory: true)
    XCTAssertEqual(retry.alreadyProcessed, 0)
    XCTAssertEqual(retry.notesImported, 1)
  }

  func testInvalidReferenceThrowsBoundedErrorWithoutWriting() async throws {
    let data = importData(
      collectionBookmarks: [
        MobileSyncImportCollectionBookmark(
          collectionName: "Missing", sura: 2, ayah: 255, lastUpdated: date(100), createdAt: nil)
      ],
      notes: [
        MobileSyncImportNote(
          body: "Private note text", startSura: 2, startAyah: 1, endSura: 2, endAyah: 1,
          lastUpdated: date(100), createdAt: nil)
      ]
    )

    do {
      _ = try await database.quranDataService.importData(data, trackHistory: true)
      XCTFail("Expected an unknown collection reference to throw")
    } catch let MobileSyncDataError.invalidArgument(underlying) {
      XCTAssertTrue(underlying.localizedDescription.contains("unknown collection"))
      XCTAssertFalse(underlying.localizedDescription.contains("Private note text"))
    }

    let notes = try await storedNotes()
    XCTAssertTrue(notes.isEmpty)
  }

  private func noteData(body: String = "Legacy note") -> MobileSyncImportData {
    MobileSyncImportData(
      notes: [
        MobileSyncImportNote(
          body: body, startSura: 2, startAyah: 1, endSura: 2, endAyah: 3,
          lastUpdated: Date(timeIntervalSince1970: 100),
          createdAt: Date(timeIntervalSince1970: 50)
        )
      ]
    )
  }

  private func importData(
    collections: [MobileSyncImportCollection] = [],
    collectionBookmarks: [MobileSyncImportCollectionBookmark] = [],
    readingSessions: [MobileSyncImportReadingSession] = [],
    notes: [MobileSyncImportNote] = [],
    highlights: [MobileSyncImportHighlight] = []
  ) -> MobileSyncImportData {
    MobileSyncImportData(
      collections: collections, collectionBookmarks: collectionBookmarks,
      readingSessions: readingSessions, notes: notes, highlights: highlights)
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }

  private func storedNotes() async throws -> [MobileSyncNote] {
    let iterator = database.quranDataService.notesSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }

  private func storedCollections() async throws -> [MobileSyncCollectionWithBookmarks] {
    let iterator = database.quranDataService.collectionsWithBookmarksSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }

  private func storedHighlights() async throws -> [MobileSyncAyahHighlight] {
    let iterator = database.quranDataService.highlightsSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }

  private func storedReadingSessions() async throws -> [MobileSyncReadingSession] {
    let iterator = database.quranDataService.readingSessionsSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }
}

private func importNoteAfterCancellation() async throws {
  // The stream never yields and ends on cancellation, so the import starts in a cancelled task.
  for await _ in AsyncStream(Void.self, { _ in }) {}
  _ = try await MobileSyncTestDatabase.shared.quranDataService.importData(cancelledNoteData(), trackHistory: true)
}

private func cancelledNoteData() -> MobileSyncImportData {
  MobileSyncImportData(
    notes: [
      MobileSyncImportNote(
        body: "Cancelled note", startSura: 2, startAyah: 1, endSura: 2, endAyah: 1,
        lastUpdated: Date(timeIntervalSince1970: 100), createdAt: nil)
    ])
}
