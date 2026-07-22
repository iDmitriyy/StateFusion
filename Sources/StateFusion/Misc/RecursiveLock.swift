//
//  RecursiveLock.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 15.06.2026.
//

import class Foundation.NSRecursiveLock
import struct Synchronization._Cell

// MARK: - RecursiveLock

import os

@_staticExclusiveOnly
public struct RecursiveLock<Value: ~Copyable>: ~Copyable {
  private let _lock = NSRecursiveLock()

  /// https://github.com/swiftlang/swift/blob/8454a3169ec99e23ae0974399f08afc4d43aa040/stdlib/public/Synchronization/Cell.swift
  private let value: _Cell<Value>

  public init(_ initialValue: consuming sending Value) {
    value = _Cell(initialValue)
  }

  /// Initialize an RecursiveLock with a non-sendable lock-protected
  /// `initialState`.
  ///
  /// By initializing with a non-sendable type, the owner of this structure
  /// must ensure the Sendable contract is upheld manually.
  /// Non-sendable content from `State` should not be allowed
  /// to escape from the lock.
  ///
  /// - Parameter initialState: An initial value to store that will be
  ///  protected under the lock.
  public init(uncheckedState initialValue: consuming Value) {
    value = _Cell(initialValue)
  }
} // reference:  https://github.com/swiftlang/swift/blob/e1c9eef30ca2e17163c8e8559befeb4dbca0e09a/stdlib/public/Synchronization/Mutex/Mutex.swift#L37

extension RecursiveLock: @unchecked Sendable where Value: ~Copyable {}

extension RecursiveLock where Value: ~Copyable {
  // FIXME: - where Result: Sendable instead of `sending Result`
  
  public borrowing func withLock<Result: ~Copyable, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending Result,
  ) throws(E) -> sending Result {
    _lock.lock(); defer { _lock.unlock() }

    return try unsafe body(&value._address.pointee)
  }

  ///  Perform a closure while holding this lock.
  ///  This method does not enforce sendability requirement
  ///  on closure body and its return type.
  ///  The caller of this method is responsible for ensuring references
  ///   to non-sendables from closure uphold the Sendability contract.
  ///
  /// - Parameter body: A closure to invoke while holding this lock.
  /// - Returns: The return value of `body`.
  /// - Throws: Anything thrown by `body`.
  public borrowing func withLockUncheckedSending<Result: ~Copyable, E: Error>(
    _ body: (inout sending Value) throws(E) -> Result,
  ) throws(E) -> sending Result {
    _lock.lock(); defer { _lock.unlock() }

    return try unsafe body(&value._address.pointee)
  }

  public func withLockMutableAccess<R: Sendable, E: Error>(
    _ access: (inout GenericStateAccessHandle<Value>) throws(E) -> R,
    whenMutablyAccessedDo: (borrowing GenericStateAccessHandle<Value>) -> Void
  ) throws(E) -> R {
    _lock.lock(); defer { _lock.unlock() }

    var stub: UInt = 0
    var accessHandle = GenericStateAccessHandle(mutableRef: _MutableRef(unsafeAddress: value._address, mutating: &stub))
    // FIXME: - error: accessHandle escapes its scope
//    var accessHandle = GenericStateAccessHandle(mutableRef: _MutableRef(&value._address.pointee))
    let result = try access(&accessHandle)

    if accessHandle._isMutablyAccessed {
      whenMutablyAccessedDo(accessHandle)
    }

    return result
  }
}
