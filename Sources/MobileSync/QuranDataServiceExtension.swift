import Foundation
internal import KMPNativeCoroutinesAsync
import Shared

public extension QuranDataService {
  func highlightsSequence() -> MobileSyncAsyncSequence<[AyahHighlight]> {
    MobileSyncAsyncSequence(asyncSequence(for: highlights))
  }

  func readingBookmarksSequence() -> MobileSyncAsyncSequence<[ReadingBookmark]> {
    MobileSyncAsyncSequence(asyncSequence(for: readingBookmarks))
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

  func setAyahReadingBookmark(
    slot: ReadingBookmarkSlot,
    sura: Int32,
    ayah: Int32
  ) async throws -> ReadingBookmark {
    try await asyncFunction(for: setAyahReadingBookmark(slot: slot, sura: sura, ayah: ayah))
  }

  func setAyahReadingBookmark(
    slot: ReadingBookmarkSlot,
    sura: Int32,
    ayah: Int32,
    timestamp: Date
  ) async throws -> ReadingBookmark {
    try await asyncFunction(
      for: setAyahReadingBookmark(slot: slot, sura: sura, ayah: ayah, timestamp: timestamp)
    )
  }

  func setPageReadingBookmark(slot: ReadingBookmarkSlot, page: Int32) async throws
    -> ReadingBookmark
  {
    try await asyncFunction(for: setPageReadingBookmark(slot: slot, page: page))
  }

  func setPageReadingBookmark(
    slot: ReadingBookmarkSlot,
    page: Int32,
    timestamp: Date
  ) async throws -> ReadingBookmark {
    try await asyncFunction(for: setPageReadingBookmark(slot: slot, page: page, timestamp: timestamp))
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

  func renameReadingBookmark(slot: ReadingBookmarkSlot, name: String?) async throws -> ReadingBookmark {
    try await asyncFunction(for: renameReadingBookmark(slot: slot, name: name))
  }

  func clearReadingBookmark(slot: ReadingBookmarkSlot) async throws -> ReadingBookmark {
    try await asyncFunction(for: clearReadingBookmark(slot: slot))
  }

  func clearReadingBookmark(slot: ReadingBookmarkSlot, timestamp: Date) async throws
    -> ReadingBookmark
  {
    try await asyncFunction(for: clearReadingBookmark(slot: slot, timestamp: timestamp))
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

  func replaceAyahBookmarkCollections(
    sura: Int32,
    ayah: Int32,
    collectionIds: [String]
  ) async throws -> BookmarkCollectionsReplacementResult {
    try await asyncFunction(
      for: replaceAyahBookmarkCollections(sura: sura, ayah: ayah, collectionIds: collectionIds)
    )
  }

  func replaceAyahBookmarkCollections(
    sura: Int32,
    ayah: Int32,
    collectionIds: [String],
    timestamp: Date
  ) async throws -> BookmarkCollectionsReplacementResult {
    try await asyncFunction(
      for: replaceAyahBookmarkCollections(
        sura: sura,
        ayah: ayah,
        collectionIds: collectionIds,
        timestamp: timestamp
      )
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
