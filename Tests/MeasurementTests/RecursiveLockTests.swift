//
//  RecursiveLockTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 16.07.2026.
//

import class Foundation.NSRecursiveLock
import StateFusion
import Testing

struct RecursiveLockTests {
  let outer: Int = 1000
  let inner: Int = 1000
  
  // MARK: - MytableAccess : ReadOnly
  
  @Test func `MutableAccess ReadOnly`() {
    `MutableAccess ReadOnly Backported.MutableRef`()
    `MutableAccess ReadOnly Swift.MutableRef`()
  }

  private func `MutableAccess ReadOnly Swift.MutableRef`() {
    if #available(macOS 26.0, *) {
      let obj1 = Object_SwiftRef.shared

      let (_, inoutAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockInout { dataState in
            blackHole(dataState)
          }
        }
      }

      let (_, pointerAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockPointer { dataStatePointer in
            blackHole(dataStatePointer.pointee)
          }
        }
      }

      let mutableAccessDoWithCopy: Double
      let mutableAccessDoWithRefHandle: Double
      if #available(macOS 9999, *) {
        (_, mutableAccessDoWithCopy) = performMeasuredAction(count: outer) {
          for _ in 1...inner {
            obj1.withLockMutableAccess_borrowing {
              blackHole($0.stateEntity)
            } whenMutablyAccessedDo: { _ in
            }
          }
        }

        (_, mutableAccessDoWithRefHandle) = performMeasuredAction(count: outer) {
          for _ in 1...inner {
            obj1.withLockMutableAccess_handle {
              blackHole($0.stateEntity)
            } whenMutablyAccessedDo: { _ in
            }
          }
        }
        // 56.7008 when no mutableAccess tracking
      } else {
        mutableAccessDoWithCopy = .nan
        mutableAccessDoWithRefHandle = .nan
      }

      printTable("MutableAccess ReadOnly Swift.MutRef",
                 rows: [("inout", inoutAccess),
                        ("pointer", pointerAccess),
                        ("with mutableAccess tracking, DoWithRefHandle", mutableAccessDoWithRefHandle),
                        ("with mutableAccess tracking, DoWithCopy", mutableAccessDoWithCopy)])
    }
  }

  private func `MutableAccess ReadOnly Backported.MutableRef`() {
    if #available(macOS 26.0, *) {
      let obj1 = Object_BackportedRef.shared

      let (_, inoutAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockInout { dataState in
            blackHole(dataState)
          }
        }
      }

      let (_, mutableAccessDoWithRefHandle) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockMutableAccess_handle {
            blackHole($0.stateEntity)
          } whenMutablyAccessedDo: { _ in
          }
        }
      }

      printTable("MutableAccess ReadOnly Backported.MutableRef",
                 rows: [("inout", inoutAccess),
                        ("with mutableAccess tracking, DoWithRefHandle", mutableAccessDoWithRefHandle)])
    }
  }
  
  // MARK: - MytableAccess : WriteOnly

  @Test func `MutableAccess WriteOnly`() {
    `MutableAccess WriteOnly Backported.MutableRef`()
    `MutableAccess WriteOnly Swift.MutableRef`()
  }

  private func `MutableAccess WriteOnly Swift.MutableRef`() {
    if #available(macOS 26.0, *) {
      let obj1 = Object_SwiftRef.shared

      let (_, inoutAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockInout { dataState in
            dataState.number += 1
          }
        }
      }

      let (_, pointerAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockPointer { dataStatePointer in
            dataStatePointer.pointee.number += 1
          }
        }
      }

      let mutableAccessDoWithCopy: Double
      let mutableAccessDoWithRefHandle: Double
      if #available(macOS 9999, *) {
        (_, mutableAccessDoWithCopy) = performMeasuredAction(count: outer) {
          for _ in 1...inner {
            obj1.withLockMutableAccess_borrowing {
              $0.stateEntity.number += 1
            } whenMutablyAccessedDo: { _ in
            }
          }
        }

        (_, mutableAccessDoWithRefHandle) = performMeasuredAction(count: outer) {
          for _ in 1...inner {
            obj1.withLockMutableAccess_handle {
              $0.stateEntity.number += 1
            } whenMutablyAccessedDo: { _ in
            }
          }
        }
        // 56.7008 when no mutableAccess tracking
      } else {
        mutableAccessDoWithCopy = .nan
        mutableAccessDoWithRefHandle = .nan
      }

      printTable("MutableAccess WriteOnly Swift.MutRef",
                 rows: [("inout", inoutAccess),
                        ("pointer", pointerAccess),
                        ("with mutableAccess tracking, DoWithRefHandle", mutableAccessDoWithRefHandle),
                        ("with mutableAccess tracking, DoWithCopy", mutableAccessDoWithCopy)])
    }
  }

  private func `MutableAccess WriteOnly Backported.MutableRef`() {
    if #available(macOS 26.0, *) {
      let obj1 = Object_BackportedRef.shared

      let (_, inoutAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockInout { dataState in
            dataState.number += 1
          }
        }
      }

      let (_, mutableAccessDoWithRefHandle) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockMutableAccess_handle {
            $0.stateEntity.number += 1
          } whenMutablyAccessedDo: { _ in
          }
        }
      }

      printTable("MutableAccess WriteOnly Backported.MutableRef",
                 rows: [("inout", inoutAccess),
                        ("with mutableAccess tracking, DoWithRefHandle", mutableAccessDoWithRefHandle)])
    }
  }
  
  // MARK: - MytableAccess : Write-Read

  @Test func `MutableAccess Write-Read`() {
    `MutableAccess Write-Read Backported.MutableRef`()
    `MutableAccess Write-Read Swift.MutableRef`()
  }

  private func `MutableAccess Write-Read Swift.MutableRef`() {
    if #available(macOS 26.0, *) {
      let obj1 = Object_SwiftRef.shared

      let (_, inoutAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockInout { dataState in
            dataState.number += 1
            blackHole(dataState)
          }
        }
      }

      let (_, pointerAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockPointer { dataStatePointer in
            dataStatePointer.pointee.number += 1
            blackHole(dataStatePointer.pointee)
          }
        }
      }

      let mutableAccessDoWithCopy: Double
      let mutableAccessDoWithRefHandle: Double
      if #available(macOS 9999, *) {
        (_, mutableAccessDoWithCopy) = performMeasuredAction(count: outer) {
          for _ in 1...inner {
            obj1.withLockMutableAccess_borrowing {
              $0.stateEntity.number += 1
            } whenMutablyAccessedDo: { stateEntity in
              blackHole(stateEntity)
            }
          }
        }

        (_, mutableAccessDoWithRefHandle) = performMeasuredAction(count: outer) {
          for _ in 1...inner {
            obj1.withLockMutableAccess_handle {
              $0.stateEntity.number += 1
            } whenMutablyAccessedDo: {
              blackHole($0.stateEntity)
            }
          }
        }
        // 56.7008 when no mutableAccess tracking
      } else {
        mutableAccessDoWithCopy = .nan
        mutableAccessDoWithRefHandle = .nan
      }

      printTable("MutableAccess Write-Read Swift.MutRef",
                 rows: [("inout", inoutAccess),
                        ("pointer", pointerAccess),
                        ("with mutableAccess tracking, DoWithRefHandle", mutableAccessDoWithRefHandle),
                        ("with mutableAccess tracking, DoWithCopy", mutableAccessDoWithCopy)])
    }
  }

  private func `MutableAccess Write-Read Backported.MutableRef`() {
    if #available(macOS 26.0, *) {
      let obj1 = Object_BackportedRef.shared

      let (_, inoutAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockInout { dataState in
            dataState.number += 1
            blackHole(dataState)
          }
        }
      }

      let (_, mutableAccessDoWithRefHandle) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockMutableAccess_handle {
            $0.stateEntity.number += 1
          } whenMutablyAccessedDo: {
            blackHole($0.stateEntity)
          }
        }
      }

      printTable("MutableAccess Write-Read Backported.MutableRef",
                 rows: [("inout", inoutAccess),
                        ("with mutableAccess tracking, DoWithRefHandle", mutableAccessDoWithRefHandle)])
    }
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - Backported:_MutableRef Handle

extension RecursiveLockTests {
  @available(anyAppleOS 26.0, *)
  final class Object_BackportedRef: Sendable {
    /// static made for rejecting class stack allocation and allocate it in heap
    static let shared = Object_BackportedRef()

    let lock = RecursiveLock(DataState_SendableExample())

    @inline(always)
    func withLockInout<Result: ~Copyable, E: Error>(
      _ body: (inout sending DataState_SendableExample) throws(E) -> sending Result,
    ) throws(E) -> sending Result {
      try lock.withLock(body)
    }

    @inline(always)
    func withLockMutableAccess_handle<R: Sendable, E: Error>(
      _ access: (inout GenericStateAccessHandle<DataState_SendableExample>) throws(E) -> R,
      whenMutablyAccessedDo: (borrowing GenericStateAccessHandle<DataState_SendableExample>) -> Void,
    )
      throws(E) -> R {
      try lock.withLockMutableAccess(access, whenMutablyAccessedDo: whenMutablyAccessedDo)
    }
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - Swift:MutableRef Handle | +Pointer access

extension RecursiveLockTests {
  @available(anyAppleOS 26.0, *)
  final class Object_SwiftRef: Sendable {
    /// static made for rejecting class stack allocation and allocate it in heap
    static let shared = Object_SwiftRef()

    let lock = RecursiveLockClass(DataState_SendableExample())

    @inline(always)
    func withLockInout<Result: ~Copyable, E: Error>(
      _ body: (inout sending DataState_SendableExample) throws(E) -> sending Result,
    ) throws(E) -> sending Result {
      try lock.withLockInout(body)
    }

    @inline(always)
    func withLockPointer<Result: ~Copyable, E: Error>(
      _ body: (UnsafeMutablePointer<DataState_SendableExample>) throws(E) -> Result,
    ) throws(E) -> Result {
      try lock.withLockPointer(body)
    }

    @available(anyAppleOS 9999, *)
    @inline(always)
    func withLockMutableAccess_borrowing<R, E: Error>(
      _ access: (inout SwiftMutableRefAccessHandle<DataState_SendableExample>) throws(E) -> R,
      whenMutablyAccessedDo: (borrowing DataState_SendableExample) -> Void,
    )
      throws(E) -> R {
      try lock.withLockMutableAccess_borrowing(access, whenMutablyAccessedDo: whenMutablyAccessedDo)
    }

    @available(anyAppleOS 9999, *)
    @inline(always)
    func withLockMutableAccess_handle<R, E: Error>(
      _ access: (inout SwiftMutableRefAccessHandle<DataState_SendableExample>) throws(E) -> R,
      whenMutablyAccessedDo: (borrowing SwiftMutableRefAccessHandle<DataState_SendableExample>) -> Void,
    )
      throws(E) -> R {
      try lock.withLockMutableAccess_handle(access, whenMutablyAccessedDo: whenMutablyAccessedDo)
    }
  }
}

// MARK: RecursiveLock 2

extension RecursiveLockTests {
  final class RecursiveLockClass<Value: ~Copyable>: @unchecked Sendable {
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
  }
}

extension RecursiveLockTests.RecursiveLockClass where Value: Sendable {
  @available(anyAppleOS 9999, *)
  func withLockMutableAccess_handle<R, E: Error>(_ access: (inout SwiftMutableRefAccessHandle<Value>) throws(E) -> R,
                                                 whenMutablyAccessedDo: (borrowing SwiftMutableRefAccessHandle<Value>) -> Void)
    throws(E) -> R {
    _lock.lock(); defer { _lock.unlock() }

    var accessHandle = SwiftMutableRefAccessHandle(mutableRef: Swift.MutableRef(&_value))
    let result = try access(&accessHandle)

    if accessHandle._isMutablyAccessed {
      whenMutablyAccessedDo(accessHandle)
    }

    return result
  }

  @available(anyAppleOS 9999, *)
  func withLockMutableAccess_borrowing<R, E: Error>(_ access: (inout SwiftMutableRefAccessHandle<Value>) throws(E) -> R,
                                                    whenMutablyAccessedDo: (borrowing Value) -> Void)
    throws(E) -> R {
    _lock.lock(); defer { _lock.unlock() }

    var accessHandle = SwiftMutableRefAccessHandle(mutableRef: Swift.MutableRef(&_value))
    let result = try access(&accessHandle)

    if accessHandle._isMutablyAccessed {
      whenMutablyAccessedDo(_value)
    }

    return result
  }
}

// MARK: Swift:MutableRef AccessHandle

@available(anyAppleOS 9999, *)
public struct SwiftMutableRefAccessHandle<StateEntity: ~Copyable>: ~Copyable, ~Escapable {
  @_alwaysEmitIntoClient
  @_transparent
  public var stateEntity: StateEntity {
    @inlinable @inline(always)
    borrow {
      _mutableRef.value
    }
    @inlinable @inline(always)
    mutate {
      _isMutablyAccessed = true
      return &_mutableRef.value
    }
  }

  @usableFromInline
  internal var _isMutablyAccessed: Bool = false

  /// private
  @usableFromInline
  /* private */ internal var _mutableRef: Swift.MutableRef<StateEntity>

  @_alwaysEmitIntoClient
  @_lifetime(copy mutableRef)
  @_transparent
  internal init(mutableRef: consuming Swift.MutableRef<StateEntity>) {
    _mutableRef = mutableRef
  }
}
