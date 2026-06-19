//
//  SequentialSnapshot.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.06.2026.
//

import Combine

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
  internal let ownerID: CombineIdentifier

//  internal init(initial value: T) {
//    self.value = value
//    _version = 0
//  }

  internal init(value: T, version: UInt32) {
    self.value = value
    _version = version
  }
}

public struct UniqueSequentialSnapshot<T>: ~Copyable {
  // TODO: add some ID/sourceIdentity to check that snapshot was consumed by the same Subject/Relay that produced it.
  public let value: T

  /// A monotonically increasing identifier for this snapshot version.
  @inlinable @inline(always)
  public var version: some Comparable {
    _version
  }

  /// serial number
  @usableFromInline
  internal let _version: UInt32

  internal init(initial value: T) {
    self.value = value
    _version = 0
  }

  internal init(value: T, version: UInt32) {
    self.value = value
    _version = version
  }
}

import Synchronization

public struct ResourceID: Sendable {
  // Размещаем атомик внутри Sendable класса
  // Начинаем с 0 или 1

  private let rawValue: Int

  public init() {
    let currentID = Self.currentID.wrappingAdd(1, ordering: .relaxed).oldValue
    rawValue = currentID
  }

  private static let currentID = Atomic<Int>(0)
}
