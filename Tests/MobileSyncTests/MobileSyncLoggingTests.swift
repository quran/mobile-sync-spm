import Foundation
import Shared
import XCTest

@testable import MobileSync

final class MobileSyncLoggingTests: XCTestCase {
  func testMapsEveryKotlinSeverityBothWays() {
    for kotlin in Shared.MobileSyncLogSeverity.entries {
      let swift = MobileSync.MobileSyncLogSeverity(kotlin)
      XCTAssertEqual("\(swift)", kotlin.name.lowercased())
      XCTAssertEqual(swift.kotlinSeverity, kotlin)
    }
  }
}
