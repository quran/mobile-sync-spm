import Foundation
import KMPNativeCoroutinesAsync
import Shared

public extension SyncService {
  func bookmarksSequence() -> NativeFlowAsyncSequence<[Bookmark], Error, KotlinUnit> {
    asyncSequence(for: bookmarks)
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

  func addPageBookmark(_ page: Int32) async throws -> Bookmark {
    try await asyncFunction(for: addBookmark(page: page))
  }

  func addAyahBookmark(sura: Int32, ayah: Int32) async throws -> Bookmark {
    try await asyncFunction(for: addBookmark(sura: sura, ayah: ayah))
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

  /// Convenience helper until native update API is exposed by SyncService.
  func replaceNote(localId: String, body: String, startAyahId: Int64, endAyahId: Int64) async throws {
    try await removeNote(localId: localId)
    try await createNote(body: body, startAyahId: startAyahId, endAyahId: endAyahId)
  }

  func removeNote(localId: String) async throws {
    _ = try await asyncFunction(for: deleteNote(localId: localId))
  }
}

private enum SyncServiceExtensionError: Error {
  case notesRepositoryUnavailable
}
