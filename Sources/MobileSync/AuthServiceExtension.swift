import Foundation
internal import KMPNativeCoroutinesAsync
import Shared

extension SyncAuthService {
  public func signIn() async throws(MobileSyncAuthenticationError) {
    do {
      _ = try await asyncFunction(for: login())
    } catch {
      throw MobileSyncAuthenticationError(bridgedError: error)
    }
  }

  public func signInWithReauthentication() async throws(MobileSyncAuthenticationError) {
    do {
      _ = try await asyncFunction(for: loginWithReauthentication())
    } catch {
      throw MobileSyncAuthenticationError(bridgedError: error)
    }
  }

  public func signOut() async throws(MobileSyncAuthenticationError) {
    do {
      _ = try await asyncFunction(for: self.logout(clearLocalData: true))
    } catch {
      throw MobileSyncAuthenticationError(bridgedError: error)
    }
  }

  public func refreshAuthentication() async throws(MobileSyncAuthenticationError) -> Bool {
    do {
      let refreshed: KotlinBoolean = try await asyncFunction(for: self.refreshAuthentication())
      return refreshed.boolValue
    } catch {
      throw MobileSyncAuthenticationError(bridgedError: error)
    }
  }

  public func authenticationHeaders() async throws(MobileSyncAuthenticationError) -> [String:
    String]
  {
    do {
      return try await asyncFunction(for: self.authenticationHeaders())
    } catch {
      throw MobileSyncAuthenticationError(bridgedError: error)
    }
  }

  public func authStateSequence() -> MobileSyncAsyncSequence<AuthState> {
    MobileSyncAsyncSequence(asyncSequence(for: authStateFlow))
  }
}
