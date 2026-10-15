import Foundation
import MobileSync
import XCTest

final class DeleteDatabaseIntegrationTests: XCTestCase {
  func testDeleteDatabaseDeletesTheNamedFile() async throws {
    let databaseName = "mobile-sync-tests-\(UUID().uuidString).db"
    let graph = MobileSyncGraph.shared(environment: .prelive, clientID: "", databaseName: databaseName)
    try MobileSyncGraph.openDatabase(databaseName: databaseName)
    _ = try await graph.dataService.createCollection(named: "Study")
    let databaseURL = try XCTUnwrap(
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ).appendingPathComponent("databases/\(databaseName)")
    XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))

    try await graph.deleteDatabase()

    for suffix in ["", "-shm", "-wal"] {
      XCTAssertFalse(FileManager.default.fileExists(atPath: databaseURL.path + suffix), suffix)
    }
  }
}
