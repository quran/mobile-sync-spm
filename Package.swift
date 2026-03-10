// swift-tools-version: 6.1
import Foundation
import PackageDescription

let packageName = "MobileSync"
let binaryTargetName = "Shared"
let shimTargetName = "MobileSync"
let shimProductName = "MobileSync"

let useLocalBinary = false
let remoteVersion = "0.0.4"
let remoteChecksum = "1699b352dac3c9025dea59555d38018f94bc64c23eefd3a8e547e1a161580d32"

let binaryTarget: Target = {
  if useLocalBinary {
    return .binaryTarget(
      name: binaryTargetName,
      path: "../mobile-sync/umbrella/build/XCFrameworks/release/\(binaryTargetName).xcframework"
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
  ]
)
