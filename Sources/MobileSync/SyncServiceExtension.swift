import Foundation
import KMPNativeCoroutinesAsync
import Shared

public extension SyncService {
  func bookmarksSequence() -> NativeFlowAsyncSequence<[AyahBookmark], Error, KotlinUnit> {
    asyncSequence(for: bookmarks)
  }

  func readingBookmarkSequence() -> NativeFlowAsyncSequence<ReadingBookmark?, Error, KotlinUnit> {
    asyncSequence(for: readingBookmark)
  }

  func readingSessionsSequence() -> NativeFlowAsyncSequence<[ReadingSession], Error, KotlinUnit> {
    asyncSequence(for: readingSessions)
  }

  func collectionsWithBookmarksSequence()
    -> NativeFlowAsyncSequence<[CollectionWithAyahBookmarks], Error, KotlinUnit>
  {
    asyncSequence(for: collectionsWithBookmarks)
  }

  func notesSequence() -> NativeFlowAsyncSequence<[Note_], Error, KotlinUnit> {
    asyncSequence(for: notes)
  }

  func bookmarksForCollectionSequence(collectionLocalId: String)
    -> NativeFlowAsyncSequence<[CollectionAyahBookmark], Error, KotlinUnit>
  {
    asyncSequence(for: getBookmarksForCollectionFlow(collectionLocalId: collectionLocalId))
  }

  func addAyahBookmark(sura: Int32, ayah: Int32) async throws -> AyahBookmark {
    try await asyncFunction(for: addBookmark(sura: sura, ayah: ayah))
  }

  func addReadingBookmark(sura: Int32, ayah: Int32) async throws -> ReadingBookmark {
    try await asyncFunction(for: addReadingBookmark(sura: sura, ayah: ayah))
  }

  func addReadingSession(sura: Int32, ayah: Int32) async throws -> ReadingSession {
    try await asyncFunction(for: addReadingSession(sura: sura, ayah: ayah))
  }

  func removeReadingBookmark() async throws -> Bool {
    let deleted: KotlinBoolean = try await asyncFunction(for: deleteReadingBookmark())
    return deleted.boolValue
  }

  func removeBookmark(_ bookmark: AyahBookmark) async throws {
    _ = try await asyncFunction(for: deleteBookmark(bookmark: bookmark))
  }

  func createCollection(named name: String) async throws {
    _ = try await asyncFunction(for: addCollection(name: name))
  }

  func removeCollection(localId: String) async throws {
    _ = try await asyncFunction(for: deleteCollection(localId: localId))
  }

  func addBookmarkToCollection(collectionLocalId: String, bookmark: AyahBookmark) async throws {
    _ = try await asyncFunction(
      for: addBookmarkToCollection(
        collectionLocalId: collectionLocalId,
        bookmark: bookmark
      )
    )
  }

  func addAyahBookmarkToCollection(collectionLocalId: String, sura: Int32, ayah: Int32) async throws
    -> CollectionAyahBookmark
  {
    try await asyncFunction(
      for: addAyahBookmarkToCollection(
        collectionLocalId: collectionLocalId,
        sura: sura,
        ayah: ayah
      )
    )
  }

  func removeBookmarkFromCollection(collectionLocalId: String, bookmark: AyahBookmark) async throws {
    _ = try await asyncFunction(
      for: removeBookmarkFromCollection(
        collectionLocalId: collectionLocalId,
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

  func updateNote(
    localId: String,
    body: String,
    startSura: Int32,
    startAyah: Int32,
    endSura: Int32,
    endAyah: Int32
  ) async throws {
    guard let notesRepository = pipelineForIos.notesRepository as? NotesRepository else {
      throw SyncServiceExtensionError.notesRepositoryUnavailable
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      notesRepository.updateNote(
        localId: localId,
        body: body,
        startSura: startSura,
        startAyah: startAyah,
        endSura: endSura,
        endAyah: endAyah
      ) { _, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }
    }
  }

  func removeNote(localId: String) async throws {
    _ = try await asyncFunction(for: deleteNote(localId: localId))
  }

  func logout(clearLocalData: Bool) async throws {
    _ = try await asyncFunction(for: logout(clearLocalData: clearLocalData))
  }

}

private enum SyncServiceExtensionError: Error {
  case notesRepositoryUnavailable
}
