//
//  RecursiveLock.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 15.06.2026.
//

public import class Foundation.NSRecursiveLock
import Synchronization

// MARK: - RecursiveLock

import os

@_staticExclusiveOnly
public struct RecursiveLock<Value: ~Copyable>: ~Copyable {
  private let _lock = NSRecursiveLock()

  /// https://github.com/swiftlang/swift/blob/8454a3169ec99e23ae0974399f08afc4d43aa040/stdlib/public/Synchronization/Cell.swift#L18
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

//  internal borrowing func withLock2<Result: ~Copyable, E: Error>(
//    _ body: (inout _MutableRef<Value>) throws(E) -> sending Result,
//  ) throws(E) -> sending Result {
//    _lock.lock(); defer { _lock.unlock() }
//
//    var ref = _MutableRef(&value._address.pointee)
//    return try body(&ref)
//  }

  public borrowing func withLock3<Result: ~Copyable, E: Error>(
    _ body: (UnsafeMutablePointer<Value>) throws(E) -> sending Result,
  ) throws(E) -> sending Result {
    _lock.lock(); defer { _lock.unlock() }
    return try body(value._address)
  }
}

// MARK: - RecursiveLock 2

public final class RecursiveLock2<Value: ~Copyable>: @unchecked Sendable {
  @usableFromInline
  internal let _lock = NSRecursiveLock()

  @usableFromInline
  internal var _value: Value

  public init(_ initialValue: consuming sending Value) {
    _value = initialValue
  }

  public func withLockInout<Result: ~Copyable, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending Result,
  ) throws(E) -> sending Result {
    _lock.lock(); defer { _lock.unlock() }

    return try body(&_value)
  }

  public func withLockPointer<Result: ~Copyable, E: Error>(
    _ body: (UnsafeMutablePointer<Value>) throws(E) -> Result,
  ) throws(E) -> Result {
    _lock.lock(); defer { _lock.unlock() }

    return try withUnsafeMutablePointer(to: &_value) { pointer throws(E) -> Result in
      try body(pointer)
    }
  }

  // withLockEmittingOnMutableAccess

//  public borrowing func withLockMutRef<Result: ~Copyable, E: Error>(
//    _ body: (borrowing _MutableRef<Value>) throws(E) -> sending Result,
//  ) throws(E) -> sending Result {
//    _lock.lock(); defer { _lock.unlock() }
//
//    var ref = _MutableRef(&value)
//    let result = try body(ref)
//
//    return result
//  }
//
//  @available(macOS 9999, *)
//  public borrowing func withLockNativeMutRef<Result: ~Copyable, E: Error>(
//    _ body: (inout MutableRef<Value>) throws(E) -> sending Result,
//  ) throws(E) -> sending Result {
//    _lock.lock(); defer { _lock.unlock() }
//
//    var ref = MutableRef(&value)
//    let result = try body(&ref)
//
//    return result
//  }
}

extension RecursiveLock2 where Value: Sendable & Copyable {
//  @inlinable
//  @inline(always)
  public final func withLockMutableAccess<R, E: Error>(_ access: (inout GenericStateAccessHandle<Value>) throws(E) -> sending R,
                                                         whenMutablyAccessedDo: (borrowing GenericStateAccessHandle<Value>) -> Void)
    throws(E) -> sending R {
    _lock.lock(); defer { _lock.unlock() }

    var accessHandle = GenericStateAccessHandle(mutableRef: _MutableRef(&_value))
    let result = try access(&accessHandle)
    let isMutablyAccessed = accessHandle._isMutablyAccessed

    if isMutablyAccessed {
      whenMutablyAccessedDo(accessHandle)
    }

    return result
  }
  
  @inlinable @inline(always)
  @available(macOS 9999, *)
  public final func withLockMutableAccessNative<R, E: Error>(_ access: (inout GenericStateAccessHandle2<Value>) throws(E) -> sending R,
                                                         whenMutablyAccessedDo: (borrowing Value) -> Void)
    throws(E) -> sending R {
    _lock.lock(); defer { _lock.unlock() }

    var accessHandle = GenericStateAccessHandle2(mutableRef: MutableRef(&_value))
    let result = try access(&accessHandle)
    
    // without inlining accessHandle.isMutablyAccessed branch make func 3.5x slower
//    if _fastPath(accessHandle._isMutablyAccessed) { // 56ms without this branch | 202ms with it
      whenMutablyAccessedDo(_value)
//    }

    return result
  }
  
//  @inlinable @inline(always)
  @available(macOS 9999, *)
  public final func withLockMutableAccessNativeH<R, E: Error>(_ access: (inout GenericStateAccessHandle2<Value>) throws(E) -> sending R,
                                                         whenMutablyAccessedDo: (borrowing GenericStateAccessHandle2<Value>) -> Void)
    throws(E) -> sending R {
    _lock.lock(); defer { _lock.unlock() }

    var accessHandle = GenericStateAccessHandle2(mutableRef: MutableRef(&_value))
    let result = try access(&accessHandle)
    
    // without inlining accessHandle.isMutablyAccessed branch make func 3.5x slower
//    if _fastPath(accessHandle._isMutablyAccessed) { // 56ms without this branch | 202ms with it
//      whenMutablyAccessedDo(_value)
//    }
      if accessHandle._isMutablyAccessed {
        whenMutablyAccessedDo(accessHandle)
      }
      
    return result
  }
  
  @inlinable @inline(always)
  @available(macOS 9999, *)
  public final func withLockMutableAccessNative<R, E: Error>(_ access: (inout GenericStateAccessHandle2<Value>) throws(E) -> sending R)
    throws(E) -> sending R {
    _lock.lock(); defer { _lock.unlock() }

    var accessHandle = GenericStateAccessHandle2(mutableRef: MutableRef(&_value))
    let result = try access(&accessHandle)

    return result
  }
}
