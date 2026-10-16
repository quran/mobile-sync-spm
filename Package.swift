// swift-tools-version: 6.1
import Foundation
import PackageDescription

let packageName = "MobileSync"
let binaryTargetName = "Shared"
let shimTargetName = "MobileSync"
let shimProductName = "MobileSync"
let testSupportTargetName = "MobileSyncTestSupport"

let localBinaryPath = ProcessInfo.processInfo.environment["MOBILE_SYNC_XCFRAMEWORK_PATH"]?
  .trimmingCharacters(in: .whitespacesAndNewlines)
let remoteVersion = "0.1.36"
let remoteChecksum = "d655f0dc903b8a28df5f6d09efa571adf7969bb80a4c433787592b583783b0df"

let binaryTarget: Target = {
  if let localBinaryPath, !localBinaryPath.isEmpty {
    return .binaryTarget(
      name: binaryTargetName,
      path: localBinaryPath
    )
  } else {
    return .binaryTarget(
      name: binaryTargetName,
      url:
        "https://github.com/quran/mobile-sync/releases/download/v\(remoteVersion)/\(binaryTargetName)-\(remoteVersion).xcframework.zip",
      checksum: remoteChecksum
    )
  }
}()

let package = Package(
  name: packageName,
  platforms: [
    .iOS(.v15)
  ],
  products: [
    .library(
      name: shimProductName,
      targets: [shimTargetName]
    ),
    // Only test targets may link it: it imports XCTest.
    .library(
      name: testSupportTargetName,
      targets: [testSupportTargetName]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/rickclephas/KMP-NativeCoroutines.git",
      exact: "1.0.0-ALPHA-48"
    )
  ],
  targets: [
    binaryTarget,
    .target(
      name: shimTargetName,
      dependencies: [
        .target(name: binaryTargetName),
        .product(name: "KMPNativeCoroutinesAsync", package: "KMP-NativeCoroutines"),
      ],
      path: "Sources/\(shimTargetName)",
      linkerSettings: [
        .linkedLibrary("sqlite3")
      ]
    ),
    .target(
      name: testSupportTargetName,
      dependencies: [
        .target(name: shimTargetName)
      ],
      path: "Sources/\(testSupportTargetName)"
    ),
    .testTarget(
      name: "MobileSyncTests",
      dependencies: [
        .target(name: shimTargetName),
        .target(name: testSupportTargetName),
      ]
    ),
    // Deleting the database stops the process-wide graph, so this runs in its own test process.
    .testTarget(
      name: "MobileSyncDeleteDatabaseTests",
      dependencies: [
        .target(name: shimTargetName)
      ]
    ),
  ]
)
