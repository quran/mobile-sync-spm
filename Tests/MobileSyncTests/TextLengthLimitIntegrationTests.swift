import Foundation
import XCTest

@testable import MobileSync

final class TextLengthLimitIntegrationTests: XCTestCase {
  private let database = ImportTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.service.logout(clearLocalData: true)
  }

  override func tearDown() async throws {
    try await database.service.logout(clearLocalData: true)
    try await super.tearDown()
  }

  func testCreateNoteThrowsTextLengthLimitError() async throws {
    let expected = MobileSyncTextLengthLimitError(
      field: .noteBody, bound: .tooShort, limit: 6, length: 2)

    await assertThrows(expected) {
      try await self.database.service.createNote(
        body: "Hi", startSura: 2, startAyah: 1, endSura: 2, endAyah: 1)
    }
    await assertThrows(expected) {
      try await self.database.service.createNote(
        body: "Hi", startSura: 2, startAyah: 1, endSura: 2, endAyah: 1, timestamp: self.date(100))
    }
    let notes = try await storedNotes()
    XCTAssertTrue(notes.isEmpty)
  }

  func testUpdateNoteThrowsTextLengthLimitErrorAndKeepsBody() async throws {
    _ = try await database.service.importData(data: noteData())
    let notes = try await storedNotes()
    let note = try XCTUnwrap(notes.first)
    let body = String(repeating: "a", count: 10001)
    let expected = MobileSyncTextLengthLimitError(
      field: .noteBody, bound: .tooLong, limit: 10000, length: 10001)

    await assertThrows(expected) {
      try await self.database.service.updateNote(id: note.id, body: body)
    }
    await assertThrows(expected) {
      try await self.database.service.updateNote(
        id: note.id, body: body, timestamp: self.date(200))
    }
    let storedBodies = try await storedNotes().map(\.body)
    XCTAssertEqual(storedBodies, ["Legacy note"])
  }

  func testCreateCollectionThrowsTextLengthLimitError() async throws {
    let expected = MobileSyncTextLengthLimitError(
      field: .collectionName, bound: .tooShort, limit: 1, length: 0)

    await assertThrows(expected) {
      _ = try await self.database.service.createCollection(named: "  ")
    }
    await assertThrows(expected) {
      _ = try await self.database.service.createCollection(named: "  ", timestamp: self.date(100))
    }
    let collections = try await storedCollections()
    XCTAssertFalse(collections.contains { !$0.collection.isSystem })
  }

  func testUpdateCollectionThrowsTextLengthLimitErrorAndKeepsName() async throws {
    let collection = try await database.service.createCollection(named: "Study")
    let name = String(repeating: "a", count: 256)
    let expected = MobileSyncTextLengthLimitError(
      field: .collectionName, bound: .tooLong, limit: 255, length: 256)

    await assertThrows(expected) {
      _ = try await self.database.service.updateCollection(id: collection.id, name: name)
    }
    await assertThrows(expected) {
      _ = try await self.database.service.updateCollection(
        id: collection.id, name: name, timestamp: self.date(200))
    }
    let collections = try await storedCollections()
    XCTAssertEqual(collections.first { $0.collection.id == collection.id }?.collection.name, "Study")
  }

  func testUpdateCollectionPassesOtherErrorsThrough() async throws {
    do {
      _ = try await database.service.updateCollection(id: "999999", name: "Study")
      XCTFail("Expected a missing collection to throw")
    } catch {
      XCTAssertFalse(error is MobileSyncTextLengthLimitError)
      XCTAssertTrue(error.localizedDescription.contains("Expected active collection"))
    }
  }

  private func assertThrows(
    _ expected: MobileSyncTextLengthLimitError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> Void
  ) async {
    do {
      try await operation()
      XCTFail("Expected a text length limit error", file: file, line: line)
    } catch {
      XCTAssertEqual(error as? MobileSyncTextLengthLimitError, expected, file: file, line: line)
    }
  }

  private func noteData() -> PersistenceImportData {
    PersistenceImportData(
      collections: [], collectionBookmarks: [], readingSessions: [],
      notes: [
        ImportNote(
          body: "Legacy note", startSura: 2, startAyah: 1, endSura: 2, endAyah: 3,
          lastUpdated: date(100), createdAt: date(50))
      ],
      highlights: [], readingBookmarks: []
    )
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }

  private func storedNotes() async throws -> [Note] {
    let iterator = database.service.notesSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }

  private func storedCollections() async throws -> [CollectionWithAyahBookmarks] {
    let iterator = database.service.collectionsWithBookmarksSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }
}
