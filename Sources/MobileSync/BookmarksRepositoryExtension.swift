import Foundation
import KMPNativeCoroutinesAsync
import Shared

public extension BookmarksRepository {
  func bookmarksSequence() -> NativeFlowAsyncSequence<[Bookmark], Error, KotlinUnit> {
    asyncSequence(for: getBookmarksFlow())
  }

  func allBookmarks() async throws -> [Bookmark] {
    try await asyncFunction(for: getAllBookmarks())
  }

  func migrateBookmarks(_ bookmarks: [BookmarkMigration]) async throws {
    _ = try await asyncFunction(for: migrateBookmarks(bookmarks: bookmarks))
  }
}
