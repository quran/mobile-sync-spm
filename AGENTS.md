# AGENTS.md

Guidance for coding agents working in this repository. Keep this file short and operational.
Use `README.md` as the source of truth for public setup and usage docs.

## Repo Snapshot

`mobile-sync-spm` is the Swift package that ships the `Shared` XCFramework from
[quran/mobile-sync](https://github.com/quran/mobile-sync) to iOS apps, behind a Swift-only API.

- `Package.swift`: the `Shared` binary target, downloaded from the mobile-sync GitHub release named by
  `remoteVersion` and verified with `remoteChecksum`, plus KMP-NativeCoroutines (`KMPNativeCoroutinesAsync`).
- `Sources/MobileSync` (product `MobileSync`): the public API. `MobileSyncGraph` creates the process-wide
  graph and opens the database; it hands out `MobileSyncDataService` and `MobileSyncAuthService`.
  `MobileSyncLogging` routes logs. The rest are Swift value types and errors.
- `Sources/MobileSyncTestSupport` (product `MobileSyncTestSupport`): `MobileSyncTestDatabase.shared`, the
  real database in a per-process file that is deleted when the test bundle finishes. It imports XCTest, so
  only test targets may link it.
- `Tests/MobileSyncTests`: unit tests for the Kotlin mapping and integration tests through the public API.
- `Tests/MobileSyncDeleteDatabaseTests`: deleting the database stops the process-wide graph, so this runs
  in its own test bundle.
- `MobileSyncSpmDemo`: template app sources with no Xcode project checked in. It doesn't use the package
  and CI doesn't build it.

## Rules

- Swift-only API: consumers `import MobileSync` and never `import Shared` or name a Kotlin type. `Sources/`
  imports `Shared` and `KMPNativeCoroutinesAsync` with `internal import`. When an app needs Kotlin API that
  isn't wrapped yet, add the Swift wrapper here (value type, enum, error mapping, async function or
  `MobileSyncAsyncSequence`) instead of exposing the Kotlin type.
- `package` declarations (`databaseName`, `deleteDatabase()`) exist for `MobileSyncTestSupport`; keep them
  out of the public API.
- Never edit `remoteVersion` or `remoteChecksum` just to adopt a mobile-sync release; the Release Wrapper
  does it (see Releasing).

## Commands

Run the tests as CI does (`.github/workflows/ci.yml`, macos-26 with Xcode 26.2). The product schemes have no
test action; `MobileSync-Package` builds and tests every target.

```bash
set -o pipefail
simulator_id="$(
  xcrun simctl list devices available --json |
    python3 -c 'import json, sys; print(next(device["udid"] for devices in json.load(sys.stdin)["devices"].values() for device in devices if device.get("isAvailable") and device["name"].startswith("iPhone")))'
)"
xcrun xcodebuild \
  -scheme MobileSync-Package \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=${simulator_id}" \
  build test
```

Build against a local XCFramework by setting `MOBILE_SYNC_XCFRAMEWORK_PATH`. `Package.swift` then uses
`.binaryTarget(path:)` instead of the release URL. SwiftPM requires the path to be relative to this
package's root (it rejects absolute paths). Unset or blank means the remote binary.

```bash
# In mobile-sync, checked out next to this repository:
./gradlew :umbrella:assembleSharedXCFramework
# Here (add the xcodebuild arguments above):
MOBILE_SYNC_XCFRAMEWORK_PATH=../mobile-sync/umbrella/build/XCFrameworks/debug/Shared.xcframework xcrun xcodebuild ...
```

## Releasing

### Adopting a new mobile-sync release needs no PR

Run the Release Wrapper (`.github/workflows/release.yml`, `workflow_dispatch`) on main:

```bash
gh workflow run release.yml -R quran/mobile-sync-spm -f kmp_version=<mobile-sync version> -f package_version=<next version>
```

- `kmp_version`: the mobile-sync release without the leading `v` (e.g. `0.1.34`).
- `package_version`: the next version of this package (see Versioning). Always pass both inputs; the
  defaults are placeholders that are already tagged.

For example, 0.2.1 was released with `kmp_version=0.1.34` and `package_version=0.2.1`.

The workflow first fails if either input isn't `x.y.z` or if `v<package_version>` already exists. Then it
downloads `Shared-<kmp_version>.xcframework.zip` from the quran/mobile-sync GitHub release, computes its
checksum, rewrites `remoteVersion` and `remoteChecksum` in `Package.swift`, builds and runs the tests, then
commits `Release <package_version>` to main and tags `v<package_version>`. Failing tests stop it before
anything is committed, pushed or tagged.

### Swift wrapper changes need a PR first

Open a PR only when the Swift code changes, for example when a Kotlin API change needs new Swift wrappers or
bridging. That PR also bumps `remoteVersion`/`remoteChecksum` to the mobile-sync release it needs
(`swift package compute-checksum Shared-<version>.xcframework.zip`). After it merges, run the Release
Wrapper with that same `kmp_version`: `Package.swift` is already current, so the release is an empty
`Release <package_version>` commit plus the tag, as with 0.2.0 after #31 and #33.

### Versioning

The `v0.1.x` and `v0.2.x` tags are this package's own versions, not mobile-sync's; read `remoteVersion` for
the mobile-sync version (e.g. this package's 0.1.34 shipped mobile-sync 0.1.33, and 0.2.1 ships 0.1.34).

- Patch: a mobile-sync upgrade that needs no Swift API change (0.2.0 → 0.2.1 for mobile-sync 0.1.34).
- Minor (pre-1.0): breaking Swift API changes (0.2.0 for the Swift-only API in #31).

From 0.1.0 until 0.2.0 every release was a patch bump, breaking ones (#28, #32) included.
