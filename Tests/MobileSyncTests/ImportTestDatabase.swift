import Foundation
import MobileSync

// Kotlin owns the service's synchronization; XCTest resets the shared database before and after each test.
final class ImportTestDatabase: @unchecked Sendable {
  static let shared = ImportTestDatabase()
  let service: QuranDataService

  private init() {
    Self.removeDatabaseFiles()
    AuthFlowFactoryProvider.shared.doInitialize()
    service =
      SharedDependencyGraph.shared.doInit(
        driverFactory: DriverFactory(),
        storage: AppleMobileSyncStorageFactory.shared.create(),
        clientId: "",
        clientSecret: nil
      ).quranDataService
  }

  private static func removeDatabaseFiles() {
    guard
      let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
    else {
      return
    }
    // The XCTest runner persists this database between runs of different local frameworks.
    let databaseURL = applicationSupport.appendingPathComponent("databases/quran.db")
    for suffix in ["", "-shm", "-wal"] {
      try? FileManager.default.removeItem(atPath: databaseURL.path + suffix)
    }
  }
}
