import Foundation
import Shared
import XCTest

@testable import MobileSync

final class MobileSyncSyncActivityMappingTests: XCTestCase {
  // MARK: Enums

  func testMapsEveryKotlinSyncRunTrigger() {
    let triggers: [(SyncRunTrigger, MobileSyncRunTrigger)] = [
      (.appStart, .appStart), (.localChange, .localChange), (.periodic, .periodic), (.manual, .manual),
      (.signIn, .signIn),
    ]

    XCTAssertEqual(SyncRunTrigger.entries, triggers.map(\.0))
    for (kotlin, swift) in triggers {
      XCTAssertEqual(MobileSyncRunTrigger(kotlin), swift, kotlin.name)
    }
  }

  func testMapsEveryKotlinSyncRunResult() {
    let results: [(SyncRunResult, MobileSyncRunResult)] = [
      (.succeeded, .succeeded), (.pulledOnly, .pulledOnly), (.failed, .failed), (.cancelled, .cancelled),
    ]

    XCTAssertEqual(SyncRunResult.entries, results.map(\.0))
    for (kotlin, swift) in results {
      XCTAssertEqual(MobileSyncRunResult(kotlin), swift, kotlin.name)
    }
  }

  func testMapsEveryKotlinSyncErrorKind() {
    let kinds: [(SyncErrorKind, MobileSyncRunError.Kind)] = [
      (.network, .network), (.authentication, .authentication), (.server, .server), (.rejected, .rejected),
      (.unknown, .unknown),
    ]

    XCTAssertEqual(SyncErrorKind.entries, kinds.map(\.0))
    for (kotlin, swift) in kinds {
      XCTAssertEqual(MobileSyncRunError.Kind(kotlin), swift, kotlin.name)
    }
  }

  func testMapsEveryKotlinSyncResourceType() {
    let types: [(SyncResourceType, MobileSyncResourceType)] = [
      (.note, .note), (.collection, .collection), (.collectionBookmark, .collectionBookmark),
      (.readingSession, .readingSession), (.readingBookmark, .readingBookmark),
    ]

    XCTAssertEqual(SyncResourceType.entries, types.map(\.0))
    for (kotlin, swift) in types {
      XCTAssertEqual(MobileSyncResourceType(kotlin), swift, kotlin.name)
    }
  }

  func testMapsEveryKotlinHeldReason() {
    let reasons: [(HeldReason, MobileSyncHeldReason)] = [
      (.tooShort, .tooShort), (.tooLong, .tooLong), (.invalidRange, .invalidRange), (.invalidVerse, .invalidVerse),
      (.invalidLocation, .invalidLocation), (.invalidSlot, .invalidSlot), (.tooMuchMetadata, .tooMuchMetadata),
      (.reservedName, .reservedName), (.readOnly, .readOnly), (.rejectedByServer, .rejectedByServer),
      (.waitingOnParent, .waitingOnParent), (.waitingOnOtherItem, .waitingOnOtherItem),
      (.notYetLinked, .notYetLinked),
    ]

    XCTAssertEqual(HeldReason.entries, reasons.map(\.0))
    for (kotlin, swift) in reasons {
      XCTAssertEqual(MobileSyncHeldReason(kotlin), swift, kotlin.name)
    }
  }

  // MARK: Values

  func testMapsFailedSyncRunWithItsError() {
    let run = SyncRun(
      startedAt: date(10), endedAt: date(20), trigger: .manual, result: .failed, attempts: 3, pushed: 4, pulled: 5,
      held: 6,
      error: SyncError(kind: .rejected, httpStatus: 409, serverCode: "UniqueViolationError", message: "Conflict"))

    XCTAssertEqual(
      MobileSyncRun(run),
      MobileSyncRun(
        startedAt: date(10), endedAt: date(20), trigger: .manual, result: .failed, attempts: 3, pushed: 4, pulled: 5,
        held: 6,
        error: MobileSyncRunError(
          kind: .rejected, httpStatus: 409, serverCode: "UniqueViolationError", message: "Conflict")))
  }

  func testMapsSucceededSyncRunWithoutError() {
    let run = SyncRun(
      startedAt: date(10), endedAt: date(20), trigger: .appStart, result: .succeeded, attempts: 1, pushed: 0,
      pulled: 2, held: 0, error: nil)

    XCTAssertEqual(
      MobileSyncRun(run),
      MobileSyncRun(
        startedAt: date(10), endedAt: date(20), trigger: .appStart, result: .succeeded, attempts: 1, pushed: 0,
        pulled: 2, held: 0, error: nil))
  }

  func testMapsEverySyncStatus() {
    let error = SyncError(kind: .network, httpStatus: nil, serverCode: nil, message: "Offline")

    XCTAssertEqual(MobileSyncStatus(SyncStatus.Idle.shared), .idle)
    XCTAssertEqual(MobileSyncStatus(SyncStatus.Syncing.shared), .syncing)
    XCTAssertEqual(MobileSyncStatus(SyncStatus.Succeeded(at: date(10))), .succeeded(at: date(10)))
    XCTAssertEqual(
      MobileSyncStatus(SyncStatus.Failed(at: date(20), error: error)),
      .failed(
        at: date(20), error: MobileSyncRunError(kind: .network, httpStatus: nil, serverCode: nil, message: "Offline")))
  }

  func testMapsHeldItemRejectedByServer() {
    let item = HeldSyncItem(
      type: .note, id: "7", collectionId: nil, reason: .rejectedByServer, waitingOn: nil, httpStatus: 422,
      serverCode: "ValidationError")

    XCTAssertEqual(
      MobileSyncHeldItem(item),
      MobileSyncHeldItem(
        type: .note, id: "7", collectionID: nil, reason: .rejectedByServer, waitingOn: nil, httpStatus: 422,
        serverCode: "ValidationError"))
  }

  func testMapsTheHeldItemAnItemWaitsOn() throws {
    let collection = HeldSyncItem(
      type: .collection, id: "3", collectionId: nil, reason: .tooLong, waitingOn: nil, httpStatus: nil, serverCode: nil)
    let bookmark = HeldSyncItem(
      type: .collectionBookmark, id: "2:255", collectionId: "3", reason: .waitingOnParent, waitingOn: collection,
      httpStatus: nil, serverCode: nil)

    let mapped = try XCTUnwrap(MobileSyncHeldItem(bookmark))

    let expectedCollection = MobileSyncHeldItem(
      type: .collection, id: "3", collectionID: nil, reason: .tooLong, waitingOn: nil, httpStatus: nil, serverCode: nil)
    XCTAssertEqual(
      mapped,
      MobileSyncHeldItem(
        type: .collectionBookmark, id: "2:255", collectionID: "3", reason: .waitingOnParent,
        waitingOn: expectedCollection, httpStatus: nil, serverCode: nil))
    XCTAssertEqual(mapped.waitingOn, expectedCollection)
  }

  func testHeldItemsWaitingOnDifferentItemsDiffer() {
    func waiting(onCollection id: String) -> MobileSyncHeldItem {
      MobileSyncHeldItem(
        type: .collectionBookmark, id: "2:255", collectionID: id, reason: .waitingOnParent,
        waitingOn: MobileSyncHeldItem(
          type: .collection, id: id, collectionID: nil, reason: .tooLong, waitingOn: nil, httpStatus: nil,
          serverCode: nil),
        httpStatus: nil, serverCode: nil)
    }

    XCTAssertEqual(waiting(onCollection: "3"), waiting(onCollection: "3"))
    XCTAssertNotEqual(waiting(onCollection: "3").waitingOn, waiting(onCollection: "4").waitingOn)
    XCTAssertEqual(Set([waiting(onCollection: "3"), waiting(onCollection: "3")]).count, 1)
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }
}
