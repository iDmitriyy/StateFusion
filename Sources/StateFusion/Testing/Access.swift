//
//  Access.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 12.06.2026.
//

public import Combine
public import class Foundation.NSRecursiveLock

public struct _MPublishedState<StateEntity: Sendable>: ~Copyable, Sendable {
  @usableFromInline
  internal let _stateImpObject: __MPublishedState<StateEntity>

  public init(_ initialValue: consuming StateEntity) {
    _stateImpObject = __MPublishedState(initialValue)
  }

  // MARK: Synchronous Thread-Safe access

  @inline(never)
  public func withLockAccess<R, E>(_ access: (borrowing StateEntity) throws(E) -> sending R)
    throws(E) -> sending R {
    try _stateImpObject.withLockAccess(access)
  }

  @inlinable
  @inline(always)
  public func withLockAccessInlined<R, E>(_ access: (borrowing StateEntity) throws(E) -> sending R)
    throws(E) -> sending R {
    try _stateImpObject.withLockAccessInlined(access)
  }

  @inline(never)
  public func withLockAccessMutRef<R, E>(_ access: (inout _MutableRef<StateEntity>) throws(E) -> sending R)
    throws(E) -> sending R {
    try _stateImpObject.withLockAccessMutRef(access)
  }

  @inlinable
  @inline(always)
  public func withLockAccessMutRefInlined<R, E>(_ access: (inout _MutableRef<StateEntity>) throws(E) -> sending R)
    throws(E) -> sending R {
    try _stateImpObject.withLockAccessMutRefInlined(access)
  }

  @inline(never)
  public func withLockAccessPointer<R, E>(_ access: (UnsafeMutablePointer<StateEntity>) throws(E) -> R)
    throws(E) -> R {
    try _stateImpObject.withLockAccessPointer(access)
  }

  @inlinable
  @inline(always)
  public func withLockAccessMutPointerInlined<R, E>(_ access: (UnsafeMutablePointer<StateEntity>) throws(E) -> R)
    throws(E) -> R {
    try _stateImpObject.withLockAccessPointer(access)
  }
}

@usableFromInline
internal final class __MPublishedState<StateEntity: Sendable>: @unchecked Sendable {
  @usableFromInline
  internal let subject: CurrentValueSubject<StateEntity, Never>

  @usableFromInline
  internal let lock = NSRecursiveLock()

  internal init(_ initialValue: StateEntity) {
    subject = CurrentValueSubject(initialValue)
  }

  @inline(never)
  internal final func withLockAccess<R, E>(_ access: (borrowing StateEntity) throws(E) -> sending R)
    throws(E) -> sending R {
    lock.lock(); defer { lock.unlock() }

    var stateAndData = subject.value
    let result = try access(stateAndData)

    return result
  }

  @inlinable
  @inline(always)
  public func withLockAccessInlined<R, E>(_ access: (borrowing StateEntity) throws(E) -> sending R)
    throws(E) -> sending R {
      lock.lock(); defer { lock.unlock() }

      var stateAndData = subject.value
      let result = try access(stateAndData)

      return result
  }

  @inline(never)
  public func withLockAccessMutRef<R, E>(_ access: (inout _MutableRef<StateEntity>) throws(E) -> sending R)
    throws(E) -> sending R {
      lock.lock(); defer { lock.unlock() }

      var stateAndData = subject.value
      var ref = _MutableRef(&stateAndData)
      
      let result = try access(&ref)
      return result
  }

  @inlinable
  @inline(always)
  public func withLockAccessMutRefInlined<R, E>(_ access: (inout _MutableRef<StateEntity>) throws(E) -> sending R)
    throws(E) -> sending R {
      lock.lock(); defer { lock.unlock() }

      var stateAndData = subject.value
      var ref = _MutableRef(&stateAndData)
      
      let result = try access(&ref)

      return result
  }

  @inline(never)
  public func withLockAccessPointer<R, E>(_ access: (UnsafeMutablePointer<StateEntity>) throws(E) -> R)
    throws(E) -> R {
      lock.lock(); defer { lock.unlock() }

      var stateAndData = subject.value
      let result = try withUnsafeMutablePointer(to: &stateAndData) { pointer throws(E) -> R in
        try access(pointer)
      }

      return result
  }

  @inline(always)
  public func withLockAccessMutPointerInlined<R, E>(_ access: (UnsafeMutablePointer<StateEntity>) throws(E) -> R)
    throws(E) -> R {
      lock.lock(); defer { lock.unlock() }

      var stateAndData = subject.value
      let result = try withUnsafeMutablePointer(to: &stateAndData) { (pointer) throws(E) -> R in
        try access(pointer)
      }

      return result
  }
}

@inline(never) @_optimize(none)
public func blackHole<T>(_ thing: T) {
  _ = thing
}
