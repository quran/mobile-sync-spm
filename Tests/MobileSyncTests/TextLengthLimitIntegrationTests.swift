import Foundation
import MobileSync
import MobileSyncTestSupport
import XCTest

final class TextLengthLimitIntegrationTests: XCTestCase {
  private let database = MobileSyncTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.reset()
  }

  override func tearDown() async throws {
    try await database.reset()
    try await super.tearDown()
  }

  func testCreateNoteThrowsTextLengthLimitError() async throws {
    let expected = ExpectedLimit(
      field: .noteBody, bound: .tooShort, limit: 6, length: 2)

    await assertThrows(\MobileSyncTextLengthLimitError.fields, expected) {
      try await self.database.quranDataService.createNote(
        body: "Hi", startSura: 2, startAyah: 1, endSura: 2, endAyah: 1)
    }
    let notes = try await storedNotes()
    XCTAssertTrue(notes.isEmpty)
  }

  func testUpdateNoteThrowsTextLengthLimitErrorAndKeepsBody() async throws {
    _ = try await database.quranDataService.importData(noteData())
    let notes = try await storedNotes()
    let note = try XCTUnwrap(notes.first)
    let body = String(repeating: "a", count: 10001)
    let expected = ExpectedLimit(
      field: .noteBody, bound: .tooLong, limit: 10000, length: 10001)

    await assertThrows(\MobileSyncTextLengthLimitError.fields, expected) {
      try await self.database.quranDataService.updateNote(id: note.id, body: body)
    }
    let storedBodies = try await storedNotes().map(\.body)
    XCTAssertEqual(storedBodies, ["Legacy note"])
  }

  func testCreateCollectionThrowsTextLengthLimitError() async throws {
    let expected = ExpectedLimit(
      field: .collectionName, bound: .tooShort, limit: 1, length: 0)

    await assertThrows(\MobileSyncTextLengthLimitError.fields, expected) {
      _ = try await self.database.quranDataService.createCollection(named: "  ")
    }
    let collections = try await storedCollections()
    XCTAssertFalse(collections.contains { !$0.collection.isSystem })
  }

  func testUpdateCollectionThrowsTextLengthLimitErrorAndKeepsName() async throws {
    let collection = try await database.quranDataService.createCollection(named: "Study")
    let name = String(repeating: "a", count: 256)
    let expected = ExpectedLimit(
      field: .collectionName, bound: .tooLong, limit: 255, length: 256)

    await assertThrows(\MobileSyncTextLengthLimitError.fields, expected) {
      _ = try await self.database.quranDataService.updateCollection(id: collection.id, name: name)
    }
    let collections = try await storedCollections()
    XCTAssertEqual(collections.first { $0.collection.id == collection.id }?.collection.name, "Study")
  }

  func testUpdateCollectionThrowsDataErrorForOtherFailures() async throws {
    do {
      _ = try await database.quranDataService.updateCollection(id: "999999", name: "Study")
      XCTFail("Expected a missing collection to throw")
    } catch let MobileSyncDataError.invalidArgument(underlying) {
      XCTAssertTrue(underlying.localizedDescription.contains("Expected active collection"))
    }
  }

  private func assertThrows<E: Error, Value: Equatable>(
    _ field: KeyPath<E, Value>,
    _ expected: Value,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> Void
  ) async {
    do {
      try await operation()
      XCTFail("Expected \(E.self)", file: file, line: line)
    } catch {
      XCTAssertEqual((error as? E)?[keyPath: field], expected, file: file, line: line)
    }
  }

  private func noteData() -> MobileSyncImportData {
    MobileSyncImportData(
      notes: [
        MobileSyncImportNote(
          body: "Legacy note", startSura: 2, startAyah: 1, endSura: 2, endAyah: 3,
          lastUpdated: date(100), createdAt: date(50))
      ]
    )
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
}

/// The public fields of a `MobileSyncTextLengthLimitError`, whose initializer is internal.
private struct ExpectedLimit: Equatable {
  let field: MobileSyncTextLengthLimitError.Field
  let bound: MobileSyncTextLengthLimitError.Bound
  let limit: Int
  let length: Int
}

extension MobileSyncTextLengthLimitError {
  fileprivate var fields: ExpectedLimit {
    ExpectedLimit(field: field, bound: bound, limit: limit, length: length)
  }
}
