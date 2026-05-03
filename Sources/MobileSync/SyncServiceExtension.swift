import Foundation
import KMPNativeCoroutinesAsync
import Shared

public extension SyncService {
  func bookmarksSequence() -> NativeFlowAsyncSequence<[Bookmark], Error, KotlinUnit> {
    asyncSequence(for: bookmarks)
  }

  func readingBookmarkSequence() -> NativeFlowAsyncSequence<ReadingBookmark?, Error, KotlinUnit> {
    asyncSequence(for: readingBookmark)
  }

  func readingSessionsSequence() -> NativeFlowAsyncSequence<[ReadingSession], Error, KotlinUnit> {
    asyncSequence(for: readingSessions)
  }

  func collectionsWithBookmarksSequence()
    -> NativeFlowAsyncSequence<[CollectionWithBookmarks], Error, KotlinUnit>
  {
    asyncSequence(for: collectionsWithBookmarks)
  }

  func notesSequence() -> NativeFlowAsyncSequence<[Note_], Error, KotlinUnit> {
    asyncSequence(for: notes)
  }

  func bookmarksForCollectionSequence(collectionLocalId: String)
    -> NativeFlowAsyncSequence<[CollectionBookmark], Error, KotlinUnit>
  {
    asyncSequence(for: getBookmarksForCollectionFlow(collectionLocalId: collectionLocalId))
  }

  func addAyahBookmark(sura: Int32, ayah: Int32) async throws -> Bookmark {
    try await asyncFunction(for: addBookmark(sura: sura, ayah: ayah))
  }

  func addReadingBookmark(sura: Int32, ayah: Int32) async throws -> ReadingBookmark {
    try await asyncFunction(for: addReadingBookmark(sura: sura, ayah: ayah))
  }

  func addReadingSession(sura: Int32, ayah: Int32) async throws -> ReadingSession {
    try await asyncFunction(for: addReadingSession(chapterNumber: sura, verseNumber: ayah))
  }

  func removeReadingBookmark() async throws -> Bool {
    let deleted: KotlinBoolean = try await asyncFunction(for: deleteReadingBookmark())
    return deleted.boolValue
  }

  func removeBookmark(_ bookmark: Bookmark) async throws {
    _ = try await asyncFunction(for: deleteBookmark(bookmark: bookmark))
  }

  func createCollection(named name: String) async throws {
    _ = try await asyncFunction(for: addCollection(name: name))
  }

  func removeCollection(localId: String) async throws {
    _ = try await asyncFunction(for: deleteCollection(localId: localId))
  }

  func addBookmarkToCollection(collectionLocalId: String, bookmark: Bookmark) async throws {
    _ = try await asyncFunction(
      for: addBookmarkToCollection(
        collectionLocalId: collectionLocalId,
        bookmark: bookmark
      )
    )
  }

  func addAyahBookmarkToCollection(collectionLocalId: String, sura: Int32, ayah: Int32) async throws
    -> CollectionBookmark
  {
    try await asyncFunction(
      for: addAyahBookmarkToCollection(
        collectionLocalId: collectionLocalId,
        sura: sura,
        ayah: ayah
      )
    )
  }

  func removeBookmarkFromCollection(collectionLocalId: String, bookmark: Bookmark) async throws {
    _ = try await asyncFunction(
      for: removeBookmarkFromCollection(
        collectionLocalId: collectionLocalId,
        bookmark: bookmark
      )
    )
  }

  func createNote(body: String, startAyahId: Int64, endAyahId: Int64) async throws {
    _ = try await asyncFunction(
      for: addNote(
        body: body,
        startAyahId: startAyahId,
        endAyahId: endAyahId
      )
    )
  }

  func updateNote(localId: String, body: String, startAyahId: Int64, endAyahId: Int64) async throws {
    guard let notesRepository = pipelineForIos.notesRepository as? NotesRepository else {
      throw SyncServiceExtensionError.notesRepositoryUnavailable
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      notesRepository.updateNote(
        localId: localId,
        body: body,
        startAyahId: startAyahId,
        endAyahId: endAyahId
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
}

private enum SyncServiceExtensionError: Error {
  case notesRepositoryUnavailable
}
