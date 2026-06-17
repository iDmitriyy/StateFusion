//
//  InfallibleValuePublisher.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 13.06.2026.
//

public import Combine

// InfallibleValuePublisher

/// A type-erasing publisher that represents a continuous state or value stream.
public final class InfallibleValuePublisher<Output>: Publisher {
  public typealias Failure = Never

  // public var valueSnapshot: Snapshot {}

  // public var value: Output {}

  /// private
  @usableFromInline
  /* private */ internal let _getValue: () -> Output

  /// private
  @usableFromInline
  /* private */ internal let _subscribeClosure: (AnySubscriber<Output, Never>) -> Void

  @inlinable
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P,
                              getCurrentValue: @escaping () -> Output)
    where P.Output == Output, P.Failure == Never {
    _subscribeClosure = { [base] subscriber in
      base.receive(subscriber: subscriber)
    }

    _getValue = getCurrentValue
  }

  @inlinable
  public final func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
    _subscribeClosure(AnySubscriber(subscriber))
  }
}

extension InfallibleValuePublisher {
  public convenience init(_ subject: CurrentValueSubject<Output, Never>) {
    self.init(retained_unverifiedValuePublisher: subject,
              getCurrentValue: { [unowned subject] in subject.value })
  }
}

extension InfallibleValuePublisher {
  @inlinable
  public final func takeUpdates(afterSnapshot snapshot: Snapshot) -> AnyPublisher<Output, Never> {
    _ = snapshot
    fatalError()
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - Snapshot

extension InfallibleValuePublisher {
  /// An opaque token representing an atomic state snapshot bundled with its chronological version.
  ///
  /// ### The Synchronization Problem
  /// A common synchronization bug occurs when establishing a reactive connection in two steps:
  /// 1. **Phase A (Synchronous):** You read the current state to bootstrap an object.
  /// 2. **Phase B (Asynchronous):** You attach a subscription to listen for future updates.
  ///
  /// Because a time gap exists between Phase A and Phase B, a concurrent thread can mutate the state
  /// right before the subscription is attached. A standard publisher will either deliver a duplicate
  /// old value (causing redundant processing) or drop the critical mid-gap update if you blindly apply `.dropFirst()`.
  ///
  /// ### Solution
  /// The `Snapshot` token tracks the exact timeline version of the state when it was read. Passing this
  /// token into ``CurrentValuePublisher/takeUpdates(afterSnapshot:)`` bridges the time gap safely:
  /// - If a concurrent mutation happened during the gap, the updated value is delivered immediately.
  /// - If no mutations occurred, the initial subscription emission is discarded silently to prevent duplicates.
  ///
  /// ### Example Usage
  ///
  /// ```swift
  /// final class DataConsumer {
  ///   private let engine: CoreEngine
  ///   private let bag = CancellationBag()
  ///
  ///   init(source: CurrentValuePublisher<Configuration>) {
  ///     // Phase A: Capture current state safely for synchronous bootstrap
  ///     let configSnapshot = source.snapshot
  ///     engine = CoreEngine(configuration: configSnapshot.value)
  ///
  ///     // Phase B: Pass the snapshot to guarantee data consistency across the gap
  ///     source.takeUpdates(afterSnapshot: configSnapshot)
  ///       .sink { [unowned self] updatedConfig in
  ///         self.engine.hotReload(updatedConfig)
  ///       }
  ///       .store(in: bag)
  ///   }
  /// }
  /// ```
  public typealias Snapshot = SequentialSnapshot<Output>
}

public struct SequentialSnapshot<T> {
  public let value: T
  
  /// A monotonically increasing identifier for this snapshot version.
  @inlinable @inline(always)
  public var version: some Comparable { _version }
  
  /// serial number
  @usableFromInline
  internal let _version: UInt64
  
  internal init(initial value: T) {
    self.value = value
    self._version = 0
  }

  internal init(value: T, serialNumber: UInt64) {
    self.value = value
    self._version = serialNumber
  }
}
