//
//  InfallibleValuePublisher.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 13.06.2026.
//

public import Combine

// MARK: - InfallibleValuePublisher (Non-Versioned)

/// A type-erasing publisher that represents a continuous state or value stream without version tracking.
///
/// Use this when you only need to subscribe to values and don't need `takeUpdates(afterSnapshot:)` or `valueSnapshot`.
/// For versioned access, use `VersionedValuePublisher` instead.
public final class InfallibleValuePublisher<Output>: Publisher {
  public typealias Failure = Never

  @usableFromInline
  /* private */ internal let _subscribeClosure: (any Subscriber<Output, Never>) -> Void

  @inlinable
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P,
                              getCurrentValue _: @escaping () -> Output)
    where P.Output == Output, P.Failure == Failure {
    _subscribeClosure = { [base] subscriber in
      base.receive(subscriber: subscriber)
    }
  }
  
  @inlinable
  internal init(subscribe: @escaping (any Subscriber<Output, Failure>) -> Void,
                getCurrentValue _: @escaping () -> Output) {
    _subscribeClosure = subscribe
  }

  @inlinable
  public final func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
    _subscribeClosure(subscriber)
  }
}



//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher (Non-Versioned, Generic Failure)

public struct CurrentValuePublisher<Output, Failure: Error>: Publisher {
  /// private
  @usableFromInline
  /* private */ internal let _subscribeClosure: (any Subscriber<Output, Failure>) -> Void

  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P,
                              getCurrentValue: @escaping () -> Output)
    where P.Output == Output, P.Failure == Failure {
    _subscribeClosure = { [base] subscriber in
      base.receive(subscriber: subscriber)
    }
  }

  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _subscribeClosure(subscriber)
  }
}

extension CurrentValuePublisher {
  public init(_ subject: CurrentValueSubject<Output, Failure>) {
    self.init(retained_unverifiedValuePublisher: subject,
              getCurrentValue: { [unowned subject] in subject.value })
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - VersionedValuePublisher

/// A type-erasing publisher that represents a continuous state or value stream with version tracking.
///
/// Supports `takeUpdates(afterSnapshot:)` for bridging the read-subscribe time gap without duplicates.
/// Use `valueSnapshot` to atomically read the current state as a `SequentialSnapshot`.
//public final class VersionedValuePublisher<Output>: Publisher {
//  public typealias Failure = Never
//
//  @usableFromInline
//  /* private */ internal let _getCurrentValueSnapshot: () -> SequentialSnapshot<Output>
//
//  @usableFromInline
//  /* private */ internal let _subscribeClosure: (AnySubscriber<Output, Never>) -> Void
//
//  @usableFromInline
//  /* private */ internal let _takeUpdatesClosure: (SequentialSnapshot<Output>) -> AnyPublisher<Output, Never>
//
//  @inlinable
//  internal init<P: Publisher>(
//    retained_unverifiedValuePublisher base: P,
//    getCurrentValueSnapshot: @escaping () -> SequentialSnapshot<Output>,
//    takeUpdates: @escaping (SequentialSnapshot<Output>) -> AnyPublisher<Output, Never>
//  )
//    where P.Output == Output, P.Failure == Never {
//    _subscribeClosure = { [base] subscriber in
//      base.receive(subscriber: subscriber)
//    }
//    _getCurrentValueSnapshot = getCurrentValueSnapshot
//    _takeUpdatesClosure = takeUpdates
//  }
//
//  @inlinable
//  public final var valueSnapshot: SequentialSnapshot<Output> {
//    _getCurrentValueSnapshot()
//  }
//
//  @inlinable
//  public final func takeUpdates(afterSnapshot snapshot: SequentialSnapshot<Output>) -> AnyPublisher<Output, Never> {
//    _takeUpdatesClosure(snapshot)
//  }
//
//  @inlinable
//  public final func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
//    _subscribeClosure(AnySubscriber(subscriber))
//  }
//}
