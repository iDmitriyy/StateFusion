//
//  _Rewrite.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.06.2026.
//

public import Combine
import class Foundation.NSRecursiveLock

// MARK: - InfallibleValueSubject

/// A thread-safe, infallible Subject that holds a current value and supports atomic read-modify-write.
///
/// Unlike `CurrentValueSubject`, this type:
/// - Is guaranteed to never fail (`Failure == Never`)
/// - Supports atomic mutations via `withLockMutableAccess`
/// - Tracks every value change with a monotonically increasing serial number
/// - Can be explicitly completed via `send(completion:)`
/// - Does NOT send `.finished` on deallocation
//public final class InfallibleValueSubjectNew<Output>: Subject, @unchecked Sendable {
//  public typealias Failure = Never
//
//  private let _lock = NSRecursiveLock()
//  private var _value: Output
//  private var _version: UInt32
//  private var _conduits: ContiguousArray<Conduit>
//
//  public var value: Output {
//    _lock.lock(); defer { _lock.unlock() }
//    return _value
//  }
//
//  public var valueSnapshot: SequentialSnapshot<Output> {
//    _lock.lock(); defer { _lock.unlock() }
//    return SequentialSnapshot(value: _value, version: _version)
//  }
//
//  public init(_ value: Output) {
//    _value = value
//    _version = 0
//    _conduits = ContiguousArray()
//  }
//
//  // MARK: Publisher
//
//  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
//    // if isCompleted { subscriber.receive(completion: ) }
//
//    let conduit = Conduit(upstream: self, downstream: subscriber)
//    _lock.lock()
//    _conduits.append(conduit)
//    _lock.unlock()
//    subscriber.receive(subscription: conduit)
//  }
//
//  // MARK: Subject
//
//  public func send(_ value: Output) {
//    let conduits: ContiguousArray<Conduit>
//    _lock.lock()
//    _version += 1
//    _value = value
//    conduits = _conduits
//    _lock.unlock()
//
//    for conduit in conduits {
//      conduit.receive(value)
//    }
//  }
//
//  public func send(completion: Subscribers.Completion<Never>) {
//    let conduits: ContiguousArray<Conduit>
//    _lock.lock()
//    conduits = _conduits
//    _conduits.removeAll()
//    _lock.unlock()
//
//    for conduit in conduits {
//      conduit.receive(completion: completion)
//    }
//  }
//
//  public func send(subscription _: any Subscription) {
//    // No-op: conduits are managed via receive(subscriber:)
//    // FIXME: do it
//  }
//
//  // MARK: Atomic Mutation
//
//  /// Atomically mutates the current value and notifies all subscribers.
//  ///
//  /// The `access` closure receives an `inout` reference to the current value.
//  /// After the closure returns, the version is incremented and all subscribers are notified.
//  public func withLockMutableAccess<R>(
//    _ access: (inout Output) -> R,
//  ) -> R {
//    let result: R
//    let conduits: ContiguousArray<Conduit>
//    let value: Output
//
//    _lock.lock()
//    result = access(&_value)
//    _version += 1
//    conduits = _conduits
//    value = _value
//    _lock.unlock()
//
//    for conduit in conduits {
//      conduit.receive(value)
//    }
//
//    return result
//  }
//
//  // MARK: Internal
//
//  fileprivate func remove(_ conduit: Conduit) {
//    _lock.lock()
//    guard let index = _conduits.firstIndex(of: conduit) else {
//      _lock.unlock()
//      return
//    }
//    _conduits.remove(at: index)
//    _lock.unlock()
//  }
//}
//
//// MARK: - Conduit (Subject)
//
//extension InfallibleValueSubjectNew {
//  fileprivate final class Conduit: Combine.Subscription, Equatable {
//    private let _lock = NSRecursiveLock()
//    private var _demand: Subscribers.Demand = .none
//    private var _receivedLastValue = false
//    private var _downstream: (any Subscriber<Output, Never>)?
//    private weak var _upstream: InfallibleValueSubjectNew?
//
//    init(
//      upstream: InfallibleValueSubjectNew,
//      downstream: any Subscriber<Output, Never>,
//    ) {
//      _upstream = upstream
//      _downstream = downstream
//    }
//
//    func cancel() {
//      _lock.lock()
//      _downstream = nil
//      let upstream = _upstream
//      _lock.unlock()
//      upstream?.remove(self)
//    }
//
//    func receive(_ value: Output) {
//      _lock.lock()
//      guard let downstream = _downstream else {
//        _lock.unlock()
//        return
//      }
//
//      switch _demand {
//      case .unlimited:
//        _lock.unlock()
//        _ = downstream.receive(value)
//
//      case .none:
//        _receivedLastValue = false
//        _lock.unlock()
//
//      default:
//        _receivedLastValue = true
//        _demand -= 1
//        _lock.unlock()
//        let moreDemand = downstream.receive(value)
//        _lock.lock()
//        _demand += moreDemand
//        _lock.unlock()
//      }
//    }
//
//    func receive(completion: Subscribers.Completion<Never>) {
//      _lock.lock()
//      guard let downstream = _downstream else {
//        _lock.unlock()
//        return
//      }
//      _downstream = nil
//      _lock.unlock()
//      downstream.receive(completion: completion)
//    }
//
//    func request(_ demand: Subscribers.Demand) {
//      precondition(demand > 0, "Demand must be greater than zero")
//
//      _lock.lock()
//      guard let downstream = _downstream else {
//        _lock.unlock()
//        return
//      }
//
//      _demand += demand
//
//      guard !_receivedLastValue, let upstream = _upstream else {
//        _lock.unlock()
//        return
//      }
//
//      _receivedLastValue = true
//      let value = upstream.value
//
//      switch _demand {
//      case .unlimited:
//        _lock.unlock()
//        _ = downstream.receive(value)
//
//      default:
//        _demand -= 1
//        _lock.unlock()
//        let moreDemand = downstream.receive(value)
//        _lock.lock()
//        _demand += moreDemand
//        _lock.unlock()
//      }
//    }
//
//    static func == (lhs: Conduit, rhs: Conduit) -> Bool {
//      lhs === rhs
//    }
//  }
//}
//
//// MARK: - InfallibleValueRelay
//
///// A thread-safe, infallible Relay that holds a current value and supports atomic read-modify-write.
/////
///// Unlike `CurrentValueRelay`, this type:
///// - Supports atomic mutations via `withLockMutableAccess`
///// - Tracks every value change with a monotonically increasing serial number
///// - Automatically sends `.finished` upon deallocation, tearing down downstream pipelines
///// - Cannot be explicitly completed by the user
//public final class InfallibleValueRelayNew<Output>: Publisher, @unchecked Sendable {
//  public typealias Failure = Never
//
//  private let _lock = NSRecursiveLock()
//  private var _value: Output
//  private var _version: UInt32
//  private var _conduits: ContiguousArray<Conduit>
//
//  public var value: Output {
//    _lock.lock(); defer { _lock.unlock() }
//    return _value
//  }
//
//  public var valueSnapshot: SequentialSnapshot<Output> {
//    _lock.lock(); defer { _lock.unlock() }
//    return SequentialSnapshot(value: _value, version: _version)
//  }
//
//  public init(_ value: Output) {
//    _value = value
//    _version = 0
//    _conduits = ContiguousArray()
//  }
//
//  deinit {
//    let conduits: ContiguousArray<Conduit>
//    _lock.lock()
//    conduits = _conduits
//    _conduits.removeAll()
//    _lock.unlock()
//
//    for conduit in conduits {
//      conduit.receive(completion: .finished)
//    }
//  }
//
//  // MARK: Publisher
//
//  public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Output {
//    let conduit = Conduit(upstream: self, downstream: subscriber)
//    _lock.lock()
//    _conduits.append(conduit)
//    _lock.unlock()
//    subscriber.receive(subscription: conduit)
//  }
//
//  // MARK: Send
//
//  public func send(_ value: Output) {
//    let conduits: ContiguousArray<Conduit>
//    _lock.lock()
//    _version += 1
//    _value = value
//    conduits = _conduits
//    _lock.unlock()
//
//    for conduit in conduits {
//      conduit.receive(value)
//    }
//  }
//
//  // MARK: Atomic Mutation
//
//  /// Atomically mutates the current value and notifies all subscribers.
//  ///
//  /// The `access` closure receives an `inout` reference to the current value.
//  /// After the closure returns, the version is incremented and all subscribers are notified.
//  public func withLockMutableAccess<R>(
//    _ access: (inout Output) -> R,
//  ) -> R {
//    let result: R
//    let conduits: ContiguousArray<Conduit>
//    let value: Output
//
//    _lock.lock()
//    result = access(&_value)
//    _version += 1
//    conduits = _conduits
//    value = _value
//    _lock.unlock()
//
//    for conduit in conduits {
//      conduit.receive(value)
//    }
//
//    return result
//  }
//
//  // MARK: Internal
//
//  fileprivate func remove(_ conduit: Conduit) {
//    _lock.lock()
//    guard let index = _conduits.firstIndex(of: conduit) else {
//      _lock.unlock()
//      return
//    }
//    _conduits.remove(at: index)
//    _lock.unlock()
//  }
//}
//
//// MARK: - Conduit (Relay)
//
//extension InfallibleValueRelayNew {
//  fileprivate final class Conduit: Combine.Subscription, Equatable {
//    private let _lock = NSRecursiveLock()
//    private var _demand: Subscribers.Demand = .none
//    private var _receivedLastValue = false
//    private var _downstream: (any Subscriber<Output, Never>)?
//    private weak var _upstream: InfallibleValueRelayNew?
//
//    init(upstream: InfallibleValueRelayNew,
//         downstream: any Subscriber<Output, Never>) {
//      _upstream = upstream
//      _downstream = downstream
//    }
//
//    final func cancel() {
//      _lock.lock()
//      _downstream = nil
//      let upstream = _upstream
//      _lock.unlock()
//      upstream?.remove(self)
//    }
//
//    final func receive(_ value: Output) {
//      _lock.lock()
//      guard let downstream = _downstream else {
//        _lock.unlock()
//        return
//      }
//
//      switch _demand {
//      case .unlimited:
//        _lock.unlock()
//        _ = downstream.receive(value)
//
//      case .none:
//        _receivedLastValue = false
//        _lock.unlock()
//
//      default:
//        _receivedLastValue = true
//        _demand -= 1
//        _lock.unlock()
//        let moreDemand = downstream.receive(value)
//        _lock.lock()
//        _demand += moreDemand
//        _lock.unlock()
//      }
//    }
//
//    final func receive(completion: Subscribers.Completion<Never>) {
//      _lock.lock()
//      guard let downstream = _downstream else {
//        _lock.unlock()
//        return
//      }
//      _downstream = nil
//      _lock.unlock()
//      downstream.receive(completion: completion)
//    }
//
//    final func request(_ demand: Subscribers.Demand) {
//      precondition(demand > 0, "Demand must be greater than zero")
//
//      _lock.lock()
//      guard let downstream = _downstream else {
//        _lock.unlock()
//        return
//      }
//
//      _demand += demand
//
//      guard !_receivedLastValue, let upstream = _upstream else {
//        _lock.unlock()
//        return
//      }
//
//      _receivedLastValue = true
//      let value = upstream.value
//
//      switch _demand {
//      case .unlimited:
//        _lock.unlock()
//        _ = downstream.receive(value)
//
//      default:
//        _demand -= 1
//        _lock.unlock()
//        let moreDemand = downstream.receive(value)
//        _lock.lock()
//        _demand += moreDemand
//        _lock.unlock()
//      }
//    }
//
//    static func == (lhs: Conduit, rhs: Conduit) -> Bool {
//      lhs === rhs
//    }
//  }
//}
