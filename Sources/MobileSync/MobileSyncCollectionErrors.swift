import Foundation
import Shared

/// Renaming or deleting a collection users can't change: Favorites, the highlight collections, and the color
/// collections older Quran.com apps created, which the server protects.
public struct MobileSyncReadOnlyCollectionError: Error, Equatable, Sendable {
  /// The id of the collection that can't change.
  public let id: String
}

/// Renaming a collection to a name another collection has. Names compare trimmed and case-insensitively.
public struct MobileSyncDuplicateCollectionNameError: Error, Equatable, Sendable {
  /// The name of the collection that already has the name.
  public let name: String
}

extension MobileSyncReadOnlyCollectionError {
  init?(bridgedError error: Error) {
    guard
      let exception = (error as NSError).userInfo["KotlinException"] as? ReadOnlyCollectionException
    else {
      return nil
    }
    id = exception.id
  }
}

extension MobileSyncDuplicateCollectionNameError {
  init?(bridgedError error: Error) {
    guard
      let exception = (error as NSError).userInfo["KotlinException"]
        as? DuplicateCollectionNameException
    else {
      return nil
    }
    name = exception.name
  }
}
