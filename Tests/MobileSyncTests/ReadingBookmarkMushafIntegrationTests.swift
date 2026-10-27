import Foundation
import MobileSync
import MobileSyncTestSupport
import XCTest

// Page reading bookmarks through the public API: MobileSync maps a page set in one mushaf into the one it's read in.
final class ReadingBookmarkMushafIntegrationTests: XCTestCase {
  private let database = MobileSyncTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.reset()
  }

  override func tearDown() async throws {
    try await database.reset()
    try await super.tearDown()
  }

  func testPageSetInMadani1405IsReadInEveryMushaf() async throws {
    let set = try await database.quranDataService.setPageReadingBookmark(
      slot: .teal, page: 585, mushaf: .madani1405, timestamp: date(100))

    XCTAssertEqual(set.placement, .page(585, mushaf: .madani1405))
    let madani1440 = try await tealPlacement(in: .madani1440)
    let indoPak = try await tealPlacement(in: .indopak15Lines)
    XCTAssertEqual(madani1440, .page(585, mushaf: .madani1440))
    XCTAssertEqual(indoPak, .page(591, mushaf: .indopak15Lines))
  }

  func testIndoPakPageKeepsTheAppsNumbering() async throws {
    let set = try await database.quranDataService.setPageReadingBookmark(
      slot: .teal, page: 537, mushaf: .indopak15Lines, timestamp: date(100))

    XCTAssertEqual(set.placement, .page(537, mushaf: .indopak15Lines))
    let madani1440 = try await tealPlacement(in: .madani1440)
    let indoPak = try await tealPlacement(in: .indopak15Lines)
    XCTAssertEqual(madani1440, .page(536, mushaf: .madani1440))
    XCTAssertEqual(indoPak, .page(537, mushaf: .indopak15Lines))
  }

  func testPageTheMushafDoesNotHaveThrowsInvalidArgument() async throws {
    let invalidPages: [(MobileSyncMushaf, Int)] = [
      (.madani1405, 605), (.madani1440, 0), (.indopak15Lines, 1), (.indopak15Lines, 612),
    ]
    for (mushaf, page) in invalidPages {
      do {
        _ = try await database.quranDataService.setPageReadingBookmark(slot: .teal, page: page, mushaf: mushaf)
        XCTFail("Expected page \(page) of \(mushaf) to throw")
      } catch MobileSyncDataError.invalidArgument {}
    }

    let bookmarks = try await readingBookmarks(in: .madani1440)
    XCTAssertEqual(bookmarks, [], "A slot that was never set isn't listed")
  }

  func testPageTooLargeForMobileSyncThrowsInvalidArgument() async throws {
    do {
      _ = try await database.quranDataService.setPageReadingBookmark(slot: .teal, page: .max, mushaf: .madani1440)
      XCTFail("Expected page Int.max to throw")
    } catch MobileSyncDataError.invalidArgument {}

    let bookmarks = try await readingBookmarks(in: .madani1440)
    XCTAssertEqual(bookmarks, [])
  }

  func testRenameReturnsThePageInTheGivenMushaf() async throws {
    _ = try await database.quranDataService.setPageReadingBookmark(
      slot: .orange, page: 537, mushaf: .indopak15Lines, timestamp: date(100))

    let renamed = try await database.quranDataService.renameReadingBookmark(
      slot: .orange, name: "Khatm", mushaf: .madani1440, timestamp: date(200))

    XCTAssertEqual(
      renamed,
      MobileSyncReadingBookmark(
        id: renamed.id, slot: .orange, placement: .page(536, mushaf: .madani1440), name: "Khatm",
        lastUpdated: date(200)))
  }

  func testImportsPagesWithTheirMushafAndSkipsPagesTheMushafDoesNotHave() async throws {
    let data = MobileSyncImportData(readingBookmarks: [
      MobileSyncImportReadingBookmark(
        slot: .teal, placement: .page(537, mushaf: .indopak15Lines), lastUpdated: date(100), name: "Morning"),
      MobileSyncImportReadingBookmark(
        slot: .red, placement: .page(605, mushaf: .madani1440), lastUpdated: date(100)),
    ])

    let result = try await database.quranDataService.importData(data)

    XCTAssertEqual(result.readingBookmarksImported, 1)
    let bookmarks = try await readingBookmarks(in: .madani1440)
    XCTAssertEqual(bookmarks.map(\.slot), [.teal])
    XCTAssertEqual(bookmarks.first?.placement, .page(536, mushaf: .madani1440))
    XCTAssertEqual(bookmarks.first?.name, "Morning")
  }

  private func tealPlacement(in mushaf: MobileSyncMushaf) async throws
    -> MobileSyncReadingBookmark.Placement?
  {
    try await readingBookmarks(in: mushaf).first { $0.slot == .teal }?.placement
  }

  private func readingBookmarks(in mushaf: MobileSyncMushaf) async throws -> [MobileSyncReadingBookmark] {
    try await database.quranDataService.readingBookmarksSequence(mushaf: mushaf).makeAsyncIterator().next() ?? []
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }
}
