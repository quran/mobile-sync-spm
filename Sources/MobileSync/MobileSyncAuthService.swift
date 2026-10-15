import Foundation
internal import KMPNativeCoroutinesAsync
internal import Shared

/// Signs the user in and out of Quran.com and authenticates their requests.
public struct MobileSyncAuthService: @unchecked Sendable {
  // MobileSync synchronizes the service internally.
  let service: SyncAuthService

  init(_ service: SyncAuthService) {
    self.service = service
  }

  public var isLoggedIn: Bool {
    service.isLoggedIn()
  }

  public var loggedInUser: MobileSyncUser? {
    service.loggedInUser.map(MobileSyncUser.init)
  }

  /// Signs in, asking the identity provider to authenticate the user again.
  public func signInWithReauthentication() async throws(MobileSyncAuthenticationError) {
    do {
      _ = try await asyncFunction(for: service.loginWithReauthentication())
    } catch {
      throw MobileSyncAuthenticationError(bridgedError: error)
    }
  }

  /// Signs out and clears local data.
  public func signOut() async throws(MobileSyncAuthenticationError) {
    do {
      _ = try await asyncFunction(for: service.logout(clearLocalData: true))
    } catch {
      throw MobileSyncAuthenticationError(bridgedError: error)
    }
  }

  /// Restores the stored session, refreshing its tokens if needed.
  /// - Returns: Whether the user is signed in.
  public func refreshAuthentication() async throws(MobileSyncAuthenticationError) -> Bool {
    do {
      let refreshed: KotlinBoolean = try await asyncFunction(for: service.refreshAuthentication())
      return refreshed.boolValue
    } catch {
      throw MobileSyncAuthenticationError(bridgedError: error)
    }
  }

  /// Headers that authenticate a Quran.com request, or none when signed out.
  public func authenticationHeaders() async throws(MobileSyncAuthenticationError) -> [String: String] {
    do {
      return try await asyncFunction(for: service.authenticationHeaders())
    } catch {
      throw MobileSyncAuthenticationError(bridgedError: error)
    }
  }
}
