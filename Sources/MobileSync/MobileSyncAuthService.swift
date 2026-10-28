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

  /// The signed-in user now and after every change, such as a token refresh that updates the profile.
  ///
  /// It yields the current user first, then each change, skipping repeats, so signing in from signed out
  /// yields only the new user. The user is nil when signed out, while a sign-in is in progress, or for a
  /// session stored before MobileSync kept the profile, until its next token refresh; check
  /// ``isLoggedIn`` to tell those apart.
  ///
  /// Cancelling its task, breaking out of the loop or taking `.first` stops observing. It throws
  /// `CancellationError` when cancelled and ``MobileSyncAuthenticationError`` otherwise.
  public var loggedInUserUpdates: MobileSyncAsyncSequence<MobileSyncUser?> {
    MobileSyncAsyncSequence(
      LoggedInUserSequence(states: asyncSequence(for: service.authStateFlow)),
      mapError: authenticationError(bridging:)
    )
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

/// Passes cancellation through, like the data sequences, and maps everything else.
private func authenticationError(bridging error: Error) -> Error {
  if error is CancellationError {
    return error
  }
  if (error as NSError).userInfo["KotlinException"] is KotlinCancellationException {
    return CancellationError()
  }
  return MobileSyncAuthenticationError(bridgedError: error)
}

/// The signed-in user each auth state publishes, without repeats.
struct LoggedInUserSequence<States: AsyncSequence>: AsyncSequence where States.Element == AuthState {
  typealias Element = MobileSyncUser?

  struct AsyncIterator: AsyncIteratorProtocol {
    var states: States.AsyncIterator
    // `.none` until the first user (which may be nil) is yielded.
    var yielded: MobileSyncUser?? = .none

    mutating func next() async throws -> MobileSyncUser?? {
      while let state = try await states.next() {
        // Success carries the session's user; Idle, Loading and Error have no session.
        let user = (state as? AuthState.Success)?.userInfo.map(MobileSyncUser.init)
        if let yielded, yielded == user {
          continue
        }
        yielded = .some(user)
        return .some(user)
      }
      return nil
    }
  }

  let states: States

  func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(states: states.makeAsyncIterator())
  }
}
