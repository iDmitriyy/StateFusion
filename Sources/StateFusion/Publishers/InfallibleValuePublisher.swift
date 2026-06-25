//
//  InfallibleValuePublisher.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 13.06.2026.
//

public import Combine

/// A type-erasing publisher that represents a continuous state or value stream.
public final class InfallibleValuePublisher<Output>: Publisher {
  public typealias Failure = Never

  /// private
  @usableFromInline
  /* private */ internal let _getCurrentValueSnapshot: () -> SequentialSnapshot<Output>

  /// private
  @usableFromInline
  /* private */ internal let _subscribeClosure: (AnySubscriber<Output, Never>) -> Void

  @inlinable
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P,
                              getCurrentValueSnapshot: @escaping () -> SequentialSnapshot<Output>)
    where P.Output == Output, P.Failure == Never {
    _subscribeClosure = { [base] subscriber in
      base.receive(subscriber: subscriber)
    }

    _getCurrentValueSnapshot = getCurrentValueSnapshot
  }

  @inlinable
  public final func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
    _subscribeClosure(AnySubscriber(subscriber))
  }
}

extension InfallibleValuePublisher {
  @inlinable
  public final func takeUpdates(afterSnapshot snapshot: SequentialSnapshot<Output>) -> AnyPublisher<Output, Never> {
    _ = snapshot
    fatalError()
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher

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
