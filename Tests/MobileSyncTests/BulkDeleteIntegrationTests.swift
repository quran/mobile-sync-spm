import Foundation
import MobileSync
import MobileSyncTestSupport
import XCTest

// Deleting a highlight color or emptying a collection in one write, through the public API only.
final class BulkDeleteIntegrationTests: XCTestCase {
  private let database = MobileSyncTestDatabase.shared
  private var service: MobileSyncDataService { database.quranDataService }

  override func setUp() async throws {
    try await super.setUp()
    try await database.reset()
  }

  override func tearDown() async throws {
    try await database.reset()
    try await super.tearDown()
  }

  func testDeleteAyahHighlightsRemovesOnlyThatColor() async throws {
    let favorites = try await favoritesID()
    let study = try await service.createCollection(named: "Study", timestamp: date(100))
    try await add([(2, 255)], to: favorites, at: 200)
    try await add([(3, 18)], to: study.id, at: 200)
    for (sura, ayah) in [(2, 255), (3, 18), (4, 1)] {
      _ = try await service.setAyahHighlight(sura: sura, ayah: ayah, color: .blue, timestamp: date(300))
    }
    let green = try await service.setAyahHighlight(sura: 5, ayah: 3, color: .green, timestamp: date(400))

    let removed = try await service.deleteAyahHighlights(color: .blue)

    XCTAssertEqual(removed, 3)
    let highlights = try await first(service.highlightsSequence())
    XCTAssertEqual(highlights, [green])
    let collections = try await storedVerses()
    XCTAssertEqual(collections[favorites], ["2:255"])
    XCTAssertEqual(collections[study.id], ["3:18"])
  }

  func testDeleteAyahHighlightsReturnsZeroWhenNoVerseHasTheColor() async throws {
    let green = try await service.setAyahHighlight(sura: 5, ayah: 3, color: .green, timestamp: date(100))

    let removed = try await service.deleteAyahHighlights(color: .pink)

    XCTAssertEqual(removed, 0)
    let highlights = try await first(service.highlightsSequence())
    XCTAssertEqual(highlights, [green])
  }

  func testRemoveAllAyahBookmarksFromCollectionEmptiesItAndKeepsIt() async throws {
    let favorites = try await favoritesID()
    let study = try await service.createCollection(named: "Study", timestamp: date(100))
    let review = try await service.createCollection(named: "Review", timestamp: date(100))
    try await add([(2, 255), (3, 18)], to: study.id, at: 200)
    try await add([(2, 255)], to: review.id, at: 300)
    try await add([(3, 18)], to: favorites, at: 300)
    let blue = try await service.setAyahHighlight(sura: 2, ayah: 255, color: .blue, timestamp: date(400))

    let removed = try await service.removeAllAyahBookmarksFromCollection(collectionID: study.id)

    XCTAssertEqual(removed, 2)
    let collections = try await storedVerses()
    XCTAssertEqual(collections[study.id], [], "Study stays, empty")
    XCTAssertEqual(collections[review.id], ["2:255"])
    XCTAssertEqual(collections[favorites], ["3:18"])
    let highlights = try await first(service.highlightsSequence())
    XCTAssertEqual(highlights, [blue])
  }

  func testRemoveAllAyahBookmarksFromCollectionEmptiesFavorites() async throws {
    let favorites = try await favoritesID()
    let study = try await service.createCollection(named: "Study", timestamp: date(100))
    try await add([(2, 255), (3, 18), (4, 1)], to: favorites, at: 200)
    try await add([(3, 18)], to: study.id, at: 300)

    let removed = try await service.removeAllAyahBookmarksFromCollection(collectionID: favorites)

    XCTAssertEqual(removed, 3)
    let collections = try await storedVerses()
    XCTAssertEqual(collections[favorites], [], "Favorites stays, empty")
    XCTAssertEqual(collections[study.id], ["3:18"])
  }

  func testRemoveAllAyahBookmarksFromCollectionReturnsZeroForAnEmptyOrUnknownCollection() async throws {
    let empty = try await service.createCollection(named: "Empty", timestamp: date(100))
    let other = try await service.createCollection(named: "Other", timestamp: date(100))
    try await add([(2, 255)], to: other.id, at: 200)

    for collectionID in [empty.id, "999", "not-an-id"] {
      let removed = try await service.removeAllAyahBookmarksFromCollection(collectionID: collectionID)
      XCTAssertEqual(removed, 0, collectionID)
    }
    let collections = try await storedVerses()
    XCTAssertEqual(collections[other.id], ["2:255"])
  }

  func testBulkDeletesKeepVersesThatDontExist() async throws {
    let study = try await service.createCollection(named: "Study", timestamp: date(100))
    try await add([(2, 999), (2, 255)], to: study.id, at: 200)
    let invalidHighlight = try await service.setAyahHighlight(sura: 2, ayah: 999, color: .blue, timestamp: date(300))
    _ = try await service.setAyahHighlight(sura: 2, ayah: 255, color: .blue, timestamp: date(300))

    let removedBookmarks = try await service.removeAllAyahBookmarksFromCollection(collectionID: study.id)
    let removedHighlights = try await service.deleteAyahHighlights(color: .blue)

    XCTAssertEqual(removedBookmarks, 1)
    XCTAssertEqual(removedHighlights, 1)
    let collections = try await storedVerses()
    XCTAssertEqual(collections[study.id], ["2:999"])
    let highlights = try await first(service.highlightsSequence())
    XCTAssertEqual(highlights, [invalidHighlight])
  }

  private func add(_ verses: [(sura: Int, ayah: Int)], to collectionID: String, at seconds: TimeInterval) async throws {
    for verse in verses {
      _ = try await service.addAyahBookmarkToCollection(
        collectionID: collectionID, sura: verse.sura, ayah: verse.ayah, timestamp: date(seconds))
    }
  }

  /// Each listed collection's id to its verses ("sura:ayah"), sorted.
  private func storedVerses() async throws -> [String: [String]] {
    let collections = try await first(service.collectionsWithBookmarksSequence()) ?? []
    return Dictionary(
      uniqueKeysWithValues: collections.map { entry in
        (entry.collection.id, entry.bookmarks.map { "\($0.sura):\($0.ayah)" }.sorted())
      })
  }

  private func favoritesID() async throws -> String {
    let collections = try await first(service.collectionsWithBookmarksSequence()) ?? []
    return try XCTUnwrap(collections.first { $0.collection.isDefault }).collection.id
  }

  private func first<Element>(_ sequence: MobileSyncAsyncSequence<Element>) async throws -> Element? {
    try await sequence.makeAsyncIterator().next()
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }
}
