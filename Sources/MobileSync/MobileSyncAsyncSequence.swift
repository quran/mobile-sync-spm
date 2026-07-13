public struct MobileSyncAsyncSequence<Element>: AsyncSequence {
  public struct AsyncIterator: AsyncIteratorProtocol {
    init<Sequence: AsyncSequence>(_ sequence: Sequence) where Sequence.Element == Element {
      var iterator = sequence.makeAsyncIterator()
      nextValue = {
        try await iterator.next()
      }
    }

    public mutating func next() async throws -> Element? {
      try await nextValue()
    }

    private let nextValue: () async throws -> Element?
  }

  init<Sequence: AsyncSequence>(_ sequence: Sequence) where Sequence.Element == Element {
    makeIteratorValue = {
      AsyncIterator(sequence)
    }
  }

  public func makeAsyncIterator() -> AsyncIterator {
    makeIteratorValue()
  }

  private let makeIteratorValue: () -> AsyncIterator
}
