// swift-tools-version: 6.1
import Foundation
import PackageDescription

let packageName = "MobileSync"
let binaryTargetName = "Shared"
let shimTargetName = "MobileSync"
let shimProductName = "MobileSync"

let localBinaryPath = ProcessInfo.processInfo.environment["MOBILE_SYNC_XCFRAMEWORK_PATH"]?
  .trimmingCharacters(in: .whitespacesAndNewlines)
let remoteVersion = "0.1.15"
let remoteChecksum = "96db62220fd9326302e001cdb25d987ed53f03d363d2da1dd95eeca6ff259b93"

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
    .testTarget(
      name: "MobileSyncTests",
      dependencies: [
        .target(name: shimTargetName)
      ]
    ),
  ]
)
