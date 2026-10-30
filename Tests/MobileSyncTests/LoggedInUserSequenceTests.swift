import Foundation
import Shared
import XCTest

@testable import MobileSync

final class LoggedInUserSequenceTests: XCTestCase {
  func testYieldsTheSignedInUserAndNilOtherwise() async throws {
    let users = try await loggedInUsers([
      AuthState.Idle.shared,
      AuthState.Success(userInfo: userInfo(name: "Ali")),
      AuthState.Error(exception: KotlinException(message: "Failed"), message: "Failed"),
      AuthState.Success(userInfo: userInfo(name: "Ali")),
      // A session stored before MobileSync kept the profile.
      AuthState.Success(userInfo: nil),
    ])

    XCTAssertEqual(users, [nil, user(name: "Ali"), nil, user(name: "Ali"), nil])
  }

  func testSkipsRestoringUntilTheStoredSessionIsRead() async throws {
    let signedIn = try await loggedInUsers([
      AuthState.Restoring.shared,
      AuthState.Success(userInfo: userInfo(name: "Ali")),
    ])
    let signedOut = try await loggedInUsers([
      AuthState.Restoring.shared,
      AuthState.Idle.shared,
    ])

    XCTAssertEqual(signedIn, [user(name: "Ali")])
    XCTAssertEqual(signedOut, [nil])
  }

  func testYieldsProfileChanges() async throws {
    let users = try await loggedInUsers([
      AuthState.Success(userInfo: userInfo(name: "Ali")),
      AuthState.Success(userInfo: userInfo(name: "Ali Hassan")),
    ])

    XCTAssertEqual(users, [user(name: "Ali"), user(name: "Ali Hassan")])
  }

  func testYieldsPhotoChanges() async throws {
    let users = try await loggedInUsers([
      AuthState.Success(userInfo: userInfo(name: "Ali")),
      AuthState.Success(userInfo: userInfo(name: "Ali", photoURL: "https://example.com/ali.png")),
    ])

    XCTAssertEqual(
      users, [user(name: "Ali"), user(name: "Ali", photoURL: "https://example.com/ali.png")])
  }

  func testSkipsRepeatedUsers() async throws {
    let users = try await loggedInUsers([
      AuthState.Idle.shared,
      AuthState.Error(exception: KotlinException(message: "Failed"), message: "Failed"),
      AuthState.Success(userInfo: userInfo(name: "Ali")),
      AuthState.Success(userInfo: userInfo(name: "Ali")),
    ])

    XCTAssertEqual(users, [nil, user(name: "Ali")])
  }

  func testSigningInAgainIsSignedOutUntilItFinishes() async throws {
    let users = try await loggedInUsers([
      AuthState.Success(userInfo: userInfo(name: "Ali")),
      AuthState.Loading.shared,
      AuthState.Success(userInfo: userInfo(name: "Ali")),
    ])

    XCTAssertEqual(users, [user(name: "Ali"), nil, user(name: "Ali")])
  }

  func testSigningInFromSignedOutYieldsOnlyTheNewUser() async throws {
    let users = try await loggedInUsers([
      AuthState.Idle.shared,
      AuthState.Loading.shared,
      AuthState.Success(userInfo: userInfo(name: "Ali")),
    ])

    XCTAssertEqual(users, [nil, user(name: "Ali")])
  }

  // MARK: Helpers

  private func loggedInUsers(_ states: [AuthState]) async throws -> [MobileSyncUser?] {
    var users: [MobileSyncUser?] = []
    for try await user in LoggedInUserSequence(states: AuthStates(states: states)) {
      users.append(user)
    }
    return users
  }

  private func userInfo(name: String, photoURL: String? = nil) -> UserInfo {
    UserInfo(id: "7", firstName: nil, lastName: nil, name: name, email: "ali@example.com", photoUrl: photoURL)
  }

  private func user(name: String, photoURL: String? = nil) -> MobileSyncUser {
    MobileSyncUser(id: "7", name: name, email: "ali@example.com", photoURL: photoURL)
  }
}

/// Yields the states in order, then ends, like a Kotlin state flow that published them.
private struct AuthStates: AsyncSequence, AsyncIteratorProtocol {
  var states: [AuthState]

  mutating func next() async -> AuthState? {
    states.isEmpty ? nil : states.removeFirst()
  }

  func makeAsyncIterator() -> AuthStates {
    self
  }
}
