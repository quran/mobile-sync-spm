import Foundation
internal import Shared

/// The state of sync in this app session. It isn't persisted, so it starts as ``idle`` on every launch.
///
/// A sync that fails is retried a few times: it is ``syncing`` while an attempt runs and
/// ``retrying(failedAt:error:nextAttemptAt:)`` while it waits for the next one, until it succeeds or gives up. A
/// sync that ends without syncing, because no one is signed in or a sign-out stopped it, leaves the status as it was.
public enum MobileSyncStatus: Hashable, Sendable {
  /// No sync has finished since launch, or a sign-out cleared the previous result.
  case idle
  /// A signed-in sync attempt is running: the first one, or a retry.
  case syncing
  /// The latest attempt failed at `failedAt` because of `error`, and the sync tries again at `nextAttemptAt` on its
  /// own, becoming ``syncing``. No attempt is running, so an app can offer "Try again"
  /// (`triggerSync(immediately: true)`), which runs at once instead of waiting.
  case retrying(failedAt: Date, error: MobileSyncRunError, nextAttemptAt: Date)
  /// The latest sync finished at `at`.
  case succeeded(at: Date)
  /// The latest sync gave up at `at` after its retries.
  case failed(at: Date, error: MobileSyncRunError)
}

/// One sync run: the first attempt and its retries. It never carries user data or server messages.
public struct MobileSyncRun: Hashable, Sendable {
  /// When the first attempt began contacting the sync server.
  public let startedAt: Date
  /// When the run ended: it succeeded, pulled only, failed with no retries left, or was cancelled.
  public let endedAt: Date
  public let trigger: MobileSyncRunTrigger
  public let result: MobileSyncRunResult
  /// The first attempt plus each retry.
  public let attempts: Int
  /// The local changes the server accepted.
  public let pushed: Int
  /// The local items the run created, changed or deleted to take the server's changes.
  public let pulled: Int
  /// The items that weren't syncing when the run ended, counted like
  /// ``MobileSyncDataService/heldItemsSequence()``.
  public let held: Int
  /// Why the run failed: non-nil exactly when ``result`` is ``MobileSyncRunResult/failed``.
  public let error: MobileSyncRunError?

  public init(
    startedAt: Date,
    endedAt: Date,
    trigger: MobileSyncRunTrigger,
    result: MobileSyncRunResult,
    attempts: Int,
    pushed: Int,
    pulled: Int,
    held: Int,
    error: MobileSyncRunError?
  ) {
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.trigger = trigger
    self.result = result
    self.attempts = attempts
    self.pushed = pushed
    self.pulled = pulled
    self.held = held
    self.error = error
  }
}

/// What started a sync run.
public enum MobileSyncRunTrigger: Hashable, Sendable {
  /// The first sync after launch.
  case appStart
  /// Local data changed, or `triggerSync(immediately: false)`.
  case localChange
  /// The app came back to the foreground: `syncOnForeground()`.
  case foreground
  /// The periodic sync came due.
  case periodic
  /// `triggerSync(immediately: true)`, such as a user's "Sync now".
  case manual
  /// A user signed in. A session restored at launch is ``appStart``.
  case signIn
}

/// How a sync run ended.
public enum MobileSyncRunResult: Hashable, Sendable {
  /// It pulled the server's changes and pushed the local ones.
  case succeeded
  /// It pulled the server's changes but pushed nothing, because pushes are paused after a failure.
  /// ``MobileSyncStatus`` keeps showing that failure until a run that pushes succeeds.
  case pulledOnly
  /// It failed with no retries left. ``MobileSyncRun/error`` says why.
  case failed
  /// It was stopped before it ended, such as by "Sync now" or a sign-in replacing a waiting retry. Its counts are
  /// what it did until then.
  case cancelled
}

/// Why a sync run failed, safe to show and to log: it never carries response bodies or user data.
public struct MobileSyncRunError: Hashable, Sendable {
  /// A stable failure category to localize from.
  public enum Kind: Hashable, Sendable {
    /// The sync server couldn't be reached, or the connection dropped or timed out.
    case network
    /// The sync server didn't accept the session (HTTP 401 or 403).
    case authentication
    /// The sync server failed or was unavailable (HTTP 5xx, 408 or 429).
    case server
    /// The sync server rejected the request (any other HTTP 4xx).
    case rejected
    /// Any other failure, such as an invalid response or a local storage error, or a kind this package doesn't
    /// know yet.
    case unknown
  }

  public let kind: Kind
  /// The HTTP status when the server answered with an error.
  public let httpStatus: Int?
  /// The server's error identifier, such as `UniqueViolationError`.
  public let serverCode: String?
  /// A short English description for diagnostics; localize from ``kind`` instead.
  public let message: String

  public init(kind: Kind, httpStatus: Int?, serverCode: String?, message: String) {
    self.kind = kind
    self.httpStatus = httpStatus
    self.serverCode = serverCode
    self.message = message
  }
}

/// A local item that doesn't sync: held because the server would refuse it (or did), or waiting on a held item.
/// It stays on the device and syncs again once the user edits it into something the server accepts, the hold
/// expires, or an update of MobileSync releases every hold. It never carries user data or server messages.
public struct MobileSyncHeldItem: Hashable, Sendable {
  /// The held item another one waits on. It is in the held items too, and waits on nothing itself.
  public struct Blocker: Hashable, Sendable {
    public let type: MobileSyncResourceType
    /// The held item's ``MobileSyncHeldItem/id``.
    public let id: String
    /// The held item's ``MobileSyncHeldItem/collectionID``.
    public let collectionID: String?
    public let reason: MobileSyncHeldReason

    public init(type: MobileSyncResourceType, id: String, collectionID: String?, reason: MobileSyncHeldReason) {
      self.type = type
      self.id = id
      self.collectionID = collectionID
      self.reason = reason
    }
  }

  public let type: MobileSyncResourceType
  /// The item's id as the other models carry it; for a ``MobileSyncResourceType/collectionBookmark``, its
  /// ``MobileSyncCollectionBookmark/bookmarkID`` (`sura:ayah`). An item held while being deleted is no longer in
  /// the other models.
  public let id: String
  /// For a ``MobileSyncResourceType/collectionBookmark``, its collection's id (a hidden collection for a
  /// highlight).
  public let collectionID: String?
  public let reason: MobileSyncHeldReason
  /// For ``MobileSyncHeldReason/rejectedByServer``, the HTTP status the server refused it with.
  public let httpStatus: Int?
  /// For ``MobileSyncHeldReason/rejectedByServer``, the server's error code, such as `UniqueViolationError`.
  public let serverCode: String?
  /// For ``MobileSyncHeldReason/waitingOnParent`` and ``MobileSyncHeldReason/waitingOnOtherItem``, the held item
  /// it waits on.
  public let waitingOn: Blocker?

  public init(
    type: MobileSyncResourceType,
    id: String,
    collectionID: String?,
    reason: MobileSyncHeldReason,
    waitingOn: Blocker?,
    httpStatus: Int?,
    serverCode: String?
  ) {
    self.type = type
    self.id = id
    self.collectionID = collectionID
    self.reason = reason
    self.waitingOn = waitingOn
    self.httpStatus = httpStatus
    self.serverCode = serverCode
  }
}

/// The items whose local changes the server doesn't have yet, which sign-out deletes. Both counts come from one read,
/// and each item is in exactly one of them, so `pending + held` is the total.
public struct MobileSyncUnsyncedItemCounts: Hashable, Sendable {
  /// The items the next sync sends: new, edited or deleted since they last synced, and not held.
  public let pending: Int
  /// The items that don't sync until they're fixed: exactly the ``MobileSyncDataService/heldItemsSequence()`` items,
  /// so the held ones and the ones waiting on them.
  public let held: Int

  public init(pending: Int, held: Int) {
    self.pending = pending
    self.held = held
  }
}

/// The kinds of synced items.
public enum MobileSyncResourceType: Hashable, Sendable {
  case note
  case collection
  /// An ayah bookmark in a collection: Favorites, a user collection, or a highlight.
  case collectionBookmark
  case readingSession
  case readingBookmark
}

/// Why a ``MobileSyncHeldItem`` doesn't sync.
public enum MobileSyncHeldReason: Hashable, Sendable {
  /// A note body or collection name is shorter than the server accepts.
  case tooShort
  /// A note body, collection name or reading bookmark name is longer than the server accepts.
  case tooLong
  /// A note's verse range doesn't exist or runs backwards.
  case invalidRange
  /// The verse doesn't exist.
  case invalidVerse
  /// A reading bookmark's location doesn't exist.
  case invalidLocation
  /// A reading bookmark's slot isn't one the server knows.
  case invalidSlot
  /// A reading bookmark carries more metadata than the server accepts.
  case tooMuchMetadata
  /// The server reserves the collection name.
  case reservedName
  /// The collection can't be renamed or deleted.
  case readOnly
  /// The server refused it (``MobileSyncHeldItem/httpStatus``, ``MobileSyncHeldItem/serverCode``), or, with
  /// neither, for a reason MobileSync doesn't know.
  case rejectedByServer
  /// Its collection is held and the server never received it.
  case waitingOnParent
  /// It takes a name or slot that a held item still has on the server.
  case waitingOnOtherItem
  /// Only a sync can link it to the server's copy (Favorites), and none has brought that copy yet.
  case notYetLinked
}

// MARK: - Kotlin mapping

extension MobileSyncStatus {
  /// Returns `nil` for a status this package doesn't know yet.
  init?(_ status: SyncStatus) {
    switch status {
    case is SyncStatus.Idle:
      self = .idle
    case is SyncStatus.Syncing:
      self = .syncing
    case let status as SyncStatus.Retrying:
      self = .retrying(
        failedAt: status.failedAt, error: MobileSyncRunError(status.error), nextAttemptAt: status.nextAttemptAt)
    case let status as SyncStatus.Succeeded:
      self = .succeeded(at: status.at)
    case let status as SyncStatus.Failed:
      self = .failed(at: status.at, error: MobileSyncRunError(status.error))
    default:
      // A status this package doesn't know yet is dropped, so the sequence keeps showing the previous one.
      return nil
    }
  }
}

extension MobileSyncRun {
  /// Returns `nil` when the run's trigger or result is unknown.
  init?(_ run: SyncRun) {
    guard let trigger = MobileSyncRunTrigger(run.trigger), let result = MobileSyncRunResult(run.result) else {
      return nil
    }
    self.init(
      startedAt: run.startedAt,
      endedAt: run.endedAt,
      trigger: trigger,
      result: result,
      attempts: Int(run.attempts),
      pushed: Int(run.pushed),
      pulled: Int(run.pulled),
      held: Int(run.held),
      error: run.error.map(MobileSyncRunError.init)
    )
  }
}

extension MobileSyncRunTrigger {
  /// Returns `nil` for a trigger this package doesn't know yet.
  init?(_ trigger: SyncRunTrigger) {
    switch trigger {
    case .appStart: self = .appStart
    case .localChange: self = .localChange
    case .foreground: self = .foreground
    case .periodic: self = .periodic
    case .manual: self = .manual
    case .signIn: self = .signIn
    default: return nil
    }
  }
}

extension MobileSyncRunResult {
  /// Returns `nil` for a result this package doesn't know yet.
  init?(_ result: SyncRunResult) {
    switch result {
    case .succeeded: self = .succeeded
    case .pulledOnly: self = .pulledOnly
    case .failed: self = .failed
    case .cancelled: self = .cancelled
    default: return nil
    }
  }
}

extension MobileSyncRunError {
  init(_ error: SyncError) {
    self.init(
      kind: Kind(error.kind),
      httpStatus: error.httpStatus.map { Int($0.int32Value) },
      serverCode: error.serverCode,
      message: error.message
    )
  }
}

extension MobileSyncRunError.Kind {
  /// A kind this package doesn't know yet is ``unknown``, so a failure still shows.
  init(_ kind: SyncErrorKind) {
    switch kind {
    case .network: self = .network
    case .authentication: self = .authentication
    case .server: self = .server
    case .rejected: self = .rejected
    default: self = .unknown
    }
  }
}

extension MobileSyncHeldItem {
  /// Returns `nil` when the item's type or reason, or the item it waits on, is unknown.
  init?(_ item: HeldSyncItem) {
    guard let type = MobileSyncResourceType(item.type), let reason = MobileSyncHeldReason(item.reason) else {
      return nil
    }
    var waitingOn: Blocker?
    if let blocker = item.waitingOn {
      guard let type = MobileSyncResourceType(blocker.type), let reason = MobileSyncHeldReason(blocker.reason) else {
        return nil
      }
      waitingOn = Blocker(type: type, id: blocker.id, collectionID: blocker.collectionId, reason: reason)
    }
    self.init(
      type: type,
      id: item.id,
      collectionID: item.collectionId,
      reason: reason,
      waitingOn: waitingOn,
      httpStatus: item.httpStatus.map { Int($0.int32Value) },
      serverCode: item.serverCode
    )
  }
}

extension MobileSyncUnsyncedItemCounts {
  init(_ counts: UnsyncedItemCounts) {
    self.init(pending: Int(counts.pending), held: Int(counts.held))
  }
}

extension MobileSyncResourceType {
  /// Returns `nil` for a type this package doesn't know yet.
  init?(_ type: SyncResourceType) {
    switch type {
    case .note: self = .note
    case .collection: self = .collection
    case .collectionBookmark: self = .collectionBookmark
    case .readingSession: self = .readingSession
    case .readingBookmark: self = .readingBookmark
    default: return nil
    }
  }
}

extension MobileSyncHeldReason {
  /// Returns `nil` for a reason this package doesn't know yet.
  init?(_ reason: HeldReason) {
    switch reason {
    case .tooShort: self = .tooShort
    case .tooLong: self = .tooLong
    case .invalidRange: self = .invalidRange
    case .invalidVerse: self = .invalidVerse
    case .invalidLocation: self = .invalidLocation
    case .invalidSlot: self = .invalidSlot
    case .tooMuchMetadata: self = .tooMuchMetadata
    case .reservedName: self = .reservedName
    case .readOnly: self = .readOnly
    case .rejectedByServer: self = .rejectedByServer
    case .waitingOnParent: self = .waitingOnParent
    case .waitingOnOtherItem: self = .waitingOnOtherItem
    case .notYetLinked: self = .notYetLinked
    default: return nil
    }
  }
}
