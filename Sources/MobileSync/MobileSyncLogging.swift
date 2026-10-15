import Foundation
internal import Shared

/// How severe a MobileSync log is, from least to most.
public enum MobileSyncLogSeverity: Hashable, Sendable {
  case verbose
  case debug
  case info
  case warn
  case error
  case assert
}

/// Receives MobileSync's logs, possibly from several threads at once. A logged error's stack trace
/// follows the message on its own lines.
public protocol MobileSyncLogSink: Sendable {
  func log(severity: MobileSyncLogSeverity, tag: String, message: String)
}

/// Chooses where MobileSync's logs go. Until configured, they go to the platform log.
public enum MobileSyncLogging {
  /// Sends MobileSync's logs at `minSeverity` or above to `sink`.
  ///
  /// At `debug` or below, HTTP calls also log headers and bodies, which hold user content such as
  /// note text. HTTP clients read this when they are created, so call it before
  /// ``MobileSyncGraph/shared(environment:clientID:clientSecret:)``.
  public static func configure(sink: some MobileSyncLogSink, minSeverity: MobileSyncLogSeverity) {
    Shared.MobileSyncLogging.shared.configure(
      sink: KotlinLogSink(sink),
      minSeverity: minSeverity.kotlinSeverity
    )
  }
}

// MARK: - Kotlin mapping

final class KotlinLogSink: NSObject, Shared.MobileSyncLogSink {
  init(_ sink: some MobileSyncLogSink) {
    self.sink = sink
  }

  func log(severity: Shared.MobileSyncLogSeverity, tag: String, message: String) {
    sink.log(severity: MobileSyncLogSeverity(severity), tag: tag, message: message)
  }

  private let sink: any MobileSyncLogSink
}

extension MobileSyncLogSeverity {
  init(_ severity: Shared.MobileSyncLogSeverity) {
    switch severity {
    case .verbose: self = .verbose
    case .debug: self = .debug
    case .info: self = .info
    case .warn: self = .warn
    case .error: self = .error
    case .assert: self = .assert
    // Logging never crashes; an unknown severity logs as info.
    default: self = .info
    }
  }

  var kotlinSeverity: Shared.MobileSyncLogSeverity {
    switch self {
    case .verbose: .verbose
    case .debug: .debug
    case .info: .info
    case .warn: .warn
    case .error: .error
    case .assert: .assert
    }
  }
}
