//
//  InsulatedVersionedValueRelay.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 27.06.2026.
//

public import Combine

//===-------------------------------------------------------------------------------------------------------------------===//
// MARK: - Insulated VersionedValue Relay

// TODO: ? ~Copyable

internal final class InsulatedVersionedValueRelay<Value>: Publisher, Sendable {
  typealias Output = (value: Value, version: UInt32)
  typealias Failure = Never

  private let _data: RecursiveLock<(value: Value, version: UInt32, subscriptions: ContiguousArray<Subscription>)>
  private let id: SourceID = SourceID()
  
  init(_ value: Value) {
    _data = RecursiveLock(uncheckedState: (value: value, version: 0, subscriptions: ContiguousArray()))
  }

  deinit {
    // TBD
  }

  // MARK: Publisher Protocol Imp
  
  func receive(subscriber: some Subscriber<Output, Never>) {
    let subscription = Subscription(upstream: self, downstream: subscriber)
    _data.withLock {
      $0.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }
  
  // MARK: Relay Specific
  
  internal func internal_terminateWithCompletion() {
    // send(completion: .finished)
  }

  internal func send(nextValue value: Value) {
    _data.withLock {
      $0.version += 1
      $0.value = value
      // !!!
      let snapshot = SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
      for subscription in $0.subscriptions {
        subscription.receive(snapshot)
      }
    }
  }
  
  internal final func withInoutAccess<R>(_ access: (inout Value) -> sending R)
    -> sending R {
      _data.withLock {
        $0.version += 1
        let result = access(&$0.value)
        // !!!
        let snapshot = SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
        for subscription in $0.subscriptions {
          subscription.receive(snapshot)
        }
        return result
      }
    }

//  internal final func withMutationTrackingAccess<R>(_: (inout GenericStateAccessHandle<Value>) -> sending R)
//    -> sending R {
//
//    }

  // MARK: Private Imp
  
  private func remove(_ subscription: Subscription) {
    _data.withLock {
      guard let index = $0.subscriptions.firstIndex(of: subscription) else { return }
      $0.subscriptions.remove(at: index)
    }
  }
}

extension InsulatedVersionedValueRelay {
  // func valuePublisher() -> some Publisher<Value, Never>
  
  // func snapshotPublisher() -> some Publisher<SequentialSnapshot<Value>, Never>
}

extension InsulatedVersionedValueRelay {
//  private var _uncheckedOutputSnapshot: Output {
//    _data.withLockUncheckedSending {
//      (value: $0.value, version: $0.version)
//    }
//  }
}

extension InsulatedVersionedValueRelay {
  fileprivate final var uncheckedSendable_valueSnapshot: SequentialSnapshot<Value> {
    _data.withLockUncheckedSending {
      SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
    }
  }
}

extension InsulatedVersionedValueRelay where Value: Sendable {
  final var valueSnapshot: SequentialSnapshot<Value> {
    _data.withLock {
      SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
    }
  }
  
  final func takeUpdates(afterSnapshot snapshot: SequentialSnapshot<Value>) -> some Publisher<Value, Never> {
    let predicate: (Output) -> Bool
    if snapshot._sourceID == id {
      predicate = { [referenceVersion = snapshot._version] in
        $0.version <= referenceVersion
      }
    } else {
      predicate = { _ in
        false
      }
      log(.warning, StateFusionLogEntry(code: .snapshotSourceMismatch, message: "Snapshot sourceID mismatch"))
    }
    
    return drop(while: predicate).map { $0.value }
    // FIXME: + share
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - TakeUpdates Publisher

extension Publishers {
//  private struct TakeUpdatesPublisher<Value>: Publisher where Value: Sendable {
//    typealias Output = Value
//    typealias Failure = Never
//
//    private let relay: InsulatedVersionedValueRelay<Value>
//    private let snapshot: SequentialSnapshot<Value>
//
//    init(relay: InsulatedVersionedValueRelay2<Value>, snapshot: SequentialSnapshot<Value>) {
//      self.relay = relay
//      self.snapshot = snapshot
//    }
//
//    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
//      relay.receiveTakeUpdates(subscriber: subscriber, snapshot: snapshot)
//    }
//  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - ____

extension Publishers {
  /// A wrapper that exposes a versioned-value publisher interface.
//  struct VersionedSnapshotView<Value>: Sendable {
//    typealias Output = (value: Value, version: UInt32)
//    typealias Failure = Never
//    
//    private let relay: InsulatedVersionedValueRelay<Value>
//
//    fileprivate init(relay: InsulatedVersionedValueRelay<Value>) {
//      self.relay = relay
//    }
//    
//    func receive<S>(subscriber: S) where S: Subscriber, S.Input == Output, S.Failure == Never {
//      relay.receiveVersioned(subscriber: subscriber)
//    }
//  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - Subscription

import Foundation

extension InsulatedVersionedValueRelay {
  fileprivate final class Subscription: Combine.Subscription, Equatable {
    private var lifecycleStage: LifecycleStage
    private let lock: os_unfair_lock_t

    // MARK: - Init

    init(upstream: InsulatedVersionedValueRelay, downstream: any Subscriber<Output, Never>) {
      lifecycleStage = .active(ActiveState(upstream: upstream, downstream: .versionedValue(downstream)))
      lock = os_unfair_lock_t.allocate(capacity: 1)
      lock.initialize(to: os_unfair_lock())
    }

    deinit {
      lock.deinitialize(count: 1)
      lock.deallocate()
    }

    func receive(_ snapshot: SequentialSnapshot<Value>) {
      lock.lock()

      guard case .active(let activeState) = lifecycleStage else {
        lock.unlock()
        return
      }

      let upstreamID = activeState.upstream.id
      let downstream = activeState.downstream

      switch activeState.demand {
      case .unlimited:
        lock.unlock()
        // NB: Adding to unlimited demand has no effect and can be ignored.
        _ = downstream.receive(snapshot, upstreamID: upstreamID)

      case .none:
        activeState.receivedLastValue = false
        lock.unlock()

      default:
        activeState.receivedLastValue = true
        activeState.demand -= 1
        lock.unlock()
        // TODO: - need to validate this code brunch later. Why not make everything and then
        // lock.unlock()? Whit lock in 2 steps?
        let moreDemand = downstream.receive(snapshot, upstreamID: upstreamID)
        lock.sync {
          activeState.demand += moreDemand
        }
      }
    }
    
    // MARK: Combine.Subscription Imp

    func cancel() {
      lock.sync {
        if case .active(let state) = lifecycleStage {
          state.upstream.remove(self)
        }
        lifecycleStage = .terminal
        // downstream, upstream, demand, receivedLastValue are freed on cancellation.
      }
    }

    func request(_ demand: Subscribers.Demand) {
      precondition(demand > 0, "Demand must be greater than zero")
      // TODO: demand.assertNonZero()

      lock.lock()

      guard case .active(let activeState) = lifecycleStage else {
        lock.unlock()
        return
      }

      activeState.demand += demand
      
      guard !activeState.receivedLastValue else {
        lock.unlock()
        return
      }
      
      activeState.receivedLastValue = true
      
      let upstreamID = activeState.upstream.id
      let downstream = activeState.downstream
      let snapshot = activeState.upstream.uncheckedSendable_valueSnapshot

      switch activeState.demand {
      case .unlimited:
        lock.unlock()
        // NB: Adding to unlimited demand has no effect and can be ignored.
        _ = downstream.receive(snapshot, upstreamID: upstreamID)

      default:
        activeState.demand -= 1
        lock.unlock()
        let moreDemand = downstream.receive(snapshot, upstreamID: upstreamID)
        lock.sync {
          activeState.demand += moreDemand
        }
      }
    }

    // MARK: - Equatable

    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
      lhs === rhs
    }
    
    // MARK: - LifecycleStage

    enum LifecycleStage {
      case active(ActiveState)
      case terminal
    }

    /// Reference-type state blob so mutations are in-place (no write-back to `stage`).
    /// Only accessed under `lock`.
    final class ActiveState {
      let upstream: InsulatedVersionedValueRelay
      var downstream: SubscriberVariant
      var demand: Subscribers.Demand
      var receivedLastValue: Bool

      init(upstream: InsulatedVersionedValueRelay, downstream: SubscriberVariant) {
        self.upstream = upstream
        self.downstream = downstream
        self.demand = .none
        self.receivedLastValue = false
      }
    }
  }
}

// MARK: - SubscriberVariant

extension InsulatedVersionedValueRelay.Subscription {
  enum SubscriberVariant {
    case value(any Subscriber<Value, Never>)
    case valueTakeUpdatesAfter(referenceVersion: UInt32, sourceID: SourceID, any Subscriber<Value, Never>)
    case versionedValue(any Subscriber<(value: Value, version: UInt32), Never>)
    case versionedValueSnapshot(any Subscriber<SequentialSnapshot<Value>, Never>)

    func receive(_ new: SequentialSnapshot<Value>, upstreamID: SourceID) -> Subscribers.Demand {
      switch self {
      case let .value(downstream):
        return downstream.receive(new.value)

      case let .valueTakeUpdatesAfter(snapshotVersion, snapshotSourceID, downstream):
        // Analog of `drop(while: { $0._version <= snapshot.version })`
        if upstreamID == snapshotSourceID {
          if new._version > snapshotVersion {
            return downstream.receive(new.value)
          } else {
            return .none // TODO: is it correct to return none or nil?
          }
        } else {
          // if sourceID is not valid, then do not drop value (pass all)
          log(.warning, StateFusionLogEntry(code: .snapshotSourceMismatch, message: "Snapshot sourceID mismatch"))
          return downstream.receive(new.value)
        }
        // TODO: need to somehow remember a Bool indication that values must be send (as in dropWhile)
        // Variants: do it under a lock or use Atomic<Bool> with proper memory ordering

      case let .versionedValue(downstream):
        return downstream.receive((value: new.value, version: new._version))

      case let .versionedValueSnapshot(downstream):
        return downstream.receive(new)
      }
    }
  }
}

public import struct Darwin.os_unfair_lock_s

extension UnsafeMutablePointer<os_unfair_lock_s> {
  @inlinable @discardableResult
  func sync<R>(_ work: () -> R) -> R {
    os_unfair_lock_lock(self)
    defer { os_unfair_lock_unlock(self) }
    return work()
  }

  func lock() {
    os_unfair_lock_lock(self)
  }

  func unlock() {
    os_unfair_lock_unlock(self)
  }
}

//extension InsulatedVersionedValueRelay {
//  fileprivate final class Subscription: Combine.Subscription, Equatable {
//    private var upstream: InsulatedVersionedValueRelay?
//    private var downstream: (any Subscriber<Output, Never>)?
//
//    private var demand = Subscribers.Demand.none
//    private var receivedLastValue = false
//
//    private let lock: os_unfair_lock_t
//
//    init(upstream: InsulatedVersionedValueRelay, downstream: any Subscriber<Output, Never>) {
//      self.upstream = upstream
//      self.downstream = downstream
//      lock = os_unfair_lock_t.allocate(capacity: 1)
//      lock.initialize(to: os_unfair_lock())
//    }
//
//    deinit {
//      self.lock.deinitialize(count: 1)
//      self.lock.deallocate()
//    }
//    // MARK: Cancellable Imp
//
//    func cancel() {
//      lock.sync {
//        self.downstream = nil
//        self.upstream?.remove(self)
//        self.upstream = nil
//      }
//    }
//
//    func receive(_ value: SequentialSnapshot<Value>) {
//      lock.lock()
//
//      guard let downstream else {
//        lock.unlock()
//        return
//      }
//
//      switch demand {
//      case .unlimited:
//        lock.unlock()
//        // NB: Adding to unlimited demand has no effect and can be ignored.
//        _ = downstream.receive(value)
//
//      case .none:
//        receivedLastValue = false
//        lock.unlock()
//
//      default:
//        receivedLastValue = true
//        demand -= 1
//        lock.unlock()
//        let moreDemand = downstream.receive(value)
//        lock.sync {
//          self.demand += moreDemand
//        }
//      }
//    }
//
//    func request(_ demand: Subscribers.Demand) {
//      precondition(demand > 0, "Demand must be greater than zero")
//
//      lock.lock()
//
//      guard let downstream else {
//        lock.unlock()
//        return
//      }
//
//      self.demand += demand
//
//      guard !receivedLastValue, let value = upstream?.valueSnapshot else {
//        lock.unlock()
//        return
//      }
//
//      receivedLastValue = true
//
//      switch self.demand {
//      case .unlimited:
//        lock.unlock()
//        // NB: Adding to unlimited demand has no effect and can be ignored.
//        _ = downstream.receive(value)
//
//      default:
//        self.demand -= 1
//        lock.unlock()
//        let moreDemand = downstream.receive(value)
//        lock.lock()
//        self.demand += moreDemand
//        lock.unlock()
//      }
//    }
//
//    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
//      lhs === rhs
//    }
//
//    enum LifecycleStage {
//      case active
//      case terminal
//    }
//  }
//}
