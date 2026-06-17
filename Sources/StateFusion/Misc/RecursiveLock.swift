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

  /// https://github.com/swiftlang/swift/blob/8454a3169ec99e23ae0974399f08afc4d43aa040/stdlib/public/Synchronization/Cell.swift#L18
  private let value: _Cell<Value>
  
  public init(_ initialValue: consuming sending Value) {
    value = _Cell(initialValue)
  }
} // reference:  https://github.com/swiftlang/swift/blob/e1c9eef30ca2e17163c8e8559befeb4dbca0e09a/stdlib/public/Synchronization/Mutex/Mutex.swift#L37

extension RecursiveLock: @unchecked Sendable where Value: ~Copyable {}

extension RecursiveLock where Value: ~Copyable {
  internal borrowing func withLock<Result: ~Copyable, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending Result,
  ) throws(E) -> sending Result {
    _lock.lock(); defer { _lock.unlock() }

    return try unsafe body(&value._address.pointee)
  }
}
