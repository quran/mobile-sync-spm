import Foundation
import Shared

/// Swift-native authentication failures produced by MobileSync.
public enum MobileSyncAuthenticationError: Error {
  case cancelled
  case networkFailure(underlying: Error)
  case authenticationFailed(underlying: Error)

  init(bridgedError error: Error) {
    if error is CancellationError {
      self = .cancelled
      return
    }

    let kotlinException = (error as NSError).userInfo["KotlinException"]
    switch kotlinException {
    case is AuthenticationCancelledException:
      self = .cancelled
    case is AuthenticationNetworkException:
      self = .networkFailure(underlying: error)
    case is AuthenticationFailedException:
      self = .authenticationFailed(underlying: error)
    default:
      let nsError = error as NSError
      if nsError.domain == NSURLErrorDomain {
        self = .networkFailure(underlying: error)
      } else {
        self = .authenticationFailed(underlying: error)
      }
    }
  }
}
