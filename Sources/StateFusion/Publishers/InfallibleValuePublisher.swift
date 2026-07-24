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

public typealias InfallibleValuePublisher<Output> = CurrentValuePublisher<Output, Never>

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher (Non-Versioned, Generic Failure)

public struct CurrentValuePublisher<Output, Failure: Error>: Publisher {
  private let _base: any Publisher<Output, Failure>

  // TODO: - ?replace generic param by existential
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P) where P.Output == Output, P.Failure == Failure {
    _base = base
  }
  
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P,
                              getCurrentValue _: @escaping () -> Output) where P.Output == Output, P.Failure == Failure {
    _base = base
  }
  
  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _base.receive(subscriber: subscriber)
  }
}

extension CurrentValuePublisher {
  public init(_ subject: CurrentValueSubject<Output, Failure>) {
    self.init(retained_unverifiedValuePublisher: subject,
              getCurrentValue: { [unowned subject] in subject.value })
  }
}
