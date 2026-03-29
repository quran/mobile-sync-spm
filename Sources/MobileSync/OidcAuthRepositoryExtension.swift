import Foundation
@preconcurrency import Shared

public extension OidcAuthRepository {
  func canResumeLogin() async throws -> Bool {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
      canContinueLogin { result, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: result?.boolValue ?? false)
        }
      }
    }
  }

  func resumeLogin() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      continueLogin { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }
}
