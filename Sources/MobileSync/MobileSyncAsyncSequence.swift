/// Values MobileSync publishes over time, such as the latest notes after every change.
///
/// Iterating it runs a MobileSync collector, which stops when the task iterating it is cancelled or the iterator is
/// dropped, so breaking out of a loop or taking `.first` stops it too.
public struct MobileSyncAsyncSequence<Element>: AsyncSequence {
  public struct AsyncIterator: AsyncIteratorProtocol {
    init<Sequence: AsyncSequence>(_ sequence: Sequence, mapError: @escaping (Error) -> Error)
    where Sequence.Element == Element {
      collector = Collector(sequence.makeAsyncIterator(), mapError: mapError)
    }

    public func next() async throws -> Element? {
      try await collector.next()
    }

    private let collector: Collector
  }

  init<Sequence: AsyncSequence>(_ sequence: Sequence, mapError: @escaping (Error) -> Error = { $0 })
  where Sequence.Element == Element {
    makeIteratorValue = {
      AsyncIterator(sequence, mapError: mapError)
    }
  }

  public func makeAsyncIterator() -> AsyncIterator {
    makeIteratorValue()
  }

  private let makeIteratorValue: () -> AsyncIterator
}

extension MobileSyncAsyncSequence {
  /// The wrapped iterator, shared by every copy of `AsyncIterator`; dropping the last copy stops its collector.
  ///
  /// KMP-NativeCoroutines cancels the collector when its iterator is dropped, but a collector that has handed over a
  /// value waits until that value is taken, and a cancel doesn't interrupt the wait. A collector left waiting fills
  /// the buffer of a MobileSync reader shared by other collectors and stops it for all of them. Asking once more from
  /// a cancelled task takes the waiting value, if any, and stops the collector at once.
  private final class Collector {
    init<Iterator: AsyncIteratorProtocol>(_ iterator: Iterator, mapError: @escaping (Error) -> Error)
    where Iterator.Element == Element {
      var iterator = iterator
      nextValue = {
        do {
          return try await iterator.next()
        } catch {
          throw mapError(error)
        }
      }
    }

    deinit {
      // Nothing else can call it once the last owner is gone.
      nonisolated(unsafe) let nextValue = nextValue
      Task {
        withUnsafeCurrentTask { $0?.cancel() }
        _ = try? await nextValue()
      }
    }

    func next() async throws -> Element? {
      try await nextValue()
    }

    private let nextValue: () async throws -> Element?
  }
}
