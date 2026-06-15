//
//  RecursiveLock.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 15.06.2026.
//

import class Foundation.NSRecursiveLock
import Synchronization

// MARK: - RecursiveLock

@_staticExclusiveOnly
internal struct RecursiveLock<Value: ~Copyable>: ~Copyable {
  private let _lock = NSRecursiveLock()

  private let value: _Cell<Value>
  
  public init(_ initialValue: consuming sending Value) {
    value = _Cell(initialValue)
  }
}

extension RecursiveLock: @unchecked Sendable where Value: ~Copyable {}

extension RecursiveLock where Value: ~Copyable {
  internal borrowing func withLock<Result: ~Copyable, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending Result,
  ) throws(E) -> sending Result {
    _lock.lock(); defer { _lock.unlock() }

    return try unsafe body(&value._address.pointee)
  }
}
