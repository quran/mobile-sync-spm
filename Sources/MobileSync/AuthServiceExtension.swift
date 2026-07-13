import Foundation
internal import KMPNativeCoroutinesAsync
import Shared

public extension SyncAuthService {
  func signIn() async throws {
    _ = try await asyncFunction(for: login())
  }

  func signInWithReauthentication() async throws {
    _ = try await asyncFunction(for: loginWithReauthentication())
  }

  func signOut() async throws {
    _ = try await asyncFunction(for: self.logout(clearLocalData: true))
  }

  func refreshAuthentication() async throws -> Bool {
    let refreshed: KotlinBoolean = try await asyncFunction(for: self.refreshAuthentication())
    return refreshed.boolValue
  }

  func authenticationHeaders() async throws -> [String: String] {
    try await asyncFunction(for: self.authenticationHeaders())
  }

  func authStateSequence() -> MobileSyncAsyncSequence<AuthState> {
    MobileSyncAsyncSequence(asyncSequence(for: authStateFlow))
  }
}
