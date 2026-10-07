import Foundation
import Shared

/// Swift-native failures opening MobileSync's database.
///
/// `storageFull` is reported only when SQLite surfaces SQLITE_FULL. A full disk can also arrive as
/// `openFailed`, for example as SQLITE_CANTOPEN or a failed rollback that hides SQLITE_FULL.
/// Callers that need certainty should check free space.
public enum MobileSyncDatabaseError: Error {
  /// SQLite reported the disk is full (SQLITE_FULL).
  case storageFull(underlying: Error)
  /// Any other failure to open the database, which can include a full disk.
  case openFailed(underlying: Error)

  init(bridgedError error: Error) {
    let kotlinException = (error as NSError).userInfo["KotlinException"]
    switch kotlinException {
    case is DatabaseStorageFullException:
      self = .storageFull(underlying: error)
    default:
      self = .openFailed(underlying: error)
    }
  }
}
