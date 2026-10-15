import Foundation
import Shared
import XCTest

@testable import MobileSync

final class MobileSyncModelMappingTests: XCTestCase {
  func testMapsCollectionsWithBookmarks() {
    // Each pair of flags differs in one of the two collections, so swapping any two fails.
    let collections = [
      CollectionWithAyahBookmarks(
        collection: BookmarkCollection(
          name: "Favorites", lastUpdated: date(10), id: "1", isDefault: true, isSystem: false, isReadOnly: false),
        bookmarks: [
          CollectionAyahBookmark(
            collectionId: "1", bookmarkId: "9", sura: 2, ayah: 255, bookmarkLastUpdated: date(20),
            bookmarkAddedDate: date(5))
        ]
      ),
      CollectionWithAyahBookmarks(
        collection: BookmarkCollection(
          name: "Green", lastUpdated: date(30), id: "2", isDefault: false, isSystem: true, isReadOnly: false),
        bookmarks: []
      ),
    ]

    XCTAssertEqual(
      collections.map(MobileSyncCollectionWithBookmarks.init),
      [
        MobileSyncCollectionWithBookmarks(
          collection: MobileSyncCollection(
            id: "1", name: "Favorites", lastUpdated: date(10), isDefault: true, isSystem: false, isReadOnly: false),
          bookmarks: [
            MobileSyncCollectionBookmark(
              collectionID: "1", bookmarkID: "9", sura: 2, ayah: 255, bookmarkLastUpdated: date(20),
              bookmarkAddedDate: date(5))
          ]
        ),
        MobileSyncCollectionWithBookmarks(
          collection: MobileSyncCollection(
            id: "2", name: "Green", lastUpdated: date(30), isDefault: false, isSystem: true, isReadOnly: false),
          bookmarks: []
        ),
      ]
    )
  }

  func testMapsEveryNoteRangeInOrder() {
    let note = Note(
      body: "Reflection",
      ranges: [
        NoteRange(startSura: 2, startAyah: 1, endSura: 3, endAyah: 5),
        NoteRange(startSura: 18, startAyah: 10, endSura: 19, endAyah: 4),
      ],
      lastUpdated: date(10),
      id: "7"
    )

    XCTAssertEqual(
      MobileSyncNote(note),
      MobileSyncNote(
        id: "7",
        body: "Reflection",
        ranges: [
          MobileSyncNoteRange(startSura: 2, startAyah: 1, endSura: 3, endAyah: 5),
          MobileSyncNoteRange(startSura: 18, startAyah: 10, endSura: 19, endAyah: 4),
        ],
        lastUpdated: date(10)
      )
    )
  }

  func testMapsPageReadingBookmarksWithTheirMushaf() {
    let bookmark = PageReadingBookmark(
      page: 255, lastUpdated: date(10), id: "3", slot: .orange, name: "Study", mushafId: 6)

    XCTAssertEqual(
      MobileSyncReadingBookmark(bookmark),
      MobileSyncReadingBookmark(
        id: "3", slot: .orange, placement: .page(255, mushafID: 6), name: "Study", lastUpdated: date(10)))
  }

  func testMapsEveryKotlinHighlightColorBothWays() throws {
    for kotlin in AyahHighlightColor.entries {
      let swift = try XCTUnwrap(MobileSyncHighlightColor(kotlin), "\(kotlin.name) has no Swift color")
      XCTAssertEqual("\(swift)", kotlin.name.lowercased())
      XCTAssertEqual(swift.kotlinColor, kotlin)
    }
  }

  func testDropsReadingBookmarksOfUnknownKinds() {
    XCTAssertNil(MobileSyncReadingBookmark(UnknownReadingBookmark()))
  }

  func testMapsEveryKotlinReadingBookmarkSlotBothWays() throws {
    for kotlin in ReadingBookmarkSlot.entries {
      let swift = try XCTUnwrap(MobileSyncReadingBookmarkSlot(kotlin), "\(kotlin.name) has no Swift slot")
      XCTAssertEqual("\(swift)", kotlin.name.lowercased())
      XCTAssertEqual(swift.kotlinSlot, kotlin)
    }
  }

  func testMapsImportDataToKotlin() {
    let data = MobileSyncImportData(
      collections: [MobileSyncImportCollection(name: "Study", lastUpdated: date(20), createdAt: date(10))],
      collectionBookmarks: [
        MobileSyncImportCollectionBookmark(collectionName: "Study", sura: 2, ayah: 255, lastUpdated: date(20))
      ],
      readingSessions: [MobileSyncImportReadingSession(sura: 18, ayah: 10, lastUpdated: date(30), createdAt: date(5))],
      notes: [
        MobileSyncImportNote(
          body: "Reflection", startSura: 2, startAyah: 1, endSura: 3, endAyah: 5, lastUpdated: date(40))
      ],
      highlights: [MobileSyncImportHighlight(sura: 2, ayah: 1, color: .yellow, lastUpdated: date(40))],
      readingBookmarks: [
        MobileSyncImportReadingBookmark(slot: .teal, placement: .ayah(sura: 36, ayah: 1), lastUpdated: date(50)),
        MobileSyncImportReadingBookmark(slot: .red, placement: .page(42), lastUpdated: date(60), name: "Review"),
      ]
    )

    XCTAssertEqual(
      data.kotlinData,
      PersistenceImportData(
        collections: [ImportCollection(name: "Study", lastUpdated: date(20), createdAt: date(10))],
        collectionBookmarks: [
          ImportCollectionAyahBookmark(
            collectionName: "Study", sura: 2, ayah: 255, lastUpdated: date(20), createdAt: nil)
        ],
        readingSessions: [ImportReadingSession(sura: 18, ayah: 10, lastUpdated: date(30), createdAt: date(5))],
        notes: [
          ImportNote(
            body: "Reflection", startSura: 2, startAyah: 1, endSura: 3, endAyah: 5, lastUpdated: date(40),
            createdAt: nil)
        ],
        highlights: [
          ImportAyahHighlight(sura: 2, ayah: 1, color: .yellow, lastUpdated: date(40), createdAt: nil)
        ],
        readingBookmarks: [
          ImportReadingBookmark.Ayah(sura: 36, ayah: 1, lastUpdated: date(50), slot: .teal, name: nil),
          ImportReadingBookmark.Page(page: 42, lastUpdated: date(60), slot: .red, name: "Review"),
        ]
      )
    )
  }

  func testMapsImportResult() {
    let result = PersistenceImportResult(
      bookmarksImported: 1, collectionsImported: 2, collectionBookmarksImported: 3, readingSessionsImported: 4,
      notesImported: 5, readingBookmarksImported: 6, highlightsImported: 7, readingSessionsUpdated: 8,
      matched: 9, keptExisting: 10, alreadyProcessed: 11, changed: true)

    XCTAssertEqual(
      MobileSyncImportResult(result),
      MobileSyncImportResult(
        bookmarksImported: 1, collectionsImported: 2, collectionBookmarksImported: 3, readingSessionsImported: 4,
        notesImported: 5, readingBookmarksImported: 6, highlightsImported: 7, readingSessionsUpdated: 8,
        matched: 9, keptExisting: 10, alreadyProcessed: 11, changed: true))
  }

  func testMapsUser() {
    let user = UserInfo(
      id: "u1", firstName: "Amina", lastName: "Khan", name: nil, email: "amina@example.com",
      photoUrl: "https://example.com/a.png")

    XCTAssertEqual(
      MobileSyncUser(user),
      MobileSyncUser(
        id: "u1", firstName: "Amina", lastName: "Khan", email: "amina@example.com",
        photoURL: "https://example.com/a.png"))
  }

  func testMapsEnvironments() {
    XCTAssertEqual(MobileSyncEnvironment.prelive.kotlinEnvironment, AppEnvironment.prelive)
    XCTAssertEqual(MobileSyncEnvironment.production.kotlinEnvironment, AppEnvironment.production)
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }
}

/// A reading bookmark kind a newer MobileSync could add.
private final class UnknownReadingBookmark: NSObject, ReadingBookmark {
  let id = "1"
  let lastUpdated = Date(timeIntervalSince1970: 10)
  let name: String? = nil
  let slot = ReadingBookmarkSlot.teal
}
