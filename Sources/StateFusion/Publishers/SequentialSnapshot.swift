//
//  SequentialSnapshot.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.06.2026.
//

public struct SequentialSnapshot<T> {
  public let value: T
  
  /// A monotonically increasing identifier for this snapshot version.
  @inlinable @inline(always)
  public var version: some Comparable { _version }
  
  /// serial number
  @usableFromInline
  internal let _version: UInt32
  
  internal init(initial value: T) {
    self.value = value
    self._version = 0
  }

  internal init(value: T, version: UInt32) {
    self.value = value
    self._version = version
  }
}
