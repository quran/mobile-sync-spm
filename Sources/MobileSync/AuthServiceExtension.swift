import Foundation
import KMPNativeCoroutinesAsync
import Shared

public extension AuthService {
  func signIn() async throws {
    _ = try await asyncFunction(for: login())
  }

  func signOut() async throws {
    _ = try await asyncFunction(for: logout())
  }

  func refreshAuthentication() async throws -> Bool {
    let refreshed: KotlinBoolean = try await asyncFunction(for: refreshAccessTokenIfNeeded())
    return refreshed.boolValue
  }

  func authenticationHeaders() async throws -> [String: String] {
    try await withCheckedThrowingContinuation { continuation in
      getAuthHeaders { headers, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: headers ?? [:])
        }
      }
    }
  }

  func authStateSequence() -> NativeFlowAsyncSequence<AuthState, Error, KotlinUnit> {
    asyncSequence(for: authStateFlow)
  }
}
