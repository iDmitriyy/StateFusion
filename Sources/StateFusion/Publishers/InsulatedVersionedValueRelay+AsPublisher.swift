//
//  InsulatedVersionedValueRelay+AsPublisher.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 22.07.2026.
//

import Combine

// MARK: - As Publisher (read-only interface)

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

    return InfallibleValuePublisher(retained_unverifiedValuePublisher: adapter)
//    getCurrentValue: { [unowned self] in
//      _properties.withLockUncheckedSending { $0.value }
//    }
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

    return InfallibleValuePublisher(retained_unverifiedValuePublisher: adapter)
//    getCurrentValue: { [unowned self] in
//      _properties.withLockUncheckedSending { ($0.value, $0.version) }
//    }
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

    return InfallibleValuePublisher(retained_unverifiedValuePublisher: adapter)
//    getCurrentValue: { [unowned self] in
//      uncheckedSendable_valueSnapshot
//    }
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
