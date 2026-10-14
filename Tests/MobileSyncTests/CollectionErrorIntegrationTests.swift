import Foundation
import XCTest

@testable import MobileSync

final class CollectionErrorIntegrationTests: XCTestCase {
  private let database = ImportTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.service.logout(clearLocalData: true)
  }

  override func tearDown() async throws {
    try await database.service.logout(clearLocalData: true)
    try await super.tearDown()
  }

  func testUpdateCollectionThrowsDuplicateNameErrorAndKeepsName() async throws {
    _ = try await database.service.createCollection(named: "Study")
    let collection = try await database.service.createCollection(named: "Review")
    let expected = MobileSyncDuplicateCollectionNameError(name: "Study")

    await assertThrows(expected) {
      _ = try await self.database.service.updateCollection(id: collection.id, name: " study ")
    }
    await assertThrows(expected) {
      _ = try await self.database.service.updateCollection(
        id: collection.id, name: " study ", timestamp: Date(timeIntervalSince1970: 200))
    }
    let collections = try await storedCollections()
    XCTAssertEqual(collections.first { $0.collection.id == collection.id }?.collection.name, "Review")
  }

  func testFavoritesThrowsReadOnlyErrorOnRenameAndDelete() async throws {
    let collections = try await storedCollections()
    let favorites = try XCTUnwrap(collections.first { $0.collection.isDefault })
    let id = favorites.collection.id
    XCTAssertTrue(favorites.collection.isReadOnly)
    let expected = MobileSyncReadOnlyCollectionError(id: id)

    await assertThrows(expected) {
      _ = try await self.database.service.updateCollection(id: id, name: "Renamed")
    }
    await assertThrows(expected) {
      _ = try await self.database.service.updateCollection(
        id: id, name: "Renamed", timestamp: Date(timeIntervalSince1970: 200))
    }
    await assertThrows(expected) {
      _ = try await self.database.service.removeCollection(id: id)
    }
    let storedNames = try await storedCollections().map(\.collection.name)
    XCTAssertTrue(storedNames.contains(favorites.collection.name))
  }

  private func assertThrows<E: Error & Equatable>(
    _ expected: E,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> Void
  ) async {
    do {
      try await operation()
      XCTFail("Expected \(expected)", file: file, line: line)
    } catch {
      XCTAssertEqual(error as? E, expected, file: file, line: line)
    }
  }

  private func storedCollections() async throws -> [CollectionWithAyahBookmarks] {
    let iterator = database.service.collectionsWithBookmarksSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }
}
