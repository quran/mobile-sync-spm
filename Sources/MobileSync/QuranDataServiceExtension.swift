import Foundation
internal import KMPNativeCoroutinesAsync
import Shared

public extension QuranDataService {
  /// Merges local data and optionally records handled content so later tracked imports skip it.
  /// `deleteExisting` preserves import history and cannot be combined with `trackHistory`.
  func importData(
    data: PersistenceImportData,
    deleteExisting: Bool = false,
    trackHistory: Bool = false
  ) async throws -> PersistenceImportResult {
    try await asyncFunction(
      for: importData(
        data: data,
        deleteExisting: deleteExisting,
        trackHistory: trackHistory
      )
    )
  }

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

  func notesSequence() -> MobileSyncAsyncSequence<[Note]> {
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

  func deleteAyahHighlight(sura: Int32, ayah: Int32) async throws -> Bool {
    let deleted: KotlinBoolean = try await asyncFunction(
      for: deleteHighlight(sura: sura, ayah: ayah)
    )
    return deleted.boolValue
  }

  /// - Throws: `MobileSyncTextLengthLimitError` when the name is outside the length limits.
  func createCollection(named name: String) async throws -> BookmarkCollection {
    try await mappingTextLengthLimit {
      try await asyncFunction(for: addCollection(name: name))
    }
  }

  /// - Throws: `MobileSyncTextLengthLimitError` when the name is outside the length limits.
  func createCollection(named name: String, timestamp: Date) async throws -> BookmarkCollection {
    try await mappingTextLengthLimit {
      try await asyncFunction(for: addCollection(name: name, timestamp: timestamp))
    }
  }

  /// - Throws: `MobileSyncReadOnlyCollectionError` when the collection can't be deleted.
  func removeCollection(id: String) async throws -> Bool {
    let deleted: KotlinBoolean = try await mappingCollectionErrors {
      try await asyncFunction(for: deleteCollection(id: id))
    }
    return deleted.boolValue
  }

  /// - Throws: `MobileSyncReadOnlyCollectionError` when the collection can't be renamed,
  ///   `MobileSyncDuplicateCollectionNameError` when another collection has the name, and
  ///   `MobileSyncTextLengthLimitError` when the name is outside the length limits.
  func updateCollection(id: String, name: String) async throws -> BookmarkCollection {
    try await mappingCollectionErrors {
      try await asyncFunction(for: updateCollection(id: id, name: name))
    }
  }

  /// - Throws: `MobileSyncReadOnlyCollectionError` when the collection can't be renamed,
  ///   `MobileSyncDuplicateCollectionNameError` when another collection has the name, and
  ///   `MobileSyncTextLengthLimitError` when the name is outside the length limits.
  func updateCollection(id: String, name: String, timestamp: Date) async throws
    -> BookmarkCollection
  {
    try await mappingCollectionErrors {
      try await asyncFunction(
        for: updateCollection(id: id, name: name, timestamp: timestamp)
      )
    }
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

  @discardableResult
  func removeAyahBookmarkFromCollection(collectionId: String, bookmarkId: String) async throws -> Bool {
    let removed: KotlinBoolean = try await asyncFunction(
      for: removeAyahBookmarkFromCollection(collectionId: collectionId, bookmarkId: bookmarkId)
    )
    return removed.boolValue
  }

  /// - Throws: `MobileSyncTextLengthLimitError` when the body is outside the length limits.
  func createNote(
    body: String,
    startSura: Int32,
    startAyah: Int32,
    endSura: Int32,
    endAyah: Int32
  ) async throws {
    _ = try await mappingTextLengthLimit {
      try await asyncFunction(
        for: addNote(
          body: body,
          startSura: startSura,
          startAyah: startAyah,
          endSura: endSura,
          endAyah: endAyah
        )
      )
    }
  }

  /// - Throws: `MobileSyncTextLengthLimitError` when the body is outside the length limits.
  func createNote(
    body: String,
    startSura: Int32,
    startAyah: Int32,
    endSura: Int32,
    endAyah: Int32,
    timestamp: Date
  ) async throws {
    _ = try await mappingTextLengthLimit {
      try await asyncFunction(
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
  }

  /// Updates a note's body. A note's verse ranges never change.
  ///
  /// - Throws: `MobileSyncTextLengthLimitError` when a changed body is outside the length limits.
  func updateNote(id: String, body: String) async throws {
    _ = try await mappingTextLengthLimit {
      try await asyncFunction(for: updateNote(id: id, body: body))
    }
  }

  /// Updates a note's body. A note's verse ranges never change.
  ///
  /// - Throws: `MobileSyncTextLengthLimitError` when a changed body is outside the length limits.
  func updateNote(id: String, body: String, timestamp: Date) async throws {
    _ = try await mappingTextLengthLimit {
      try await asyncFunction(for: updateNote(id: id, body: body, timestamp: timestamp))
    }
  }

  @discardableResult
  func deleteNote(id: String) async throws -> Bool {
    let deleted: KotlinBoolean = try await asyncFunction(for: deleteNote(id: id))
    return deleted.boolValue
  }

  func logout(clearLocalData: Bool) async throws {
    _ = try await asyncFunction(for: logout(clearLocalData: clearLocalData))
  }
}

/// Rethrows a bridged `TextLengthLimitException` as `MobileSyncTextLengthLimitError`.
private func mappingTextLengthLimit<T>(_ operation: () async throws -> T) async throws -> T {
  do {
    return try await operation()
  } catch {
    throw MobileSyncTextLengthLimitError(bridgedError: error) ?? error
  }
}

/// Rethrows a bridged collection or text length exception as its Swift-native error.
private func mappingCollectionErrors<T>(_ operation: () async throws -> T) async throws -> T {
  do {
    return try await mappingTextLengthLimit(operation)
  } catch {
    if let readOnly = MobileSyncReadOnlyCollectionError(bridgedError: error) {
      throw readOnly
    }
    throw MobileSyncDuplicateCollectionNameError(bridgedError: error) ?? error
  }
}
