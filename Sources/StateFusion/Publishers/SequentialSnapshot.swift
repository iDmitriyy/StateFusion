//
//  SequentialSnapshot.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.06.2026.
//

import Combine

/// An immutable snapshot of atomically-captured state paired with a monotonically increasing version number.
/// The version is a serial number that tracks the order of mutations.
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
public struct SequentialSnapshot<T> {
  public let value: T

  /// A monotonically increasing identifier for this snapshot version.
  @inlinable @inline(always)
  public var version: some Comparable {
    _version
  }

  /// serial number
  @usableFromInline
  internal let _version: UInt32
  
  /// ID/sourceIdentity to check that snapshot was consumed by the same Subject/Relay that produced it.
  internal let _sourceID: SourceID

//  internal init(initial value: T) {
//    self.value = value
//    _version = 0
//  }

  internal init(value: T, version: UInt32, sourceID: SourceID) {
    self.value = value
    _version = version
    _sourceID = sourceID
  }
  
  @_spi(PerformanceMeasuring)
  public init(_value value: T, _version version: UInt32, _sourceID sourceID: SourceID) {
    self.value = value
    _version = version
    _sourceID = sourceID
  }
}

extension SequentialSnapshot: Sendable where T: Sendable {}

import Synchronization

public struct SourceID: Sendable, Equatable {
  private let rawValue: UInt

  public init() {
    let currentID = SourceID.currentID.wrappingAdd(1, ordering: .relaxed).oldValue
    rawValue = currentID
  }

  private static let currentID = Atomic<UInt>(0)
}

// TODO: - is UInt32 reasonable
