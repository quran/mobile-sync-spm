import Foundation
import MobileSync
import XCTest

/// The real MobileSync database for tests, in a file only this process uses.
///
/// Test processes on one simulator share its database directory, so the file has a unique name.
/// MobileSync owns the services' synchronization; tests reset the database before and after each test,
/// and it is deleted when the test bundle finishes.
final class ImportTestDatabase: Sendable {
  static let shared = ImportTestDatabase()
  let databaseName = "mobile-sync-spm-tests-\(UUID().uuidString).db"
  let graph: MobileSyncGraph

  var service: MobileSyncDataService {
    graph.dataService
  }

  /// Signs out, which clears every table.
  func reset() async throws {
    try await graph.authService.signOut()
  }

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
    // This runs on the main thread, where MobileSync finishes stopping the graph's work, so keep the run loop
    // turning while waiting.
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
