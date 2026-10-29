import Foundation
import MobileSync
import XCTest

/// The real MobileSync database for tests, in a file only this process uses.
///
/// Test bundles and concurrent runs on one simulator share its database directory, so the file has a
/// unique name. It is closed and deleted when the test bundle finishes.
public final class MobileSyncTestDatabase: Sendable {
  public static let shared = MobileSyncTestDatabase()

  public var quranDataService: MobileSyncDataService {
    graph.dataService
  }

  public var authService: MobileSyncAuthService {
    graph.authService
  }

  /// Signs out, which clears user data but keeps tracked import history.
  public func reset() async throws {
    try await authService.logout()
  }

  package let databaseName = "mobile-sync-tests-\(UUID().uuidString).db"
  private let graph: MobileSyncGraph

  private init() {
    graph = MobileSyncGraph.shared(environment: .prelive, clientID: "", databaseName: databaseName)
    DatabaseDeleter.register(graph)
  }
}

/// Deletes the database after the bundle's last test.
private final class DatabaseDeleter: NSObject, XCTestObservation {
  init(graph: MobileSyncGraph) {
    self.graph = graph
  }

  static func register(_ graph: MobileSyncGraph) {
    if Thread.isMainThread {
      XCTestObservationCenter.shared.addTestObserver(DatabaseDeleter(graph: graph))
    } else {
      DispatchQueue.main.async {
        XCTestObservationCenter.shared.addTestObserver(DatabaseDeleter(graph: graph))
      }
    }
  }

  func testBundleDidFinish(_ testBundle: Bundle) {
    // This runs on the main thread, where MobileSync finishes stopping the graph's work, so keep the run
    // loop turning while waiting.
    let deletion = Deletion()
    Task { @MainActor [graph] in
      do {
        try await graph.deleteDatabase()
      } catch {
        print("Failed to delete the MobileSync test database: \(error)")
      }
      deletion.isFinished = true
    }
    let deadline = Date().addingTimeInterval(10)
    while !deletion.isFinished, Date() < deadline {
      RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
  }

  private let graph: MobileSyncGraph

  private final class Deletion: @unchecked Sendable {
    var isFinished = false
  }
}
