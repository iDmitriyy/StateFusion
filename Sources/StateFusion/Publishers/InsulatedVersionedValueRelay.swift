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

  internal func terminateWithCompletion() {
    // send(completion: .finished)
  }

  func receive(subscriber: some Subscriber<Output, Never>) {
    let subscription = Subscription(upstream: self, downstream: subscriber)
    _data.withLock {
      $0.subscriptions.append(subscription)
    }
    subscriber.receive(subscription: subscription)
  }

  internal func send(newValue value: Value) {
    _data.withLock {
      $0.version += 1
      $0.value = value

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

  private func remove(_ subscription: Subscription) {
    _data.withLock {
      guard let index = $0.subscriptions.firstIndex(of: subscription) else { return }
      $0.subscriptions.remove(at: index)
    }
  }
}

extension InsulatedVersionedValueRelay {
  private var _uncheckedOutputSnapshot: Output {
    _data.withLockUncheckedSending {
      (value: $0.value, version: $0.version)
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

import Foundation

extension InsulatedVersionedValueRelay {
  fileprivate final class Subscription: Combine.Subscription, Equatable {
    private var demand = Subscribers.Demand.none
    private var downstream: (any Subscriber<Output, Never>)?
    private var receivedLastValue = false
    private var upstream: InsulatedVersionedValueRelay?
    
    private let lock: os_unfair_lock_t

    init(upstream: InsulatedVersionedValueRelay, downstream: any Subscriber<Output, Never>) {
      self.upstream = upstream
      self.downstream = downstream
      lock = os_unfair_lock_t.allocate(capacity: 1)
      lock.initialize(to: os_unfair_lock())
    }

    deinit {
      self.lock.deinitialize(count: 1)
      self.lock.deallocate()
    }

    func cancel() {
      lock.sync {
        self.downstream = nil
        self.upstream?.remove(self)
        self.upstream = nil
      }
    }

    func receive(_ value: SequentialSnapshot<Value>) {
      lock.lock()

      guard let downstream else {
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
