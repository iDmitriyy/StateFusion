//
//  ValuePublisherOperatorsInit.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 17.07.2026.
//

public import Combine
import StateFusion
import Testing

struct ValuePublisherOperatorsInit {
  let outer: Int = 150
  let inner: Int = 1000

  /// Measures the performance overhead of creating a chain of Combine operators (e.g. .map)
  /// using three different approaches for a CurrentValuePublisher.
  /// It specifically bench-marks how the internal storage mechanism of each wrapper affects memory
  /// allocation and CPU time during type initialization.
  @Test func `Operators Chain Creation`() {
    let currentValueSubject = CurrentValueSubject<String, Never>("")
    let currentValuePublisher = CurrentValuePublisher(currentValueSubject) // Library actual implementation
    let currentValuePublisherA = CurrentValuePublisher1(currentValueSubject)
    let currentValuePublisherB = CurrentValuePublisher2(currentValueSubject)
    let currentValuePublisherC = CurrentValuePublisher3(currentValueSubject)

    let (_, tCurrentValueSubject) = performMeasuredAction(count: outer) { // reference measurement
      for _ in 0..<inner {
        blackHole(currentValueSubject.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" })
      }
    }

    let (_, tCurrentValueSubjectErased) = performMeasuredAction(count: outer) { // reference measurement
      for _ in 0..<inner {
        blackHole(currentValueSubject.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.eraseToAnyPublisher())
      }
    }

    let (_, tValuePublisher) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(currentValuePublisher.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" })
      }
    }

    let (_, tValuePublisherA) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(currentValuePublisherA.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" })
      }
    }
    // FIXME: - write difference from map2
    // this variant eliminate nesting in chain "CurrentValuePublisher-Base1-CurrentValuePublisher-Base2..."
    let (_, tValuePublisherB_1) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(currentValuePublisherB.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" })
      }
    }

    let (_, tValuePublisherB_2) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(currentValuePublisherB.map2 { $0 }.map2 { $0 }.map2 { $0 }.map2 { $0 }.map2 { "\($0)" })
      }
    }

    let (_, tValuePublisherC_1) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(currentValuePublisherC.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" })
      }
    }

    let (_, tValuePublisherC_2) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(currentValuePublisherC.map2 { $0 }.map2 { $0 }.map2 { $0 }.map2 { $0 }.map2 { "\($0)" })
      }
    }

    printTable("OperatorsChain Init",
               decimalDigits: 0,
               rows: [("CurrentValueSubject", tCurrentValueSubject),
                      ("CurrentValueSubjectErased", tCurrentValueSubjectErased),
                      ("ValuePublisher", tValuePublisher),
                      ("ValuePublisherA", tValuePublisherA),
                      ("ValuePublisherB_1", tValuePublisherB_1),
                      ("ValuePublisherB_2", tValuePublisherB_2),
                      ("ValuePublisherC_1", tValuePublisherC_1),
                      ("ValuePublisherC_2", tValuePublisherC_2)])
  }
}

extension CurrentValuePublisher1 {
  public func map<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher1<T, Failure> {
    let map = Publishers.Map(upstream: self, transform: transform)
    return CurrentValuePublisher1<T, Failure>(retained_unverifiedValuePublisher: map)
  }
}

extension CurrentValuePublisher2 {
  public func map<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher2<T, Failure> {
    func wrap(unboxingAny base: some Publisher<Output, Failure>) -> CurrentValuePublisher2<T, Failure> {
      let map = Publishers.Map(upstream: base, transform: transform)
      return CurrentValuePublisher2<T, Failure>(retained_unverifiedValuePublisher: map)
    }
    return wrap(unboxingAny: _base)
  }

  public func map2<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher2<T, Failure> {
    let map = Publishers.Map(upstream: self, transform: transform)
    return CurrentValuePublisher2<T, Failure>(retained_unverifiedValuePublisher: map)
  }
}

extension CurrentValuePublisher3 {
  public func map<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher3<T, Failure> {
    let map = Publishers.Map(upstream: _base, transform: transform)
    return CurrentValuePublisher3<T, Failure>(retained_unverifiedValuePublisher: map)
  }

  public func map2<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher3<T, Failure> {
    let map = Publishers.Map(upstream: self, transform: transform)
    return CurrentValuePublisher3<T, Failure>(retained_unverifiedValuePublisher: map)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher (Non-Versioned, Generic Failure)

/// Closure-capturing imp.
/// `base: P` is captured by closure, no existential boxing
struct CurrentValuePublisher1<Output, Failure: Error>: Publisher {
  @usableFromInline
  /* private */ internal let _subscribeClosure: (any Subscriber<Output, Failure>) -> Void

  @inlinable
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P)
    where P.Output == Output, P.Failure == Failure {
    _subscribeClosure = { [base] subscriber in
      base.receive(subscriber: subscriber)
    }
  }

  @inlinable
  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _subscribeClosure(subscriber)
  }
}

extension CurrentValuePublisher1 {
  public init(_ subject: CurrentValueSubject<Output, Failure>) {
    self.init(retained_unverifiedValuePublisher: subject)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher 2

/// Existential implementation.
/// `base: P` is wrapped by existential container.
struct CurrentValuePublisher2<Output, Failure: Error>: Publisher {
  @usableFromInline
  /* private */ internal let _base: any Publisher<Output, Failure>

  @inlinable
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P) where P.Output == Output, P.Failure == Failure {
    _base = base
  }

  @inlinable
  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _base.receive(subscriber: subscriber)
  }
}

extension CurrentValuePublisher2 {
  init(_ subject: CurrentValueSubject<Output, Failure>) {
    self.init(retained_unverifiedValuePublisher: subject)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher 3

/// AnyPublisher implementation.
/// `base: P` is wrapped by AnyPublisher
struct CurrentValuePublisher3<Output, Failure: Error>: Publisher {
  @usableFromInline
  /* private */ internal let _base: AnyPublisher<Output, Failure>

  @inlinable
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P) where P.Output == Output, P.Failure == Failure {
    _base = base.eraseToAnyPublisher()
  }

  @inlinable
  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _base.receive(subscriber: subscriber)
  }
}

extension CurrentValuePublisher3 {
  init(_ subject: CurrentValueSubject<Output, Failure>) {
    self.init(retained_unverifiedValuePublisher: subject)
  }
}
