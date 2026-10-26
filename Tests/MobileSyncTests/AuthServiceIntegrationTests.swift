import Foundation
import MobileSync
import MobileSyncTestSupport
import XCTest

// Uses only the public API, so it also checks that a consumer needs nothing else.
final class AuthServiceIntegrationTests: XCTestCase {
  private let database = MobileSyncTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.reset()
  }

  override func tearDown() async throws {
    try await database.reset()
    try await super.tearDown()
  }

  func testLoggedInUserUpdatesStartSignedOut() async throws {
    let user = try await database.authService.loggedInUserUpdates.makeAsyncIterator().next()

    // The sequence yields one value, nil, rather than ending.
    XCTAssertEqual(user, .some(nil))
  }

  func testLoggedInUserUpdatesEndWhenTheirTaskIsCancelled() async throws {
    let signedOut = expectation(description: "Yielded signed out")
    let ended = expectation(description: "Ended")
    let updates = database.authService.loggedInUserUpdates
    let observation = Task { () -> Error? in
      defer { ended.fulfill() }
      do {
        for try await user in updates {
          XCTAssertNil(user)
          signedOut.fulfill()
        }
        return nil
      } catch {
        return error
      }
    }

    await fulfillment(of: [signedOut], timeout: 10)
    observation.cancel()
    await fulfillment(of: [ended], timeout: 10)

    let error = await observation.value
    XCTAssertTrue(
      error == nil || error is CancellationError,
      "Expected the sequence to end or throw CancellationError, got \(String(describing: error))")
  }
}
