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

/// A thread-safe relay that holds a versioned value and publishes updates to subscribers.
///
/// `InsulatedVersionedValueRelay` provides a thread-safe container for a single value
/// that can be observed by multiple subscribers. Each mutation increments a version number,
/// allowing subscribers to detect and skip missed updates.
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
extension InsulatedVersionedValueRelay {
  /// Creates a publisher that emits the current and future values.
  ///
  /// The returned publisher emits only the value component of each update,
  /// discarding version information. This is useful when you only need
  /// to observe value changes without version tracking.
  ///
  /// - Returns: A publisher that emits `Value` instances.
  internal final func asValuePublisher() -> InfallibleValuePublisher<Value> {
    let adapter = ValueRelayAdapter<Value>(_subscribeClosure: { [self] subscriber in
      receive(subscriberVariant: .value(subscriber))
    })

    return InfallibleValuePublisher(retained_unverifiedValuePublisher: adapter,
                                    getCurrentValue: { [unowned self] in
                                      _properties.withLockUncheckedSending { $0.value }
                                    })
  }

  /// Creates a publisher that emits the current and future values with version information.
  ///
  /// The returned publisher emits tuples containing both the value and its version number.
  /// This is useful when you need to track the order of mutations or detect missed updates.
  ///
  /// - Returns: A publisher that emits `(value: Value, version: UInt32)` tuples.
  internal final func asVersionedValuePublisher() -> InfallibleValuePublisher<(value: Value, version: UInt32)> {
    let adapter = ValueRelayAdapter<(value: Value, version: UInt32)>(_subscribeClosure: { [self] subscriber in
      receive(subscriberVariant: .versionedValue(subscriber))
    })

    return InfallibleValuePublisher(retained_unverifiedValuePublisher: adapter,
                                    getCurrentValue: { [unowned self] in
                                      _properties.withLockUncheckedSending { ($0.value, $0.version) }
                                    })
  }

  /// Creates a publisher that emits the current and future values as snapshots.
  ///
  /// The returned publisher emits `SequentialSnapshot` instances, which include
  /// the value, version, and source identity. This is useful for establishing
  /// synchronized connections where you need to capture the current state
  /// and then receive only subsequent updates.
  ///
  /// - Returns: A publisher that emits `SequentialSnapshot<Value>` instances.
  internal final func asSnapshotPublisher() -> InfallibleValuePublisher<SequentialSnapshot<Value>> {
    let adapter = ValueRelayAdapter<SequentialSnapshot<Value>>(_subscribeClosure: { [self] subscriber in
      receive(subscriberVariant: .versionedValueSnapshot(subscriber))
    })

    return InfallibleValuePublisher(retained_unverifiedValuePublisher: adapter,
                                    getCurrentValue: { [unowned self] in
                                      uncheckedSendable_valueSnapshot
                                    })
  }
}

// MARK: - Take Updates

extension InsulatedVersionedValueRelay {
  /// Creates a publisher that emits values after the specified snapshot.
  ///
  /// Use this method to bridge the synchronization gap between reading the current
  /// state and subscribing to future updates. If a mutation occurred between the
  /// snapshot capture and subscription, the updated value is delivered immediately.
  ///
  /// - Parameter snapshot: The snapshot to use as a reference point.
  /// - Returns: A publisher that emits values after the snapshot's version.
  internal final func takeUpdates(afterSnapshot snapshot: SequentialSnapshot<Value>) -> some InfalliblePublisher<Value> { // TODO: InfalliblePublisher
    ValueRelayAdapter(_subscribeClosure: { [self] subscriber in
      receive(subscriberVariant: .valueTakeUpdatesAfter(referenceVersion: snapshot._version,
                                                        sourceID: snapshot._sourceID,
                                                        subscriber))
    })
  }

  /// Creates a publisher that drops values until the snapshot's version is exceeded.
  ///
  /// This is an older implementation that uses `drop(while:)` to filter values.
  /// It logs a warning if the snapshot's source ID does not match this relay's ID.
  ///
  /// - Parameter snapshot: The snapshot to use as a reference point.
  /// - Returns: A publisher that emits values after the snapshot's version.
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

  // TODO: use SubscribeClosure struct to pass subscriber as generic params and eliminate existential unboxing
  let _subscribeClosure: (any Subscriber<Output, Failure>) -> Void

  func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _subscribeClosure(subscriber)
  }
}

fileprivate struct SubscribeClosure<Output, Failure: Error> { // FIXME: - TBD
  func callAsFunction(_ subscriber: some Subscriber<Output, Failure>) {
    _ = subscriber
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - Insulated VersionedValue Relay

internal final class InsulatedVersionedValueRelay<Value>: Publisher, Sendable {
  typealias Output = (value: Value, version: UInt32)
  typealias Failure = Never

  private let _properties: RecursiveLock<(value: Value, version: UInt32, subscriptions: ContiguousArray<SubscriptionImp>)>
  private let id: SourceID = SourceID()

  init(_ value: Value) {
    _properties = RecursiveLock(uncheckedState: (value: value, version: 0, subscriptions: ContiguousArray()))
  }

  deinit {
    // TODO: TBD — send .finished to all active subscriptions
  }

  // MARK: - Publisher Protocol Imp

  func receive(subscriber: some Subscriber<Output, Never>) {
    let subscription = SubscriptionImp(upstream: self, downstream: .versionedValue(subscriber))
    _properties.withLock {
      $0.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }

  private func receive(subscriberVariant: SubscriberVariant) {
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

// MARK: - Sync Access

extension InsulatedVersionedValueRelay { // where Value: ~Sendable
  fileprivate final var uncheckedSendable_valueSnapshot: SequentialSnapshot<Value> {
    _properties.withLockUncheckedSending {
      SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
    }
  }

  internal func send(nextValue value: Value) {
    _properties.withLock {
      $0.version += 1
      $0.value = value
      // !!!
      let snapshot = SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
      for subscription in $0.subscriptions {
        subscription.receive(snapshot)
      }
    }
  }

  internal final func withLockAlwaysEmittingMutableAccess<R>(_ access: (inout Value) -> sending R)
    -> sending R {
    _properties.withLock {
      $0.version += 1
      let result = access(&$0.value)
      let snapshot = SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
      for subscription in $0.subscriptions {
        subscription.receive(snapshot)
      }
      return result
    }
  }
}

extension InsulatedVersionedValueRelay where Value: Sendable {
  final var valueSnapshot: SequentialSnapshot<Value> {
    _properties.withLock {
      SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
    }
  }

  internal final func withLockEmittingOnMutableAccess<R: Sendable, E: Error>(
    _ access: (inout GenericStateAccessHandle<Value>) throws(E) -> R,
  ) throws(E) -> R {
    try _properties.withLock { properties throws(E) -> R in
      var accessHandle = GenericStateAccessHandle(mutableRef: _MutableRef(&properties.value))
      let result = try access(&accessHandle)

      if accessHandle._isMutablyAccessed {
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
