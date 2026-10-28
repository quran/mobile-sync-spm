import KMPNativeCoroutinesAsync
import KMPNativeCoroutinesCore
import XCTest
@testable import MobileSync

final class MobileSyncAsyncSequenceTests: XCTestCase {
  func testForwardsValuesFromWrappedSequence() async throws {
    let source = AsyncStream<Int> { continuation in
      continuation.yield(1)
      continuation.yield(2)
      continuation.finish()
    }
    let iterator = MobileSyncAsyncSequence(source).makeAsyncIterator()

    let first = try await iterator.next()
    let second = try await iterator.next()
    let end = try await iterator.next()

    XCTAssertEqual(first, 1)
    XCTAssertEqual(second, 2)
    XCTAssertNil(end)
  }

  func testMapsErrorsFromWrappedSequence() async {
    struct Source: Error {}
    struct Mapped: Error {}
    let source = AsyncThrowingStream<Int, Error> { continuation in
      continuation.finish(throwing: Source())
    }
    let iterator = MobileSyncAsyncSequence(source, mapError: { _ in Mapped() }).makeAsyncIterator()

    do {
      _ = try await iterator.next()
      XCTFail("Expected the source error")
    } catch {
      XCTAssertTrue(error is Mapped)
    }
  }

  // MARK: Collector

  func testKeepsCollectingWhileTheIteratorIsAlive() async throws {
    let flow = NativeFlowFake()
    let iterator = MobileSyncAsyncSequence(asyncSequence(for: flow.nativeFlow)).makeAsyncIterator()

    let values = [try await iterator.next(), try await iterator.next(), try await iterator.next()]

    XCTAssertEqual(values, [0, 1, 2])
    XCTAssertFalse(flow.isCancelRequested)
    withExtendedLifetime(iterator) {}
  }

  /// Kotlin waits in the collector until the waiting value is taken, so cancelling alone wouldn't stop it.
  func testDroppingTheIteratorWithAValueWaitingStopsTheCollector() async throws {
    let flow = NativeFlowFake()
    do {
      let iterator = MobileSyncAsyncSequence(asyncSequence(for: flow.nativeFlow)).makeAsyncIterator()
      let first = try await iterator.next()
      await fulfillment(of: [flow.emitted[1]], timeout: 5)

      XCTAssertEqual(first, 0)
      withExtendedLifetime(iterator) {}
    }

    await fulfillment(of: [flow.collectorStopped], timeout: 5)
  }

  func testFirstStopsTheCollector() async throws {
    let flow = NativeFlowFake()

    let first = try await MobileSyncAsyncSequence(asyncSequence(for: flow.nativeFlow)).first { _ in true }

    XCTAssertEqual(first, 0)
    await fulfillment(of: [flow.collectorStopped], timeout: 5)
  }

  func testBreakingOutOfALoopStopsTheCollector() async throws {
    let flow = NativeFlowFake()

    var values: [Int] = []
    for try await value in MobileSyncAsyncSequence(asyncSequence(for: flow.nativeFlow)) {
      values.append(value)
      if values.count == 2 {
        break
      }
    }

    XCTAssertEqual(values, [0, 1])
    await fulfillment(of: [flow.collectorStopped], timeout: 5)
  }
}

/// A Kotlin flow at the native boundary. Like a MobileSync flow after every change, it emits 0, 1, 2… as its
/// collector takes them, the next one once the collector is ready.
///
/// Like KMP-NativeCoroutines' Kotlin side, the collector waits after handing over a value until that value's `next`
/// callback runs, and a cancel doesn't interrupt that wait: with a value waiting, the collector stops only once its
/// `next` callback runs; otherwise it stops at once.
private final class NativeFlowFake: @unchecked Sendable {
  let collectorStopped = XCTestExpectation(description: "The collector stopped")
  /// Fulfilled once value `n` is handed to the collector.
  let emitted = (0..<5).map { XCTestExpectation(description: "Emitted \($0)") }

  var isCancelRequested: Bool {
    queue.sync { cancelRequested }
  }

  var nativeFlow: NativeFlow<Int, Error, Void> {
    { [self] onItem, _, onCancelled in
      queue.sync {
        self.onItem = onItem
        self.onCancelled = onCancelled
      }
      emit(0)
      return { [self] in
        queue.async { [self] in
          cancelRequested = true
          if waitingValue == nil {
            stop()
          }
        }
      }
    }
  }

  // Kotlin calls back on its own threads, never while the collector is waiting to emit.
  private let queue = DispatchQueue(label: "NativeFlowFake")
  private var onItem: NativeCallback2<Int, () -> Void, Void>?
  private var onCancelled: NativeCallback<Error, Void>?
  private var cancelRequested = false
  private var stopped = false
  /// The value handed to the collector whose `next` callback hasn't run yet.
  private var waitingValue: Int?

  private func emit(_ value: Int) {
    queue.async { [self] in
      guard !cancelRequested else {
        return stop()
      }
      waitingValue = value
      onItem?(value, { [self] in taken(value) }, ())
      if emitted.indices.contains(value) {
        emitted[value].fulfill()
      }
    }
  }

  private func taken(_ value: Int) {
    queue.async { [self] in
      waitingValue = nil
      if cancelRequested {
        stop()
      } else {
        emit(value + 1)
      }
    }
  }

  private func stop() {
    guard !stopped else {
      return
    }
    stopped = true
    onCancelled?(CancellationError(), ())
    collectorStopped.fulfill()
  }
}
