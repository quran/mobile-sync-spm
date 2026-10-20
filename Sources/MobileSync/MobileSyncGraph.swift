import Foundation
internal import Shared

/// Which Quran.com servers MobileSync signs in and syncs with.
public enum MobileSyncEnvironment: Hashable, Sendable {
  case prelive
  case production
}

/// MobileSync's services, shared by the whole process.
public struct MobileSyncGraph: @unchecked Sendable {
  // MobileSync synchronizes the graph internally.
  private let graph: any AppGraph

  private init(_ graph: any AppGraph) {
    self.graph = graph
  }

  /// Reads and writes user data. The first access opens the database and crashes if that fails,
  /// so call ``openDatabase()`` first to handle failures.
  public var dataService: MobileSyncDataService {
    MobileSyncDataService(graph.quranDataService)
  }

  /// Signs the user in and out. The first access opens the database, like ``dataService``.
  public var authService: MobileSyncAuthService {
    MobileSyncAuthService(graph.authService)
  }

  /// Returns the process-wide graph, creating it on the first call. Later calls ignore their arguments.
  ///
  /// Configure ``MobileSyncLogging`` first. A blank `clientID` keeps data local and makes sign-in
  /// unavailable.
  public static func shared(
    environment: MobileSyncEnvironment,
    clientID: String,
    clientSecret: String? = nil
  ) -> MobileSyncGraph {
    makeShared(environment: environment, clientID: clientID, clientSecret: clientSecret, databaseName: nil)
  }

  /// Like ``shared(environment:clientID:clientSecret:)``, with the database in the file `databaseName`
  /// instead of `user_data.db`, so a test process can use a file no other process opens.
  package static func shared(
    environment: MobileSyncEnvironment,
    clientID: String,
    clientSecret: String? = nil,
    databaseName: String
  ) -> MobileSyncGraph {
    makeShared(
      environment: environment, clientID: clientID, clientSecret: clientSecret, databaseName: databaseName)
  }

  /// Opens MobileSync's database, or reuses it when already open, so failures can be handled instead
  /// of crashing when a service first needs it. A failed open is not cached, so calling again retries.
  /// - Throws: `MobileSyncDatabaseError`. A full disk can also arrive as `openFailed`, so check free
  ///   space if needed.
  public static func openDatabase() throws(MobileSyncDatabaseError) {
    try openDatabase(databaseName: nil)
  }

  /// Like ``openDatabase()``, for a graph created with a `databaseName`. The first open decides which file
  /// the graph uses, so pass the same name.
  package static func openDatabase(databaseName: String?) throws(MobileSyncDatabaseError) {
    #if DEBUG
    assertSameDatabaseName(databaseName)
    #endif
    do {
      try SharedDependencyGraph.shared.openDatabase(driverFactory: driverFactory(databaseName: databaseName))
    } catch {
      throw MobileSyncDatabaseError(bridgedError: error)
    }
  }

  /// Stops the graph's work, then closes the database and deletes its files.
  ///
  /// For a test process that uses its own `databaseName`, once it is done with MobileSync: afterwards
  /// this graph and every service it returned stop working, and `shared` keeps returning the stopped
  /// graph. MobileSync finishes stopping the work on the main queue, so a caller that blocks the main
  /// thread while waiting must keep its run loop turning.
  /// - Throws: `CancellationError` when MobileSync cancels the work, and ``MobileSyncDataError`` otherwise.
  package func deleteDatabase() async throws {
    do {
      try await SharedDependencyGraph.shared.deleteDatabase()
    } catch {
      throw dataError(bridging: error)
    }
  }

  private static func makeShared(
    environment: MobileSyncEnvironment,
    clientID: String,
    clientSecret: String?,
    databaseName: String?
  ) -> MobileSyncGraph {
    #if DEBUG
    assertSameSetup(
      Setup(
        environment: environment, clientID: clientID, clientSecret: clientSecret, databaseName: databaseName))
    #endif
    if !AuthFlowFactoryProvider.shared.isInitialized() {
      AuthFlowFactoryProvider.shared.doInitialize()
    }
    let graph = SharedDependencyGraph.shared.doInit(
      driverFactory: driverFactory(databaseName: databaseName),
      storage: AppleMobileSyncStorageFactory.shared.create(),
      appEnvironment: environment.kotlinEnvironment,
      clientId: clientID,
      clientSecret: clientSecret
    )
    return MobileSyncGraph(graph)
  }

  private static func driverFactory(databaseName: String?) -> DriverFactory {
    databaseName.map { DriverFactory(name: $0) } ?? DriverFactory()
  }
}

#if DEBUG
extension MobileSyncGraph {
  /// The arguments of a `shared` call.
  private struct Setup: Equatable {
    let environment: MobileSyncEnvironment
    let clientID: String
    let clientSecret: String?
    let databaseName: String?
  }

  private static let setupLock = NSLock()
  nonisolated(unsafe) private static var firstSetup: Setup?
  nonisolated(unsafe) private static var firstDatabaseName: String??

  /// Catches a later call that expects a different graph than the one it gets.
  private static func assertSameSetup(_ setup: Setup) {
    let firstSetup = setupLock.withLock {
      if Self.firstSetup == nil {
        Self.firstSetup = setup
      }
      return Self.firstSetup
    }
    assert(firstSetup == setup, "MobileSyncGraph.shared was already called with different arguments")
    assertSameDatabaseName(setup.databaseName)
  }

  /// Catches a `shared` or `openDatabase` call that expects a different file than the one opened first.
  private static func assertSameDatabaseName(_ databaseName: String?) {
    let firstDatabaseName = setupLock.withLock {
      if Self.firstDatabaseName == nil {
        Self.firstDatabaseName = .some(databaseName)
      }
      return Self.firstDatabaseName
    }
    assert(
      firstDatabaseName == .some(databaseName),
      "MobileSyncGraph was already set up with a different databaseName")
  }
}
#endif

extension MobileSyncEnvironment {
  var kotlinEnvironment: AppEnvironment {
    switch self {
    case .prelive: .prelive
    case .production: .production
    }
  }
}
