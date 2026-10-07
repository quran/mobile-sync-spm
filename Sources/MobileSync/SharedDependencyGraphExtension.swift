import Shared

extension SharedDependencyGraph {
  /// Opens MobileSync's shared database before the graph resolves it, so failures can be handled instead of crashing.
  /// Reuses an already open database; a failed open is not cached, so calling again retries.
  /// - Throws: `MobileSyncDatabaseError`. A full disk can also arrive as `openFailed`, so check free space if needed.
  public func openDatabase(using driverFactory: DriverFactory) throws(MobileSyncDatabaseError) {
    do {
      try openDatabase(driverFactory: driverFactory)
    } catch {
      throw MobileSyncDatabaseError(bridgedError: error)
    }
  }
}
