import Foundation
internal import KMPNativeCoroutinesAsync
internal import Shared

/// Reads and writes Quran user data, and syncs it when the user is signed in.
///
/// Reads and writes throw `CancellationError` when cancelled, ``MobileSyncTextLengthLimitError`` when
/// a note body or collection name is outside the length limits, the collection errors documented on
/// each collection write, and ``MobileSyncDataError`` otherwise.
/// Observation sequences end when their task is cancelled and leave out values this package doesn't
/// know yet, such as a new highlight color. Writes default `timestamp` to now.
public struct MobileSyncDataService: @unchecked Sendable {
  // MobileSync synchronizes the service internally.
  let service: QuranDataService

  init(_ service: QuranDataService) {
    self.service = service
  }

  // MARK: Observing

  public func notesSequence() -> MobileSyncAsyncSequence<[MobileSyncNote]> {
    sequence(asyncSequence(for: service.notes)) { $0.map(MobileSyncNote.init) }
  }

  /// The default collection first, then user collections, each with its bookmarks, after every change.
  public func collectionsWithBookmarksSequence()
    -> MobileSyncAsyncSequence<[MobileSyncCollectionWithBookmarks]>
  {
    sequence(asyncSequence(for: service.collectionsWithBookmarks)) {
      $0.map(MobileSyncCollectionWithBookmarks.init)
    }
  }

  public func highlightsSequence() -> MobileSyncAsyncSequence<[MobileSyncAyahHighlight]> {
    sequence(asyncSequence(for: service.highlights)) { $0.compactMap(MobileSyncAyahHighlight.init) }
  }

  /// The reading-bookmark slots that have ever been written, after every change; a slot that was never written
  /// isn't in the list, and a cleared slot stays listed as ``MobileSyncReadingBookmark/Placement/unplaced``.
  /// Page bookmarks are pages of `mushaf`, the mushaf the app shows, mapped from whichever mushaf they were set
  /// in. A page `mushaf` can't show comes back ``MobileSyncReadingBookmark/Placement/unplaced``.
  public func readingBookmarksSequence(mushaf: MobileSyncMushaf)
    -> MobileSyncAsyncSequence<[MobileSyncReadingBookmark]>
  {
    sequence(asyncSequence(for: service.readingBookmarks(mushaf: mushaf.kotlinMushaf))) {
      $0.compactMap(MobileSyncReadingBookmark.init)
    }
  }

  public func readingSessionsSequence() -> MobileSyncAsyncSequence<[MobileSyncReadingSession]> {
    sequence(asyncSequence(for: service.readingSessions)) { $0.map(MobileSyncReadingSession.init) }
  }

  // MARK: Syncing

  /// The sync status now and after every change, for a live spinner or error. See ``MobileSyncStatus`` for how
  /// retries and sign-out show; it isn't persisted, so take "Last synced" from ``syncHistorySequence()``.
  public func syncStatusSequence() -> MobileSyncAsyncSequence<MobileSyncStatus> {
    MobileSyncAsyncSequence(
      asyncSequence(for: service.syncStatusFlow).compactMap(MobileSyncStatus.init),
      mapError: dataError(bridging:)
    )
  }

  /// The newest sync runs first, at most 50, after every change. Sign-out and an account switch clear them with
  /// the rest of the data.
  public func syncHistorySequence() -> MobileSyncAsyncSequence<[MobileSyncRun]> {
    sequence(asyncSequence(for: service.syncHistory)) { $0.compactMap(MobileSyncRun.init) }
  }

  /// The items that don't sync, held ones first, then the ones waiting on them. It changes as soon as an item is
  /// held or released, without waiting for a sync. Sign-out and an account switch clear them with the rest of the
  /// data.
  public func heldItemsSequence() -> MobileSyncAsyncSequence<[MobileSyncHeldItem]> {
    sequence(asyncSequence(for: service.heldItems)) { $0.compactMap(MobileSyncHeldItem.init) }
  }

  /// How many items have local changes the server doesn't have yet, after every change: the ones the next sync sends
  /// and the held ones, counted apart from one read. Sign-out deletes them all, so an app can warn with these counts.
  /// It may over-count pending items before the first sync and while a sent batch's answer is unknown.
  ///
  /// Every write re-reads it, so observe it only while it's shown. For a one-off read, such as a sign-out warning,
  /// take its first value.
  public func unsyncedItemsSequence() -> MobileSyncAsyncSequence<MobileSyncUnsyncedItemCounts> {
    sequence(asyncSequence(for: service.unsyncedItems), transform: MobileSyncUnsyncedItemCounts.init)
  }

  /// Schedules a sync when the user is signed in.
  ///
  /// - Parameter immediately: `false` waits a few seconds so a burst of edits syncs once. `true` starts now, such
  ///   as for a user's "Sync now"; while a sync runs, another starts right after it.
  public func triggerSync(immediately: Bool) {
    service.triggerSync(immediately: immediately)
  }

  /// Tells sync the app came back to the foreground, so it syncs soon; ``syncHistorySequence()`` records the run as
  /// ``MobileSyncRunTrigger/foreground``. Call it on each return from the background, not at launch, which has its
  /// own sync.
  ///
  /// Like a local change, the run starts after a few seconds and only pulls while pushes back off after a failure. A
  /// run already due sooner runs in its place, keeping its own trigger; during a run it runs again after it; while a
  /// failed run waits to retry, it is dropped. Without a signed-in user, nothing syncs.
  public func syncOnForeground() {
    service.syncOnForeground()
  }

  // MARK: Profile

  /// Fetches the signed-in user's profile from Quran.com now, so a name or photo changed there reaches
  /// ``MobileSyncAuthService/loggedInUserUpdates``. Call it when the user may have just edited their profile, such as
  /// when a Quran.com account page the app opened closes. A call while a fetch runs joins it.
  ///
  /// MobileSync also fetches the profile on its own: during the sign-in's sync, and about once a day during a sync.
  /// Without a signed-in user, or while signing out, it returns without a request. A failure keeps the user and the
  /// session.
  ///
  /// - Throws: `CancellationError`, or ``MobileSyncDataError`` when the fetch failed: no network, an error status, or
  ///   a response that isn't a profile.
  public func refreshProfile() async throws {
    _ = try await bridgingDataErrors { try await asyncFunction(for: service.refreshProfile()) }
  }

  // MARK: Importing

  /// Merges local data and optionally records handled content so later tracked imports skip it.
  /// `deleteExisting` preserves import history and cannot be combined with `trackHistory`.
  public func importData(
    _ data: MobileSyncImportData,
    deleteExisting: Bool = false,
    trackHistory: Bool = false
  ) async throws -> MobileSyncImportResult {
    let result = try await bridgingDataErrors {
      try await asyncFunction(
        for: service.importData(
          data: data.kotlinData,
          deleteExisting: deleteExisting,
          trackHistory: trackHistory
        )
      )
    }
    return MobileSyncImportResult(result)
  }

  // MARK: Notes

  public func createNote(
    body: String,
    startSura: Int,
    startAyah: Int,
    endSura: Int,
    endAyah: Int,
    timestamp: Date = Date()
  ) async throws {
    _ = try await bridgingDataErrors {
      try await asyncFunction(
        for: service.addNote(
          body: body,
          startSura: Int32(startSura),
          startAyah: Int32(startAyah),
          endSura: Int32(endSura),
          endAyah: Int32(endAyah),
          timestamp: timestamp
        )
      )
    }
  }

  /// Changes a note's body. A note's verse ranges never change.
  public func updateNote(id: String, body: String, timestamp: Date = Date()) async throws {
    _ = try await bridgingDataErrors {
      try await asyncFunction(for: service.updateNote(id: id, body: body, timestamp: timestamp))
    }
  }

  /// - Returns: Whether a note was deleted.
  @discardableResult
  public func deleteNote(id: String) async throws -> Bool {
    try await bridgingBool { try await asyncFunction(for: service.deleteNote(id: id)) }
  }

  // MARK: Collections

  /// - Throws: ``MobileSyncReservedCollectionNameError`` when the name is reserved.
  public func createCollection(named name: String, timestamp: Date = Date()) async throws
    -> MobileSyncCollection
  {
    let collection = try await bridgingDataErrors {
      try await asyncFunction(for: service.addCollection(name: name, timestamp: timestamp))
    }
    return MobileSyncCollection(collection)
  }

  /// - Throws: ``MobileSyncReadOnlyCollectionError`` when the collection can't be renamed,
  ///   ``MobileSyncReservedCollectionNameError`` when the name is reserved,
  ///   ``MobileSyncDuplicateCollectionNameError`` when another collection has the name, and
  ///   `MobileSyncDataError.invalidArgument` when `id` isn't an active collection.
  public func updateCollection(id: String, name: String, timestamp: Date = Date()) async throws
    -> MobileSyncCollection
  {
    let collection = try await bridgingDataErrors {
      try await asyncFunction(for: service.updateCollection(id: id, name: name, timestamp: timestamp))
    }
    return MobileSyncCollection(collection)
  }

  /// - Returns: Whether a collection was deleted.
  /// - Throws: ``MobileSyncReadOnlyCollectionError`` when the collection can't be deleted.
  @discardableResult
  public func removeCollection(id: String) async throws -> Bool {
    try await bridgingBool { try await asyncFunction(for: service.deleteCollection(id: id)) }
  }

  public func addAyahBookmarkToCollection(
    collectionID: String,
    sura: Int,
    ayah: Int,
    timestamp: Date = Date()
  ) async throws -> MobileSyncCollectionBookmark {
    let bookmark = try await bridgingDataErrors {
      try await asyncFunction(
        for: service.addAyahBookmarkToCollection(
          collectionId: collectionID,
          sura: Int32(sura),
          ayah: Int32(ayah),
          timestamp: timestamp
        )
      )
    }
    return MobileSyncCollectionBookmark(bookmark)
  }

  /// - Returns: Whether a membership was removed.
  @discardableResult
  public func removeAyahBookmarkFromCollection(collectionID: String, bookmarkID: String) async throws
    -> Bool
  {
    try await bridgingBool {
      try await asyncFunction(
        for: service.removeAyahBookmarkFromCollection(collectionId: collectionID, bookmarkId: bookmarkID)
      )
    }
  }

  // MARK: Highlights

  public func setAyahHighlight(
    sura: Int,
    ayah: Int,
    color: MobileSyncHighlightColor,
    timestamp: Date = Date()
  ) async throws -> MobileSyncAyahHighlight {
    let highlight = try await bridgingDataErrors {
      try await asyncFunction(
        for: service.setHighlight(
          sura: Int32(sura),
          ayah: Int32(ayah),
          color: color.kotlinColor,
          timestamp: timestamp
        )
      )
    }
    return try known(MobileSyncAyahHighlight(highlight))
  }

  /// - Returns: Whether a highlight was removed.
  @discardableResult
  public func deleteAyahHighlight(sura: Int, ayah: Int) async throws -> Bool {
    try await bridgingBool {
      try await asyncFunction(for: service.deleteHighlight(sura: Int32(sura), ayah: Int32(ayah)))
    }
  }

  // MARK: Reading bookmarks

  public func setAyahReadingBookmark(
    slot: MobileSyncReadingBookmarkSlot,
    sura: Int,
    ayah: Int,
    timestamp: Date = Date()
  ) async throws -> MobileSyncReadingBookmark {
    try await bridgingReadingBookmark {
      try await asyncFunction(
        for: service.setAyahReadingBookmark(
          slot: slot.kotlinSlot, sura: Int32(sura), ayah: Int32(ayah), timestamp: timestamp)
      )
    }
  }

  /// Sets a slot to `page` of `mushaf`, numbered as ``MobileSyncMushaf`` describes.
  ///
  /// - Throws: `MobileSyncDataError.invalidArgument` when `mushaf` has no such page.
  public func setPageReadingBookmark(
    slot: MobileSyncReadingBookmarkSlot,
    page: Int,
    mushaf: MobileSyncMushaf,
    timestamp: Date = Date()
  ) async throws -> MobileSyncReadingBookmark {
    guard let kotlinPage = Int32(exactly: page) else {
      throw MobileSyncDataError.invalidArgument(underlying: PageOutOfRangeError(page: page))
    }
    return try await bridgingReadingBookmark {
      try await asyncFunction(
        for: service.setPageReadingBookmark(
          slot: slot.kotlinSlot, page: kotlinPage, mushaf: mushaf.kotlinMushaf, timestamp: timestamp)
      )
    }
  }

  /// Renames a slot without moving its bookmark and returns it read in `mushaf`, like
  /// ``readingBookmarksSequence(mushaf:)``. A `nil` name clears it.
  public func renameReadingBookmark(
    slot: MobileSyncReadingBookmarkSlot,
    name: String?,
    mushaf: MobileSyncMushaf,
    timestamp: Date = Date()
  ) async throws -> MobileSyncReadingBookmark {
    try await bridgingReadingBookmark {
      try await asyncFunction(
        for: service.renameReadingBookmark(
          slot: slot.kotlinSlot, name: name, mushaf: mushaf.kotlinMushaf, timestamp: timestamp)
      )
    }
  }

  /// Removes a slot's placement and keeps its name.
  public func clearReadingBookmark(
    slot: MobileSyncReadingBookmarkSlot,
    timestamp: Date = Date()
  ) async throws -> MobileSyncReadingBookmark {
    try await bridgingReadingBookmark {
      try await asyncFunction(
        for: service.clearReadingBookmark(slot: slot.kotlinSlot, timestamp: timestamp)
      )
    }
  }

  // MARK: Reading sessions

  public func addReadingSession(sura: Int, ayah: Int, timestamp: Date = Date()) async throws
    -> MobileSyncReadingSession
  {
    let session = try await bridgingDataErrors {
      try await asyncFunction(
        for: service.addReadingSession(sura: Int32(sura), ayah: Int32(ayah), timestamp: timestamp)
      )
    }
    return MobileSyncReadingSession(session)
  }

  /// Moves a reading session. The result is authoritative: when another session is already at the
  /// destination, the two merge under that session's ID.
  public func updateReadingSession(id: String, sura: Int, ayah: Int, timestamp: Date = Date()) async throws
    -> MobileSyncReadingSession
  {
    let session = try await bridgingDataErrors {
      try await asyncFunction(
        for: service.updateReadingSession(
          id: id, sura: Int32(sura), ayah: Int32(ayah), timestamp: timestamp)
      )
    }
    return MobileSyncReadingSession(session)
  }

  // MARK: Private

  private func sequence<Values: AsyncSequence, Element>(
    _ values: Values,
    transform: @escaping @Sendable (Values.Element) -> Element
  ) -> MobileSyncAsyncSequence<Element> {
    MobileSyncAsyncSequence(values.map(transform), mapError: dataError(bridging:))
  }

  private func bridgingBool(_ operation: () async throws -> KotlinBoolean) async throws -> Bool {
    try await bridgingDataErrors(operation).boolValue
  }

  private func bridgingReadingBookmark(
    _ operation: () async throws -> any ReadingBookmark
  ) async throws -> MobileSyncReadingBookmark {
    try known(MobileSyncReadingBookmark(try await bridgingDataErrors(operation)))
  }

  /// Fails a write whose result holds a value this package doesn't know yet. The write was already saved.
  private func known<Value>(_ value: Value?) throws -> Value {
    guard let value else {
      throw MobileSyncDataError.failed(underlying: UnknownValueError(type: String(describing: Value.self)))
    }
    return value
  }
}

/// A Kotlin result that holds a value this package doesn't know yet.
struct UnknownValueError: Error {
  let type: String
}

/// A page number too large for MobileSync, so no mushaf has it.
struct PageOutOfRangeError: Error {
  let page: Int
}
