//
//  RecursiveLock.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 16.07.2026.
//

import StateFusion
import Testing

struct RecursiveLockTests {
  let outer: Int = 1000
  let inner: Int = 1000

  @Test func `Access Variants Read`() {
    if #available(macOS 26.0, *) {
      let obj1 = RecursiveLock2Wrapper.shared
      
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
      
      let (_, mutableAccessTracking) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockMutableAccess {
            blackHole($0.stateEntity)
          } whenMutablyAccessedDo: { dataState in
            blackHole(dataState)
          }
        }
      }
      
      print("___", inoutAccess, pointerAccess, mutableAccessTracking)
    }
  }
  
  @Test func `Access Variants Write`() {
    if #available(macOS 26.0, *) {
      let obj1 = RecursiveLock2Wrapper.shared
      
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
      
      let (_, mutableAccessTracking) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          obj1.withLockMutableAccess {
            $0.stateEntity.number += 1
          } whenMutablyAccessedDo: { _ in }
        }
      }
      
      if #available(macOS 9999, *) {
        let (_, mutableAccessNativeTracking) = performMeasuredAction(count: outer) {
          for _ in 1...inner {
            obj1.withLockMutableAccessNative {
              $0.stateEntity.number += 1
            } whenMutablyAccessedDo: { _ in }
          }
        }
        
        print(mutableAccessNativeTracking) // 56.7008 when no mutableAccess tracking
      }
      
      print("___", inoutAccess, pointerAccess, mutableAccessTracking)
    }
  }

  @Test func `RecursiveLock Access`() {
    if #available(macOS 26.0, *) {
      let lock = RecursiveLock(DataState_Example())

      let (_, access1) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          lock.withLock {
            $0.number += 1
          }
        }
      }

      let (_, access3) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          lock.withLock3 {
            $0.pointee.number += 1
          }
        }
      }

      print("___", access1, access3)
    }
  }
  
  @available(anyAppleOS 26.0, *)
  final class RecursiveLock2Wrapper: Sendable {
    // static made for rejecting class stack allocation and allocate it in heap
    static let shared = RecursiveLock2Wrapper()

    let lock = RecursiveLock2(DataState_SendableExample())

    func withLockInout<Result: ~Copyable, E: Error>(
      _ body: (inout sending DataState_SendableExample) throws(E) -> sending Result,
    ) throws(E) -> sending Result {
      try lock.withLockInout(body)
    }

    func withLockPointer<Result: ~Copyable, E: Error>(
      _ body: (UnsafeMutablePointer<DataState_SendableExample>) throws(E) -> Result,
    ) throws(E) -> Result {
      try lock.withLockPointer(body)
    }

//    @inlinable
//    @inline(always)
    func withLockMutableAccess<R, E: Error>(_ access: (inout GenericStateAccessHandle<DataState_SendableExample>) throws(E) -> sending R,
                                            whenMutablyAccessedDo: (borrowing DataState_SendableExample) -> Void)
      throws(E) -> sending R {
      try lock.withLockMutableAccess(access, whenMutablyAccessedDo: whenMutablyAccessedDo)
    }
    
    @available(macOS 9999, *)
    func withLockMutableAccessNative<R, E: Error>(_ access: (inout GenericStateAccessHandle2<DataState_SendableExample>) throws(E) -> sending R,
                                            whenMutablyAccessedDo: (borrowing DataState_SendableExample) -> Void)
      throws(E) -> sending R {
      try lock.withLockMutableAccessNative(access, whenMutablyAccessedDo: whenMutablyAccessedDo)
    }
  }
}

//extension RecursiveLockTests {
//
//}
