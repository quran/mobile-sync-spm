import Foundation
import MobileSync
import XCTest

final class CollectionErrorIntegrationTests: XCTestCase {
  private let database = ImportTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.reset()
  }

  override func tearDown() async throws {
    try await database.reset()
    try await super.tearDown()
  }

  func testUpdateCollectionThrowsDuplicateNameErrorAndKeepsName() async throws {
    _ = try await database.service.createCollection(named: "Study")
    let collection = try await database.service.createCollection(named: "Review")

    await assertThrows(\MobileSyncDuplicateCollectionNameError.name, "Study") {
      _ = try await self.database.service.updateCollection(id: collection.id, name: " study ")
    }
    let collections = try await storedCollections()
    XCTAssertEqual(collections.first { $0.collection.id == collection.id }?.collection.name, "Review")
  }

  func testFavoritesThrowsReadOnlyErrorOnRenameAndDelete() async throws {
    let collections = try await storedCollections()
    let favorites = try XCTUnwrap(collections.first { $0.collection.isDefault })
    let id = favorites.collection.id
    XCTAssertTrue(favorites.collection.isReadOnly)

    await assertThrows(\MobileSyncReadOnlyCollectionError.id, id) {
      _ = try await self.database.service.updateCollection(id: id, name: "Renamed")
    }
    await assertThrows(\MobileSyncReadOnlyCollectionError.id, id) {
      _ = try await self.database.service.removeCollection(id: id)
    }
    let storedNames = try await storedCollections().map(\.collection.name)
    XCTAssertTrue(storedNames.contains(favorites.collection.name))
  }

  func testCreateAndRenameThrowReservedNameError() async throws {
    let collection = try await database.service.createCollection(named: "Study")

    await assertThrows(\MobileSyncReservedCollectionNameError.name, "system:notes") {
      _ = try await self.database.service.createCollection(named: "system:notes")
    }
    await assertThrows(\MobileSyncReservedCollectionNameError.name, "Favorites") {
      _ = try await self.database.service.updateCollection(id: collection.id, name: "Favorites")
    }
    let names = try await storedCollections().map(\.collection.name)
    XCTAssertTrue(names.contains("Study"))
    XCTAssertFalse(names.contains("system:notes"))
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

  private func storedCollections() async throws -> [MobileSyncCollectionWithBookmarks] {
    let iterator = database.service.collectionsWithBookmarksSequence().makeAsyncIterator()
    return try await iterator.next() ?? []
  }
}
