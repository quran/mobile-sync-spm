import Foundation
import KMPNativeCoroutinesAsync
@preconcurrency import Shared

/**
 * Swift-side sync wrapper around the shared services.
 *
 * This keeps the iOS consumer close to the demo setup while hiding the KMP coroutine bridge
 * details inside the SPM package.
 */
public final class SyncViewModel {
  private let authService: AuthService
  public let syncService: SyncService

  public init(container: AppContainer) {
    authService = container.authService
    syncService = container.syncService
  }

  public func authStateSequence() -> NativeFlowAsyncSequence<AuthState, Error, KotlinUnit> {
    asyncSequence(for: syncService.authStateFlow)
  }

  public func bookmarksSequence() -> NativeFlowAsyncSequence<[Bookmark], Error, KotlinUnit> {
    asyncSequence(for: syncService.bookmarks)
  }

  public func collectionsWithBookmarksSequence()
    -> NativeFlowAsyncSequence<[CollectionWithBookmarks], Error, KotlinUnit>
  {
    asyncSequence(for: syncService.collectionsWithBookmarks)
  }

  public func notesSequence() -> NativeFlowAsyncSequence<[Note_], Error, KotlinUnit> {
    asyncSequence(for: syncService.notes)
  }

  public func bookmarksForCollection(collectionId: String)
    -> NativeFlowAsyncSequence<[CollectionBookmark], Error, KotlinUnit>
  {
    asyncSequence(for: syncService.getBookmarksForCollectionFlow(collectionLocalId: collectionId))
  }

  public func triggerSync() {
    syncService.triggerSync()
  }

  public func addBookmark(page: Int32) async throws -> Bookmark {
    try await asyncFunction(for: syncService.addBookmark(page: page))
  }

  public func addBookmark(sura: Int32, ayah: Int32) async throws -> Bookmark {
    try await asyncFunction(for: syncService.addBookmark(sura: sura, ayah: ayah))
  }

  public func deleteBookmark(bookmark: Bookmark) async throws {
    _ = try await asyncFunction(for: syncService.deleteBookmark(bookmark: bookmark))
  }

  public func addCollection(name: String) async throws {
    _ = try await asyncFunction(for: syncService.addCollection(name: name))
  }

  public func deleteCollection(collectionId: String) async throws {
    _ = try await asyncFunction(for: syncService.deleteCollection(localId: collectionId))
  }

  public func addNote(body: String, startAyahId: Int64, endAyahId: Int64) async throws {
    _ = try await asyncFunction(
      for: syncService.addNote(
        body: body,
        startAyahId: startAyahId,
        endAyahId: endAyahId
      )
    )
  }

  public func deleteNote(localId: String) async throws {
    _ = try await asyncFunction(for: syncService.deleteNote(localId: localId))
  }

  public func addBookmarkToCollection(collectionId: String, bookmark: Bookmark) async throws {
    _ = try await asyncFunction(
      for: syncService.addBookmarkToCollection(
        collectionLocalId: collectionId,
        bookmark: bookmark
      )
    )
  }

  public func removeBookmarkFromCollection(collectionId: String, bookmark: Bookmark) async throws {
    _ = try await asyncFunction(
      for: syncService.removeBookmarkFromCollection(
        collectionLocalId: collectionId,
        bookmark: bookmark
      )
    )
  }

  public func login() async throws {
    try await asyncFunction(for: authService.login())
  }

  public func logout() async throws {
    try await asyncFunction(for: authService.logout())
  }

  public func refreshAccessTokenIfNeeded() async throws -> Bool {
    let refreshed: KotlinBoolean = try await asyncFunction(for: authService.refreshAccessTokenIfNeeded())
    return refreshed.boolValue
  }

  public func getAuthHeaders() async throws -> [String: String] {
    try await withCheckedThrowingContinuation { continuation in
      authService.getAuthHeaders { headers, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: headers ?? [:])
        }
      }
    }
  }

  public func isLoggedIn() -> Bool {
    authService.isLoggedIn()
  }

  public func clearError() {
    authService.clearError()
  }
}
