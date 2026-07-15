//
//  InsulatedVersionedValueRelay.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 27.06.2026.
//

public import Combine
import Foundation
import Synchronization

// MARK: - As Publisher (read-only interface)

extension InsulatedVersionedValueRelay {
  internal final func asValuePublisher() -> InfallibleValuePublisher<Value> {
    InfallibleValuePublisher<Value>(subscribe: { [self] subscriber in
      self.receive(subscriberVariant: .value(subscriber))
    }, getCurrentValue: { [unowned self] in
      self._dataState.withLockUncheckedSending { $0.value }
    })
  }
  
  internal final func asVersionedValuePublisher() -> InfallibleValuePublisher<(value: Value, version: UInt32)> {
    InfallibleValuePublisher<Output>(subscribe: { [self] subscriber in
      self.receive(subscriberVariant: .versionedValue(subscriber))
    }, getCurrentValue: {
      self._dataState.withLockUncheckedSending { ($0.value, $0.version) }
    })
  }
  
  internal final func asSnapshotPublisher() -> InfallibleValuePublisher<SequentialSnapshot<Value>> {
    InfallibleValuePublisher(subscribe: { [self] subscriber in
      self.receive(subscriberVariant: .versionedValueSnapshot(subscriber))
    }, getCurrentValue: { [unowned self] in
      self.uncheckedSendable_valueSnapshot
    })
  }
}

// MARK: - Take Updates

extension InsulatedVersionedValueRelay {
  internal final func takeUpdates(afterSnapshot snapshot: SequentialSnapshot<Value>) -> some InfalliblePublisher<Value> { // TODO: InfalliblePublisher
    ValueRelayAdapter(_subscribeClosure: { [self] subscriber in
      self.receive(subscriberVariant: .valueTakeUpdatesAfter(referenceVersion: snapshot._version,
                                                             sourceID: snapshot._sourceID,
                                                             subscriber))
    })
  }
  
  internal final func takeUpdates_old(afterSnapshot snapshot: SequentialSnapshot<Value>) -> some Publisher<Value, Never> {
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

fileprivate struct ValueRelayAdapter<Output>: Publisher {
  typealias Failure = Never
  
  internal let _subscribeClosure: (any Subscriber<Output, Never>) -> Void
  
  func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _subscribeClosure(subscriber)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//
// MARK: - Insulated VersionedValue Relay

internal final class InsulatedVersionedValueRelay<Value>: Publisher, Sendable {
  typealias Output = (value: Value, version: UInt32)
  typealias Failure = Never

  private let _dataState: RecursiveLock<(value: Value, version: UInt32, subscriptions: ContiguousArray<SubscriptionImp>)>
  private let id: SourceID = SourceID()

  init(_ value: Value) {
    _dataState = RecursiveLock(uncheckedState: (value: value, version: 0, subscriptions: ContiguousArray()))
  }

  deinit {
    // TODO: TBD — send .finished to all active subscriptions
  }

  // MARK: - Publisher Protocol Imp

  func receive(subscriber: some Subscriber<Output, Never>) {
    let subscription = SubscriptionImp(upstream: self, downstream: .versionedValue(subscriber))
    _dataState.withLock {
      $0.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }

  private func receive(subscriberVariant: SubscriberVariant) {
    let subscription = SubscriptionImp(upstream: self, downstream: subscriberVariant)
    _dataState.withLock {
      $0.subscriptions.append(subscription)
    }
    
    switch subscriberVariant {
    case let .value(subscriber):
      subscriber.receive(subscription: subscription)
    case let .valueTakeUpdatesAfter(_, _, subscriber):
      subscriber.receive(subscription: subscription)
    case let .versionedValue(subscriber):
      subscriber.receive(subscription: subscription)
    case let .versionedValueSnapshot(subscriber):
      subscriber.receive(subscription: subscription)
    }
  }
  
  // MARK: - Relay Specific

  internal func internal_terminateWithCompletion() {
    // send(completion: .finished)
  }

  internal func send(nextValue value: Value) {
    _dataState.withLock {
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
    _dataState.withLock {
      $0.version += 1
      let result = access(&$0.value)
      let snapshot = SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
      for subscription in $0.subscriptions {
        subscription.receive(snapshot)
      }
      return result
    }
  }
  
  // internal final func withMutationTrackingAccess<R>(_ access: (inout Value) -> sending R)
  // -> sending R {
  //
  // }

  // MARK: - Private Imp

  fileprivate func remove(_ subscription: SubscriptionImp) {
    _dataState.withLock {
      guard let index = $0.subscriptions.firstIndex(of: subscription) else { return }
      $0.subscriptions.remove(at: index)
    }
  }
}

// MARK: - Sync Access

extension InsulatedVersionedValueRelay {
  fileprivate final var uncheckedSendable_valueSnapshot: SequentialSnapshot<Value> {
    _dataState.withLockUncheckedSending {
      SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
    }
  }
}

extension InsulatedVersionedValueRelay where Value: Sendable {
  final var valueSnapshot: SequentialSnapshot<Value> {
    _dataState.withLock {
      SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
    }
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//
// MARK: - Subscription

extension InsulatedVersionedValueRelay {
  fileprivate final class SubscriptionImp: Combine.Subscription, Equatable {
    private var lifecycleStage: LifecycleStage

    private let lock: os_unfair_lock_t
    /// Protects downstream delivery from reentrant sends (same pattern as OpenCombine's `downstreamLock`).
    private let downstreamLock: os_unfair_lock_t

    // MARK: - Init

    init(upstream: InsulatedVersionedValueRelay, downstream: SubscriberVariant) {
      lifecycleStage = .active(ActiveState(upstream: upstream, downstream: downstream))
      lock = os_unfair_lock_t.allocate(capacity: 1)
      lock.initialize(to: os_unfair_lock())
      downstreamLock = os_unfair_lock_t.allocate(capacity: 1)
      downstreamLock.initialize(to: os_unfair_lock())
    }

    deinit {
      lock.deinitialize(count: 1)
      lock.deallocate()
      downstreamLock.deinitialize(count: 1)
      downstreamLock.deallocate()
    }

    func receive(_ new: SequentialSnapshot<Value>) {
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
        downstreamLock.lock()
        _ = downstream.receive(new, upstreamID: upstreamID)
        downstreamLock.unlock()

      case .none:
        // FIXME: fixed — reset receivedLastValue so next request() delivers the current value.
        activeState.receivedLastValue = false
        lock.unlock()

      default:
        activeState.receivedLastValue = true
        activeState.demand -= 1
        lock.unlock()
        // FIXME: fixed — downstream delivery under downstreamLock, then update demand under lock.
        downstreamLock.lock()
        let moreDemand = downstream.receive(new, upstreamID: upstreamID)
        downstreamLock.unlock()
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
        lifecycleStage = .terminal // downstream, upstream, demand, receivedLastValue are freed
      }
    }

    func request(_ demand: Subscribers.Demand) {
      // FIXME: fixed — use assertNonZero() pattern like OpenCombine
      precondition(demand > 0, "Demand must be greater than zero")

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

      // Capture what we need, then release lock before reading snapshot.
      // This avoids the lock ordering issue: os_unfair_lock → _data.lock
      // (send holds _data.lock → os_unfair_lock via subscription.receive).
      let downstream = activeState.downstream

      lock.unlock()

      // Read snapshot WITHOUT holding os_unfair_lock (safe: _data.lock is separate).
      let snapshot = activeState.upstream.uncheckedSendable_valueSnapshot
      let upstreamID = activeState.upstream.id

      lock.lock()

      // Re-check: cancel() may have been called while we released the lock.
      guard case .active = lifecycleStage else {
        lock.unlock()
        return
      }

      switch activeState.demand {
      case .unlimited:
        lock.unlock()
        // NB: Adding to unlimited demand has no effect and can be ignored.
        downstreamLock.lock()
        _ = downstream.receive(snapshot, upstreamID: upstreamID)
        downstreamLock.unlock()

      default:
        activeState.demand -= 1
        lock.unlock()
        downstreamLock.lock()
        let moreDemand = downstream.receive(snapshot, upstreamID: upstreamID)
        downstreamLock.unlock()
        lock.sync {
          activeState.demand += moreDemand
        }
      }
    }

    // MARK: Equatable

    static func == (lhs: SubscriptionImp, rhs: SubscriptionImp) -> Bool {
      lhs === rhs
    }

    // MARK: Nested Types

    private enum LifecycleStage {
      case active(ActiveState)
      case terminal
    }

    /// Reference-type state blob so mutations are in-place (no write-back to `stage`).
    /// Only accessed under `lock`.
    final class ActiveState { // FIXME: - make a struct | is it used correctly under the lock
      let upstream: InsulatedVersionedValueRelay
      var downstream: SubscriberVariant
      var demand: Subscribers.Demand
      var receivedLastValue: Bool

      init(upstream: InsulatedVersionedValueRelay, downstream: SubscriberVariant) {
        self.upstream = upstream
        self.downstream = downstream
        demand = .none
        receivedLastValue = false
      }
    }
  }
}

extension InsulatedVersionedValueRelay {
  fileprivate enum SubscriberVariant {
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
        // FIXME: fixed — correct to return .none for dropped values. Caller does not
        // decrement demand for dropped values (demand is only decremented in `receive`
        // AFTER the `downstream.receive` call returns a non-zero demand).
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

  #if DEBUG
    private func assertOwner() {
      // FIXME: fixed — assertOwner pattern from OpenCombine.
      // os_unfair_lock does not track the owning thread, so a full assertion
      // requires switching to a lock that does (like OpenCombine's UnfairLock
      // which stores the owning pthread_t). This is a placeholder for that integration.
    }
  #endif
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
