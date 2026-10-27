import Foundation
internal import Shared

public enum MobileSyncDataError: Error {
  /// Sign-out is clearing local data, so the write was rejected.
  case sessionResetInProgress(underlying: Error)
  /// MobileSync rejected the request, for example an unknown collection, incompatible import options or a page
  /// its mushaf doesn't have.
  case invalidArgument(underlying: Error)
  /// Any other failure, such as a database error.
  case failed(underlying: Error)

  init(bridgedError error: Error) {
    switch (error as NSError).userInfo["KotlinException"] {
    case is SessionResetInProgressException:
      self = .sessionResetInProgress(underlying: error)
    case is KotlinIllegalArgumentException:
      self = .invalidArgument(underlying: error)
    default:
      self = .failed(underlying: error)
    }
  }

  /// The failure's type without its message, which can contain user content, so it is safe to log.
  public var category: String {
    let error = underlying as NSError
    if let exception = error.userInfo["KotlinException"] {
      return String(describing: type(of: exception))
    }
    return "\(error.domain)#\(error.code)"
  }

  private var underlying: Error {
    switch self {
    case let .sessionResetInProgress(underlying),
      let .invalidArgument(underlying),
      let .failed(underlying):
      underlying
    }
  }
}

func bridgingDataErrors<T>(_ operation: () async throws -> T) async throws -> T {
  do {
    return try await operation()
  } catch {
    throw dataError(bridging: error)
  }
}

func dataError(bridging error: Error) -> Error {
  if error is CancellationError {
    return error
  }
  if (error as NSError).userInfo["KotlinException"] is KotlinCancellationException {
    return CancellationError()
  }
  // These Kotlin exceptions extend IllegalArgumentException, so they're matched before `invalidArgument`.
  if let textLengthLimitError = MobileSyncTextLengthLimitError(bridgedError: error) {
    return textLengthLimitError
  }
  if let readOnlyError = MobileSyncReadOnlyCollectionError(bridgedError: error) {
    return readOnlyError
  }
  if let duplicateNameError = MobileSyncDuplicateCollectionNameError(bridgedError: error) {
    return duplicateNameError
  }
  if let reservedNameError = MobileSyncReservedCollectionNameError(bridgedError: error) {
    return reservedNameError
  }
  return MobileSyncDataError(bridgedError: error)
}
