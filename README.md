# mobile-sync-spm

A Swift package that wraps the `Shared` XCFramework from [quran/mobile-sync](https://github.com/quran/mobile-sync),
the Kotlin Multiplatform authentication, local storage and sync stack for Quran apps, in a Swift-only API.
Apps `import MobileSync` and never see a Kotlin type.

## Installation

Add the package with Swift Package Manager (iOS 15 or later, `swift-tools-version` 6.1):

```swift
dependencies: [
  .package(url: "https://github.com/quran/mobile-sync-spm.git", .upToNextMinor(from: "0.4.0")),
],
```

Releases before 1.0 can break the API in a minor version, hence `.upToNextMinor`.

| Product | Use |
| --- | --- |
| `MobileSync` | The API for apps: the graph, data and auth services, logging, and their Swift types. |
| `MobileSyncTestSupport` | A real MobileSync database for tests. It imports XCTest, so link it from test targets only. |

```swift
.target(name: "App", dependencies: [.product(name: "MobileSync", package: "mobile-sync-spm")]),
.testTarget(name: "AppTests", dependencies: [.product(name: "MobileSyncTestSupport", package: "mobile-sync-spm")]),
```

## Usage

```swift
import MobileSync

struct PrintLogSink: MobileSyncLogSink {
  func log(severity: MobileSyncLogSeverity, tag: String, message: String) {
    print("[\(tag)] \(message)")
  }
}

// Configure logging before creating the graph: HTTP clients read it when they are created.
MobileSyncLogging.configure(sink: PrintLogSink(), minSeverity: .info)

// The process-wide graph. Later calls return the same graph; in debug builds, different arguments assert.
// A blank clientID keeps data local and makes sign-in unavailable.
let graph = MobileSyncGraph.shared(environment: .production, clientID: "<client ID>")

// Open the database up front to handle failures; otherwise the first service access crashes on failure.
do {
  try MobileSyncGraph.openDatabase()
} catch MobileSyncDatabaseError.storageFull {
  // The disk is full.
} catch {
  // MobileSyncDatabaseError.openFailed
}
```

Reading and writing user data:

```swift
let data = graph.dataService

try await data.createNote(body: "Reflection", startSura: 2, startAyah: 255, endSura: 2, endAyah: 257)
let collection = try await data.createCollection(named: "Study")
_ = try await data.addAyahBookmarkToCollection(collectionID: collection.id, sura: 2, ayah: 255)
_ = try await data.setAyahHighlight(sura: 1, ayah: 1, color: .yellow)
_ = try await data.setAyahReadingBookmark(slot: .teal, sura: 18, ayah: 10)
_ = try await data.setPageReadingBookmark(slot: .orange, page: 537, mushaf: .indopak15Lines)

// Each sequence yields the latest values after every change. Cancelling its task, breaking out of the
// loop or taking `.first` stops it.
for try await notes in data.notesSequence() {
  print(notes.map(\.body))
}
let notes = try await data.notesSequence().first { _ in true } // The current notes.
```

Page reading bookmarks take the `MobileSyncMushaf` the app shows: `.madani1405`, `.madani1440` (604 pages each) or
`.indopak15Lines`, numbered 2…611 as the apps number it (page 1 is the cover). `readingBookmarksSequence(mushaf:)`
and `renameReadingBookmark(slot:name:mushaf:)` return page bookmarks as pages of that mushaf, mapped from whichever
mushaf they were set in, here or on Quran.com; a page it can't show comes back `.unplaced`. Setting a page the
mushaf doesn't have throws `MobileSyncDataError.invalidArgument`, and importing one skips it.

`MobileSyncDataService` also covers updating and deleting notes and collections, removing collection bookmarks
and highlights, renaming and clearing reading bookmarks, adding and updating reading sessions, and importing local
data (`importData(_:deleteExisting:trackHistory:)`). Calls that create, add, set, update, rename or clear take a
`timestamp` that defaults to now. Calls throw `CancellationError`,
`MobileSyncTextLengthLimitError`, the collection errors (`MobileSyncReadOnlyCollectionError`,
`MobileSyncDuplicateCollectionNameError`, `MobileSyncReservedCollectionNameError`) documented on each
collection write, or `MobileSyncDataError`.

Signing in, which also syncs the user's data with Quran.com:

```swift
let auth = graph.authService

// Restores the stored session; returns whether the user is signed in.
if try await !auth.refreshAuthentication() {
  try await auth.signInWithReauthentication()
}
let headers = try await auth.authenticationHeaders() // For your own Quran.com requests.

try await auth.signOut() // Also clears local data.

// Yields the signed-in user now and after every change, such as a token refresh that updates the
// profile. nil means no profile: signed out, signing in, or a session stored before MobileSync kept the
// profile; check `auth.isLoggedIn` to tell them apart.
let observation = Task {
  for try await user in auth.loggedInUserUpdates {
    print(user?.name ?? "No profile")
  }
}
observation.cancel() // Stops observing.
```

Auth calls throw `MobileSyncAuthenticationError`.

## Testing with MobileSyncTestSupport

`MobileSyncTestDatabase.shared` is the real MobileSync database in a file only the test process uses, with
local data only (no sign-in). It is closed and deleted when the test bundle finishes.

```swift
import MobileSync
import MobileSyncTestSupport
import XCTest

final class NotesTests: XCTestCase {
  private let database = MobileSyncTestDatabase.shared

  override func setUp() async throws {
    try await super.setUp()
    try await database.reset() // Clears user data; tracked import history survives.
  }

  func testCreatesNote() async throws {
    try await database.quranDataService.createNote(
      body: "Reflection", startSura: 2, startAyah: 1, endSura: 2, endAyah: 5)
    // Read it back through database.quranDataService.notesSequence().
  }
}
```

`MobileSyncTestDatabase` creates the process-wide graph with its own database file, so the test process must
not call `MobileSyncGraph.shared` or `MobileSyncGraph.openDatabase()` itself (for example from a host app); in
debug builds either call trips an assertion.

## Development

Run the tests the way CI does (`.github/workflows/ci.yml`). The product schemes have no test action, so
`scripts/test.sh` runs the `MobileSync-Package` scheme on an iPhone simulator, preferring one whose iOS version
matches the SDK's:

```bash
scripts/test.sh
```

The KMP-NativeCoroutines version pinned in `Package.swift` must match `native-coroutines` in mobile-sync's
`gradle/libs.versions.toml` at the `remoteVersion` tag, since the Swift package and the Kotlin plugin that builds
`Shared` are two halves of one library. CI checks it with `scripts/check-native-coroutines.sh`, which also runs
locally; bump both together.

### Using a locally built XCFramework

By default `Package.swift` downloads `Shared` from the mobile-sync release named by `remoteVersion`. To try
unreleased mobile-sync changes, build the XCFramework in mobile-sync and point `MOBILE_SYNC_XCFRAMEWORK_PATH`
at it. The path must be relative to this package's root; SwiftPM rejects absolute paths.

```bash
# In mobile-sync, checked out next to this repository:
./gradlew :umbrella:assembleSharedXCFramework
```

```bash
MOBILE_SYNC_XCFRAMEWORK_PATH=../mobile-sync/umbrella/build/XCFrameworks/debug/Shared.xcframework scripts/test.sh
```

Xcode reads the variable when it launches, so quit it, then start it with the variable set to use the local
binary there:

```bash
open -a Xcode --env MOBILE_SYNC_XCFRAMEWORK_PATH=../mobile-sync/umbrella/build/XCFrameworks/debug/Shared.xcframework .
```

## Releasing

Releases are made by the **Release Wrapper** workflow ([`.github/workflows/release.yml`](.github/workflows/release.yml)).
Given a mobile-sync release (`kmp_version`) and this package's next version (`package_version`), it points
`Package.swift` at that release's XCFramework and checksum, builds and runs the tests, commits
`Release <package_version>` to main and tags `v<package_version>`. It refuses a version that is already tagged:

```bash
gh workflow run release.yml -R quran/mobile-sync-spm -f kmp_version=<mobile-sync version> -f package_version=<next version>
```

For example, 0.2.1 was released with `kmp_version=0.1.34` and `package_version=0.2.1`.

This package's versions are its own, not mobile-sync's; `remoteVersion` in `Package.swift` names the
mobile-sync release it ships. See [AGENTS.md](AGENTS.md) for when a release needs a PR and how versions are
chosen.
