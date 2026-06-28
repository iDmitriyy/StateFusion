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
//  final var valueSnapshot: SequentialSnapshot<Value> {
//    _data.withLock {
//      SequentialSnapshot(value: $0.value, version: $0.version, sourceID: id)
//    }
//  }
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

// MARK: - Subscription

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
    private var upstream: InsulatedVersionedValueRelay? // TODO: weak?
    private var downstream: SubscriberVariant?
//    private var downstream: (any Subscriber<Output, Never>)?
    
    
    private var demand = Subscribers.Demand.none
    private var receivedLastValue = false
    
    private let lock: os_unfair_lock_t

    init(upstream: InsulatedVersionedValueRelay, downstream: any Subscriber<Output, Never>) {
      self.upstream = upstream
//      self.downstream = downstream
      self.downstream = .versionedValue(downstream)
      lock = os_unfair_lock_t.allocate(capacity: 1)
      lock.initialize(to: os_unfair_lock())
    }

    deinit {
      self.lock.deinitialize(count: 1)
      self.lock.deallocate()
    }
    // MARK: Cancellable Imp
    
    func cancel() {
      lock.sync {
        self.downstream = nil
        self.upstream?.remove(self)
        self.upstream = nil
      }
    }

    func receive(_ new: SequentialSnapshot<Value>) {
      lock.lock()

      guard let downstream else {
        lock.unlock()
        return
      }

      switch demand {
      case .unlimited:
        // NB: Adding to unlimited demand has no effect and can be ignored.
//        _ = downstream.receive(value)
        switch downstream {
        case let .value(downstream):
          lock.unlock() // FIXME: - eliminate lock.unlock() by using explicit LifecycleStage
          _ = downstream.receive(new.value)
          
        case let .valueTakeUpdatesAfter(snapshotVersion, snapshotSourceID, downstream):
          guard let upstream = upstream else {
            lock.unlock(); return
          }
          lock.unlock()
          // == drop(while: { $0._version <= snapshot.version })
          if upstream.id == snapshotSourceID, new._version <= snapshotVersion {
            return
          } else {
            // if new._version > snapshotVersion then send values
            // if sourceID is not valid, then do not drop value (pass all values)
            _ = downstream.receive(new.value)
          }
          
        case let .versionedValue(downstream):
          lock.unlock()
          let output = (value: new.value, version: new._version)
          _ = downstream.receive(output)
        case let .versionedValueSnapshot(downstream):
          lock.unlock()
          _ = downstream.receive(new)
        }

      case .none:
        receivedLastValue = false
        lock.unlock()

      default:
        receivedLastValue = true
        demand -= 1
        lock.unlock()
        switch downstream {
        case let .value(downstream):
          <#code#>
        case let .valueTakeUpdatesAfter(_, _, downstream):
          <#code#>
        case let .versionedValue(downstream):
          <#code#>
        case let .versionedValueSnapshot(downstream):
          <#code#>
        }
        
        let moreDemand = downstream.receive(new)
        lock.sync {
          self.demand += moreDemand
        }
      }
    }

    func request(_ demand: Subscribers.Demand) {
      precondition(demand > 0, "Demand must be greater than zero")

      lock.lock()

      guard let downstream else {
        lock.unlock()
        return
      }

      self.demand += demand

      guard !receivedLastValue, let value = upstream?.valueSnapshot else {
        lock.unlock()
        return
      }

      receivedLastValue = true

      switch self.demand {
      case .unlimited:
        lock.unlock()
        // NB: Adding to unlimited demand has no effect and can be ignored.
        _ = downstream.receive(value)

      default:
        self.demand -= 1
        lock.unlock()
        let moreDemand = downstream.receive(value)
        lock.lock()
        self.demand += moreDemand
        lock.unlock()
      }
    }
    
    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
      lhs === rhs
    }
    
    enum SubscriberVariant {
      case value(any Subscriber<Value, Never>)
      case valueTakeUpdatesAfter(referenceVersion: UInt32, sourceID: SourceID, any Subscriber<Value, Never>)
      case versionedValue(any Subscriber<Output, Never>)
      case versionedValueSnapshot(any Subscriber<SequentialSnapshot<Value>, Never>)
      
      func send(new: SequentialSnapshot<Value>, upstreamID: SourceID?) -> Subscribers.Demand {
        // FIXME: what does upstreamID == nil means? except it is an artifact.
        // nil value mean that upstream is as a resource was cleaned up, which means that cancellation happened
        switch self {
        case let .value(downstream):
          downstream.receive(new.value)
          
        case let .valueTakeUpdatesAfter(snapshotVersion, snapshotSourceID, downstream):
          // code below is analog of `drop(while: { $0._version <= snapshot.version })`
          if upstreamID == snapshotSourceID, new._version <= snapshotVersion {
            .none //
          } else {
            // if new._version > snapshotVersion then send values
            // if sourceID is not valid, then do not drop value (pass all values)
            downstream.receive(new.value)
          }
          
        case let .versionedValue(downstream):
          downstream.receive((value: new.value, version: new._version))
          
        case let .versionedValueSnapshot(downstream):
          downstream.receive(new)
        }
      }
    }
    
    enum LifecycleStage {
      case active
      case terminal
    }
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
