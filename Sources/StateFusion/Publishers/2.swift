//
//  2.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 27.06.2026.
//

//
//  InsulatedVersionedValueRelay2.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 27.06.2026.
//

public import Combine
import Foundation

//===-------------------------------------------------------------------------------------------------------------------===//
// MARK: - Insulated VersionedValue Relay

/// A thread-safe, infallible Relay that holds a current value and supports atomic read-modify-write.
///
/// Unlike `CurrentValueRelay`, this type:
/// - Supports atomic mutations via `withInoutAccess`
/// - Tracks every value change with a monotonically increasing serial number
/// - Automatically sends `.finished` upon deallocation, tearing down downstream pipelines
/// - Cannot be explicitly completed by the user
internal final class InsulatedVersionedValueRelay2<Value>: Publisher, Sendable {
  typealias Output = Value
  typealias Failure = Never

  private let _data: RecursiveLock<(value: Value, version: UInt32, subscriptions: ContiguousArray<Subscription>)>
  private let _id: SourceID = SourceID()

  init(_ value: Value) {
    _data = RecursiveLock(uncheckedState: (value: value, version: 0, subscriptions: ContiguousArray()))
  }

  deinit {
    // TBD
  }

  internal func terminateWithCompletion() {
    // send(completion: .finished)
  }

  // MARK: Publisher

  func receive(subscriber: some Subscriber<Value, Never>) {
    let subscription = Subscription(upstream: self, downstream: subscriber)
    _data.withLock {
      $0.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }

  // MARK: Send

  internal func send(newValue value: Value) {
    _data.withLock {
      $0.version &+= 1
      $0.value = value
      let version = $0.version
      for subscription in $0.subscriptions {
        subscription.receive(value, version)
      }
    }
  }

  internal final func withInoutAccess<R>(_ access: (inout Value) -> sending R)
    -> sending R {
      _data.withLock {
        $0.version &+= 1
        let result = access(&$0.value)
        let value = $0.value
        let version = $0.version
        for subscription in $0.subscriptions {
          subscription.receive(value, version)
        }
        return result
      }
    }

  // MARK: Internal

  fileprivate func remove(_ subscription: Subscription) {
    _data.withLock {
      guard let index = $0.subscriptions.firstIndex(of: subscription) else { return }
      $0.subscriptions.remove(at: index)
    }
  }

  internal func receiveVersioned(subscriber: some Subscriber<(value: Value, version: UInt32), Never>) {
    let subscription = Subscription(upstream: self, versionedDownstream: subscriber)
    _data.withLock {
      $0.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }

  internal func receiveTakeUpdates(subscriber: some Subscriber<Value, Never>, snapshot: SequentialSnapshot<Value>) {
    let subscription = Subscription(upstream: self, takeUpdatesDownstream: subscriber, snapshot: snapshot)
    _data.withLock {
      $0.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }
}

// MARK: - Sync Access

extension InsulatedVersionedValueRelay2 {
  internal var value: Value {
    _data.withLockUncheckedSending { $0.value }
  }

  internal var _currentVersion: UInt32 {
    _data.withLockUncheckedSending { $0.version }
  }
}

extension InsulatedVersionedValueRelay2 {
  final var valueSnapshot: SequentialSnapshot<Value> {
    _data.withLockUncheckedSending {
      SequentialSnapshot(value: $0.value, version: $0.version, sourceID: _id)
    }
  }
}

// MARK: - Versioned Access

extension InsulatedVersionedValueRelay2 where Value: Sendable {
  final func takeUpdates(afterSnapshot snapshot: SequentialSnapshot<Value>) -> some Publisher<Value, Never> {
    TakeUpdatesPublisher(relay: self, snapshot: snapshot)
    // FIXME: + share
  }

  final func versionedValuePublisher() -> VersionedSnapshotView<Value> {
    VersionedSnapshotView(relay: self)
  }
}

// MARK: - TakeUpdatesPublisher

private struct TakeUpdatesPublisher<Value>: Publisher where Value: Sendable {
  typealias Output = Value
  typealias Failure = Never

  private let relay: InsulatedVersionedValueRelay2<Value>
  private let snapshot: SequentialSnapshot<Value>

  init(relay: InsulatedVersionedValueRelay2<Value>, snapshot: SequentialSnapshot<Value>) {
    self.relay = relay
    self.snapshot = snapshot
  }

  func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
    relay.receiveTakeUpdates(subscriber: subscriber, snapshot: snapshot)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//
// MARK: - VersionedSnapshotView (~Copyable wrapper)

/// A thin wrapper that retains the relay and exposes a versioned publisher interface.
/// Use `versionedValuePublisher()` on `InsulatedVersionedValueRelay2` to obtain one.
struct VersionedSnapshotView<Value>: Sendable {
  private let relay: InsulatedVersionedValueRelay2<Value>

  fileprivate init(relay: InsulatedVersionedValueRelay2<Value>) {
    self.relay = relay
  }
}

extension VersionedSnapshotView: Publisher {
  typealias Output = (value: Value, version: UInt32)
  typealias Failure = Never

  func receive<S>(subscriber: S) where S: Subscriber, S.Input == Output, S.Failure == Never {
    relay.receiveVersioned(subscriber: subscriber)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//
// MARK: - Subscription

extension InsulatedVersionedValueRelay2 {
  fileprivate final class Subscription: Combine.Subscription, Equatable {
    private enum Kind {
      case value
      case versioned
      case takeUpdates(referenceVersion: UInt32, sourceID: SourceID)
    }

    private let kind: Kind
    private var demand = Subscribers.Demand.none
    private var receivedLastValue = false
    private var downstreamValue: (any Subscriber<Value, Never>)?
    private var downstreamVersioned: (any Subscriber<(value: Value, version: UInt32), Never>)?
    private weak var upstream: InsulatedVersionedValueRelay2?

    private let lock: os_unfair_lock_t

    // MARK: - Init (Value)

    init(upstream: InsulatedVersionedValueRelay2, downstream: any Subscriber<Value, Never>) {
      kind = .value
      self.upstream = upstream
      downstreamValue = downstream
      lock = os_unfair_lock_t.allocate(capacity: 1)
      lock.initialize(to: os_unfair_lock())
    }

    // MARK: - Init (Versioned)

    init(upstream: InsulatedVersionedValueRelay2, versionedDownstream: any Subscriber<(value: Value, version: UInt32), Never>) {
      kind = .versioned
      self.upstream = upstream
      downstreamVersioned = versionedDownstream
      lock = os_unfair_lock_t.allocate(capacity: 1)
      lock.initialize(to: os_unfair_lock())
    }

    // MARK: - Init (TakeUpdates)

    init(upstream: InsulatedVersionedValueRelay2, takeUpdatesDownstream: any Subscriber<Value, Never>, snapshot: SequentialSnapshot<Value>) {
      kind = .takeUpdates(referenceVersion: snapshot._version, sourceID: snapshot._sourceID)
      self.upstream = upstream
      downstreamValue = takeUpdatesDownstream
      lock = os_unfair_lock_t.allocate(capacity: 1)
      lock.initialize(to: os_unfair_lock())
    }

    deinit {
      self.lock.deinitialize(count: 1)
      self.lock.deallocate()
    }

    // MARK: - Receive

    func receive(_ value: Value, _ version: UInt32) {
      lock.lock()

      switch kind {
      case .value:
        guard let downstream = downstreamValue else {
          lock.unlock()
          return
        }
        switch demand {
        case .unlimited:
          lock.unlock()
          // NB: Adding to unlimited demand has no effect and can be ignored.
          _ = downstream.receive(value)

        case .none:
          receivedLastValue = false
          lock.unlock()

        default:
          receivedLastValue = true
          demand -= 1
          lock.unlock()
          let moreDemand = downstream.receive(value)
          lock.sync {
            self.demand += moreDemand
          }
        }

      case .versioned:
        guard let downstream = downstreamVersioned else {
          lock.unlock()
          return
        }
        let output = (value: value, version: version)
        switch demand {
        case .unlimited:
          lock.unlock()
          // NB: Adding to unlimited demand has no effect and can be ignored.
          _ = downstream.receive(output)

        case .none:
          receivedLastValue = false
          lock.unlock()

        default:
          receivedLastValue = true
          demand -= 1
          lock.unlock()
          let moreDemand = downstream.receive(output)
          lock.sync {
            self.demand += moreDemand
          }
        }

      case .takeUpdates(let referenceVersion, let sourceID):
        guard upstream?._id == sourceID else {
          lock.unlock()
          return
        }
        guard version > referenceVersion else {
          lock.unlock()
          return
        }
        guard let downstream = downstreamValue else {
          lock.unlock()
          return
        }
        switch demand {
        case .unlimited:
          lock.unlock()
          // NB: Adding to unlimited demand has no effect and can be ignored.
          _ = downstream.receive(value)

        case .none:
          receivedLastValue = false
          lock.unlock()

        default:
          receivedLastValue = true
          demand -= 1
          lock.unlock()
          let moreDemand = downstream.receive(value)
          lock.sync {
            self.demand += moreDemand
          }
        }
      }
    }

    // MARK: - Request

    func request(_ demand: Subscribers.Demand) {
      precondition(demand > 0, "Demand must be greater than zero")

      lock.lock()

      guard let upstream else {
        lock.unlock()
        return
      }

      self.demand += demand

      guard !receivedLastValue else {
        lock.unlock()
        return
      }

      receivedLastValue = true

      let snapshot = upstream.valueSnapshot

      switch kind {
      case .value:
        guard let downstream = downstreamValue else {
          lock.unlock()
          return
        }
        switch self.demand {
        case .unlimited:
          lock.unlock()
          // NB: Adding to unlimited demand has no effect and can be ignored.
          _ = downstream.receive(snapshot.value)

        default:
          self.demand -= 1
          lock.unlock()
          let moreDemand = downstream.receive(snapshot.value)
          lock.lock()
          self.demand += moreDemand
          lock.unlock()
        }

      case .versioned:
        guard let downstream = downstreamVersioned else {
          lock.unlock()
          return
        }
        let output = (value: snapshot.value, version: snapshot._version)
        switch self.demand {
        case .unlimited:
          lock.unlock()
          // NB: Adding to unlimited demand has no effect and can be ignored.
          _ = downstream.receive(output)

        default:
          self.demand -= 1
          lock.unlock()
          let moreDemand = downstream.receive(output)
          lock.lock()
          self.demand += moreDemand
          lock.unlock()
        }

      case .takeUpdates(let referenceVersion, let sourceID):
        guard snapshot._sourceID == sourceID else {
          lock.unlock()
          return
        }
        guard snapshot._version > referenceVersion else {
          lock.unlock()
          return
        }
        guard let downstream = downstreamValue else {
          lock.unlock()
          return
        }
        switch self.demand {
        case .unlimited:
          lock.unlock()
          // NB: Adding to unlimited demand has no effect and can be ignored.
          _ = downstream.receive(snapshot.value)

        default:
          self.demand -= 1
          lock.unlock()
          let moreDemand = downstream.receive(snapshot.value)
          lock.lock()
          self.demand += moreDemand
          lock.unlock()
        }
      }
    }

    // MARK: - Cancel

    func cancel() {
      lock.sync {
        switch kind {
        case .value, .takeUpdates:
          self.downstreamValue = nil
        case .versioned:
          self.downstreamVersioned = nil
        }
        self.upstream?.remove(self)
        self.upstream = nil
      }
    }

    // MARK: - Equatable

    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
      lhs === rhs
    }
  }
}
