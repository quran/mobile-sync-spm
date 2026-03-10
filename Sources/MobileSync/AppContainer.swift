import Foundation
import Shared

public struct MobileSyncClientConfiguration {
  public let clientId: String
  public let clientSecret: String?
  public let redirectUri: String
  public let postLogoutRedirectUri: String
  public let scopes: [String]
  public let usePreProduction: Bool

  public init(
    clientId: String,
    clientSecret: String? = nil,
    redirectUri: String = "com.quran.oauth://callback",
    postLogoutRedirectUri: String = "com.quran.oauth://callback",
    scopes: [String] = [
      "openid", "offline_access", "content", "user", "bookmark", "sync",
      "collection", "reading_session", "preference", "note",
    ],
    usePreProduction: Bool = false
  ) {
    self.clientId = clientId
    self.clientSecret = clientSecret
    self.redirectUri = redirectUri
    self.postLogoutRedirectUri = postLogoutRedirectUri
    self.scopes = scopes
    self.usePreProduction = usePreProduction
  }
}

/**
 * App-level container around the shared dependency graph.
 *
 * This mirrors the demo setup while allowing iOS consumers to inject a runtime auth config when
 * they can't rely on the binary's baked BuildKonfig values.
 */
public final class AppContainer: @unchecked Sendable {
  public static let shared = AppContainer()

  public static var graph: any AppGraph {
    shared.graph
  }

  public let graph: any AppGraph
  public let authService: AuthService
  public let syncService: SyncService
  public let bookmarksRepository: any BookmarksRepository

  public convenience init(
    environment: SynchronizationEnvironment
  ) {
    self.init(configuration: nil, environment: environment)
  }

  public init(
    configuration: MobileSyncClientConfiguration? = nil,
    environment: SynchronizationEnvironment = SynchronizationEnvironment(
      endPointURL: "https://apis.quran.foundation/auth"
    )
  ) {
    AuthFlowFactoryProvider.shared.doInitialize()

    let driverFactory = DriverFactory()
    let graph = SharedDependencyGraph.shared.doInit(
      driverFactory: driverFactory,
      environment: environment
    )

    self.graph = graph
    bookmarksRepository = graph.bookmarksRepository

    if let configuration {
      let authConfig = AuthConfig(
        usePreProduction: configuration.usePreProduction,
        clientId: configuration.clientId,
        clientSecret: configuration.clientSecret,
        redirectUri: configuration.redirectUri,
        postLogoutRedirectUri: configuration.postLogoutRedirectUri,
        scopes: configuration.scopes
      )
      let json = AuthModule.companion.provideJson()
      let settings = AuthModule.companion.provideSettings()
      let httpClient = AuthModule.companion.provideHttpClient(json: json, config: authConfig)
      let oidcClient = AuthModule.companion.provideOpenIdConnectClient(
        config: authConfig,
        httpClient: httpClient
      )
      let authStorage = AuthStorage(settings: settings, json: json)
      let authNetworkDataSource = AuthNetworkDataSource(
        authConfig: authConfig,
        httpClient: httpClient
      )
      let logger = KermitLogger.companion.withTag(tag: "mobile-sync-spm")
      let authRepository = OidcAuthRepository(
        authConfig: authConfig,
        authStorage: authStorage,
        oidcClient: oidcClient,
        networkDataSource: authNetworkDataSource,
        logger: logger
      )
      let authService = AuthService(authRepository: authRepository)

      self.authService = authService
      syncService = SyncService(
        authService: authService,
        pipeline: graph.syncService.pipelineForIos,
        environment: environment,
        settings: SyncServiceKt.makeSettings()
      )
    } else {
      authService = graph.authService
      syncService = graph.syncService
    }
  }
}
