/// Values MobileSync publishes over time, such as the latest notes after every change.
public struct MobileSyncAsyncSequence<Element>: AsyncSequence {
  public struct AsyncIterator: AsyncIteratorProtocol {
    init<Sequence: AsyncSequence>(_ sequence: Sequence, mapError: @escaping (Error) -> Error)
    where Sequence.Element == Element {
      var iterator = sequence.makeAsyncIterator()
      nextValue = {
        do {
          return try await iterator.next()
        } catch {
          throw mapError(error)
        }
      }
    }

    public func next() async throws -> Element? {
      try await nextValue()
    }

    private let nextValue: () async throws -> Element?
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
