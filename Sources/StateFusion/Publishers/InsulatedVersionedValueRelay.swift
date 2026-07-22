//
//  InsulatedVersionedValueRelay.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 27.06.2026.
//

public import Combine
import Foundation
import Synchronization

// MARK: - Insulated VersionedValue Relay

/// A thread-safe relay that holds a versioned value and publishes updates to subscribers.
///
/// Each mutation increments a version number,
/// allowing subscribers to detect missed updates.
///
/// The relay maintains internal synchronization using a `RecursiveLock`, ensuring that
/// concurrent reads and writes are safe. Subscribers receive values in the order they
/// were published, and each value is paired with a monotonically increasing version number
/// to enable gap detection.
///
/// ### Usage
///
/// ```swift
/// let relay = InsulatedVersionedValueRelay(42)
///
/// // Subscribe to value changes
/// relay.asValuePublisher()
///   .sink { value in
///     print("Received: \(value)")
///   }
///
/// // Update the value
/// relay.send(nextValue: 100)
/// ```
public final class InsulatedVersionedValueRelay<Value>: Publisher {
  public typealias Output = Value
  public typealias Failure = Never

  private let _properties: RecursiveLock<(value: Value, version: UInt32, subscriptions: ContiguousArray<SubscriptionImp>)>
  internal let id: SourceID = SourceID()

  internal init(_ value: Value) {
    _properties = RecursiveLock(uncheckedState: (value: value, version: 0, subscriptions: ContiguousArray()))
  }
  
  @_spi(PerformanceMeasuring)
  public init(_value: Value) {
    _properties = RecursiveLock(uncheckedState: (value: _value, version: 0, subscriptions: ContiguousArray()))
  }

  deinit {
    // TODO: TBD — send .finished to all active subscriptions
  }

  // MARK: - Publisher Protocol Imp

  public func receive(subscriber: some Subscriber<Output, Never>) {
    let subscription = SubscriptionImp(upstream: self, downstream: .value(subscriber))
    _properties.withLock {
      $0.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }

  internal func receive(subscriberVariant: SubscriberVariant) {
    let subscription = SubscriptionImp(upstream: self, downstream: subscriberVariant)
    _properties.withLock {
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

  // MARK: - Private Imp

  fileprivate func remove(_ subscription: SubscriptionImp) {
    _properties.withLock {
      guard let index = $0.subscriptions.firstIndex(of: subscription) else { return }
      $0.subscriptions.remove(at: index)
    }
  }
}

extension InsulatedVersionedValueRelay: Sendable where Value: Sendable {}

// MARK: - Sync Access

extension InsulatedVersionedValueRelay { // where Value: ~Sendable
  fileprivate final var uncheckedSendable_valueSnapshot: SequentialSnapshot<Value> {
    _properties.withLockUncheckedSending {
      SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
    }
  }

  public func send(nextValue value: Value) {
    _properties.withLock {
      $0.version += 1
      $0.value = value
      
      if !$0.subscriptions.isEmpty {
        let snapshot = SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
        for subscription in $0.subscriptions {
          subscription.receive(snapshot)
        }
      }
    }
  }

  public final func withLockAlwaysEmittingMutableAccess<R>(_ access: (inout Value) -> sending R)
    -> sending R {
    _properties.withLock {
      $0.version += 1
      let result = access(&$0.value)
      
      if !$0.subscriptions.isEmpty {
        let snapshot = SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
        for subscription in $0.subscriptions {
          subscription.receive(snapshot)
        }
      }
      
      return result
    }
  }
}

extension InsulatedVersionedValueRelay where Value: Sendable {
  internal final var valueSnapshot: SequentialSnapshot<Value> {
    _properties.withLock {
      SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
    }
  }

  public final func withLockEmittingOnMutableAccess<R: Sendable, E: Error>(
    _ access: (inout GenericStateAccessHandle<Value>) throws(E) -> R,
  ) throws(E) -> R {
    try _properties.withLock { properties throws(E) -> R in
      var accessHandle = GenericStateAccessHandle(mutableRef: _MutableRef(&properties.value))
      let result = try access(&accessHandle)

      if accessHandle._isMutablyAccessed, !properties.subscriptions.isEmpty {
        let snapshot = SequentialSnapshot(value: properties.value, version: properties.version, sourceID: id)
        for subscription in properties.subscriptions {
          subscription.receive(snapshot)
        }
      }

      return result
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
  internal enum SubscriberVariant {
    case value(any Subscriber<Value, Never>)
    case valueTakeUpdatesAfter(referenceVersion: UInt32, sourceID: SourceID, any Subscriber<Value, Never>)
    case versionedValue(any Subscriber<(value: Value, version: UInt32), Never>)
    case versionedValueSnapshot(any Subscriber<SequentialSnapshot<Value>, Never>)

    fileprivate func receive(_ new: SequentialSnapshot<Value>, upstreamID: SourceID) -> Subscribers.Demand {
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
