import Foundation
internal import KMPNativeCoroutinesAsync
import Shared

public extension QuranDataService {
  func highlightsSequence() -> MobileSyncAsyncSequence<[AyahHighlight]> {
    MobileSyncAsyncSequence(asyncSequence(for: highlights))
  }

  func readingBookmarkSequence() -> MobileSyncAsyncSequence<ReadingBookmark?> {
    MobileSyncAsyncSequence(asyncSequence(for: readingBookmark))
  }

  func readingSessionsSequence() -> MobileSyncAsyncSequence<[ReadingSession]> {
    MobileSyncAsyncSequence(asyncSequence(for: readingSessions))
  }

  func collectionsWithBookmarksSequence()
    -> MobileSyncAsyncSequence<[CollectionWithAyahBookmarks]>
  {
    MobileSyncAsyncSequence(asyncSequence(for: collectionsWithBookmarks))
  }

  func notesSequence() -> MobileSyncAsyncSequence<[Note_]> {
    MobileSyncAsyncSequence(asyncSequence(for: notes))
  }

  func addAyahReadingBookmark(sura: Int32, ayah: Int32) async throws -> AyahReadingBookmark {
    try await asyncFunction(for: addAyahReadingBookmark(sura: sura, ayah: ayah))
  }

  func addAyahReadingBookmark(sura: Int32, ayah: Int32, timestamp: Date) async throws
    -> AyahReadingBookmark
  {
    try await asyncFunction(
      for: addAyahReadingBookmark(sura: sura, ayah: ayah, timestamp: timestamp)
    )
  }

  func addPageReadingBookmark(page: Int32) async throws -> PageReadingBookmark {
    try await asyncFunction(for: addPageReadingBookmark(page: page))
  }

  func addPageReadingBookmark(page: Int32, timestamp: Date) async throws -> PageReadingBookmark {
    try await asyncFunction(for: addPageReadingBookmark(page: page, timestamp: timestamp))
  }

  func addReadingSession(sura: Int32, ayah: Int32) async throws -> ReadingSession {
    try await asyncFunction(for: addReadingSession(sura: sura, ayah: ayah))
  }

  func addReadingSession(sura: Int32, ayah: Int32, timestamp: Date) async throws -> ReadingSession {
    try await asyncFunction(for: addReadingSession(sura: sura, ayah: ayah, timestamp: timestamp))
  }

  func updateReadingSession(id: String, sura: Int32, ayah: Int32, timestamp: Date) async throws
    -> ReadingSession
  {
    try await asyncFunction(
      for: updateReadingSession(
        id: id,
        sura: sura,
        ayah: ayah,
        timestamp: timestamp
      )
    )
  }

  func updateReadingSession(id: String, sura: Int32, ayah: Int32) async throws
    -> ReadingSession
  {
    try await asyncFunction(
      for: updateReadingSession(
        id: id,
        sura: sura,
        ayah: ayah
      )
    )
  }

  func removeReadingSession(sura: Int32, ayah: Int32) async throws -> Bool {
    let deleted: KotlinBoolean = try await asyncFunction(
      for: deleteReadingSession(sura: sura, ayah: ayah)
    )
    return deleted.boolValue
  }

  func removeReadingBookmark() async throws -> Bool {
    let deleted: KotlinBoolean = try await asyncFunction(for: deleteReadingBookmark())
    return deleted.boolValue
  }

  func setAyahHighlight(sura: Int32, ayah: Int32, color: AyahHighlightColor) async throws
    -> AyahHighlight
  {
    try await asyncFunction(for: setHighlight(sura: sura, ayah: ayah, color: color))
  }

  func removeAyahHighlight(sura: Int32, ayah: Int32) async throws -> Bool {
    let removed: KotlinBoolean = try await asyncFunction(
      for: removeHighlight(sura: sura, ayah: ayah)
    )
    return removed.boolValue
  }

  func createCollection(named name: String) async throws -> BookmarkCollection {
    try await asyncFunction(for: addCollection(name: name))
  }

  func createCollection(named name: String, timestamp: Date) async throws -> BookmarkCollection {
    try await asyncFunction(for: addCollection(name: name, timestamp: timestamp))
  }

  func removeCollection(id: String) async throws -> Bool {
    let deleted: KotlinBoolean = try await asyncFunction(for: deleteCollection(id: id))
    return deleted.boolValue
  }

  func updateCollection(id: String, name: String) async throws -> BookmarkCollection {
    try await asyncFunction(for: updateCollection(id: id, name: name))
  }

  func updateCollection(id: String, name: String, timestamp: Date) async throws
    -> BookmarkCollection
  {
    try await asyncFunction(
      for: updateCollection(id: id, name: name, timestamp: timestamp)
    )
  }

  func addAyahBookmarkToCollection(collectionId: String, sura: Int32, ayah: Int32) async throws
    -> CollectionAyahBookmark
  {
    try await asyncFunction(
      for: addAyahBookmarkToCollection(
        collectionId: collectionId,
        sura: sura,
        ayah: ayah
      )
    )
  }

  func addAyahBookmarkToCollection(
    collectionId: String,
    sura: Int32,
    ayah: Int32,
    timestamp: Date
  ) async throws -> CollectionAyahBookmark {
    try await asyncFunction(
      for: addAyahBookmarkToCollection(
        collectionId: collectionId,
        sura: sura,
        ayah: ayah,
        timestamp: timestamp
      )
    )
  }

  func removeAyahBookmarkFromCollection(_ bookmark: CollectionAyahBookmark) async throws {
    _ = try await asyncFunction(
      for: removeAyahBookmarkFromCollection(
        bookmark: bookmark
      )
    )
  }

  func createNote(
    body: String,
    startSura: Int32,
    startAyah: Int32,
    endSura: Int32,
    endAyah: Int32
  ) async throws {
    _ = try await asyncFunction(
      for: addNote(
        body: body,
        startSura: startSura,
        startAyah: startAyah,
        endSura: endSura,
        endAyah: endAyah
      )
    )
  }

  func createNote(
    body: String,
    startSura: Int32,
    startAyah: Int32,
    endSura: Int32,
    endAyah: Int32,
    timestamp: Date
  ) async throws {
    _ = try await asyncFunction(
      for: addNote(
        body: body,
        startSura: startSura,
        startAyah: startAyah,
        endSura: endSura,
        endAyah: endAyah,
        timestamp: timestamp
      )
    )
  }

  func updateNote(
    id: String,
    body: String,
    startSura: Int32,
    startAyah: Int32,
    endSura: Int32,
    endAyah: Int32
  ) async throws {
    _ = try await asyncFunction(
      for: updateNote(
        id: id,
        body: body,
        startSura: startSura,
        startAyah: startAyah,
        endSura: endSura,
        endAyah: endAyah
      )
    )
  }

  func updateNote(
    id: String,
    body: String,
    startSura: Int32,
    startAyah: Int32,
    endSura: Int32,
    endAyah: Int32,
    timestamp: Date
  ) async throws {
    _ = try await asyncFunction(
      for: updateNote(
        id: id,
        body: body,
        startSura: startSura,
        startAyah: startAyah,
        endSura: endSura,
        endAyah: endAyah,
        timestamp: timestamp
      )
    )
  }

  func removeNote(id: String) async throws {
    _ = try await asyncFunction(for: deleteNote(id: id))
  }

  func logout(clearLocalData: Bool) async throws {
    _ = try await asyncFunction(for: logout(clearLocalData: clearLocalData))
  }
}
