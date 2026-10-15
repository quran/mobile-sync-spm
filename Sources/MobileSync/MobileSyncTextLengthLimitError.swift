import Foundation
internal import Shared

/// A note body or collection name outside the server's length limits.
public struct MobileSyncTextLengthLimitError: Error, Equatable, Sendable {
  /// Which text is out of bounds.
  public enum Field: Equatable, Sendable {
    case noteBody
    case collectionName
  }

  /// Which length limit was crossed.
  public enum Bound: Equatable, Sendable {
    case tooShort
    case tooLong
  }

  /// The text that is out of bounds.
  public let field: Field
  /// Whether the text is under the minimum or over the maximum.
  public let bound: Bound
  /// The minimum for `tooShort`, or the maximum for `tooLong`.
  public let limit: Int
  /// The length as the server measures it: trimmed, HTML-escaped, in UTF-16 code units.
  public let length: Int
}

extension MobileSyncTextLengthLimitError {
  init?(bridgedError error: Error) {
    guard
      let exception = (error as NSError).userInfo["KotlinException"] as? TextLengthLimitException,
      let field = Field(exception.field),
      let bound = Bound(exception.bound)
    else {
      return nil
    }
    self.field = field
    self.bound = bound
    limit = Int(exception.limit)
    length = Int(exception.length)
  }
}

extension MobileSyncTextLengthLimitError.Field {
  fileprivate init?(_ field: TextLengthField) {
    switch field {
    case .noteBody: self = .noteBody
    case .collectionName: self = .collectionName
    default: return nil
    }
  }
}

extension MobileSyncTextLengthLimitError.Bound {
  fileprivate init?(_ bound: TextLengthBound) {
    switch bound {
    case .tooShort: self = .tooShort
    case .tooLong: self = .tooLong
    default: return nil
    }
  }
}
