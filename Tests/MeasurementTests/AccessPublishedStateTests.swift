//
//  AccessPublishedStateTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 22.07.2026.
//

@_spi(Testing) import StateFusion
import Testing

/// Compare results with `AccessRecursiveLockTests` to see difference.
struct AccessPublishedStateTests {
  let outer: Int = 1000
  let inner: Int = 1000
  
  
  // MARK: - MutableAccess : ReadOnly
  
  
  // MARK: - MutableAccess : Write - Read

  /// Measures combined read/write access performance across different lock implementations.
  /// Compares `inout`, `pointer`, and mutableAccess tracking access patterns.
  @Test func `MutableAccess Write-Read`() {
    `MutableAccess Write NoEmission`()
//    `MutableAccess Write-Read Swift.MutableRef`()
  }

//  private func `MutableAccess Write-Read Swift.MutableRef`() {
//    if #available(macOS 26.0, *) {
//      let obj1 = SwiftRef_TestObject.shared
//
//      let (_, inoutAccess) = performMeasuredAction(count: outer) {
//        for _ in 1...inner {
//          obj1.withLockInout { dataState in
//            dataState.number += 1
//            blackHole(dataState)
//          }
//        }
//      }
//
//      let (_, pointerAccess) = performMeasuredAction(count: outer) {
//        for _ in 1...inner {
//          obj1.withLockPointer { dataStatePointer in
//            dataStatePointer.pointee.number += 1
//            blackHole(dataStatePointer.pointee)
//          }
//        }
//      }
//
//      let mutableAccessDoWithCopy: Double
//      let mutableAccessDoWithRefHandle: Double
//      if #available(macOS 9999, *) {
//        (_, mutableAccessDoWithCopy) = performMeasuredAction(count: outer) {
//          for _ in 1...inner {
//            obj1.withLockMutableAccess_borrowing {
//              $0.stateEntity.number += 1
//            } whenMutablyAccessedDo: { stateEntity in
//              blackHole(stateEntity)
//            }
//          }
//        }
//
//        (_, mutableAccessDoWithRefHandle) = performMeasuredAction(count: outer) {
//          for _ in 1...inner {
//            obj1.withLockMutableAccess_handle {
//              $0.stateEntity.number += 1
//            } whenMutablyAccessedDo: {
//              blackHole($0.stateEntity)
//            }
//          }
//        }
//        // 56.7008 when no mutableAccess tracking
//      } else {
//        mutableAccessDoWithCopy = .nan
//        mutableAccessDoWithRefHandle = .nan
//      }
//
//      printTable("MutableAccess Write-Read Swift.MutRef",
//                 rows: [("inout", inoutAccess),
//                        ("pointer", pointerAccess),
//                        ("with mutableAccess tracking, DoWithRefHandle", mutableAccessDoWithRefHandle),
//                        ("with mutableAccess tracking, DoWithCopy", mutableAccessDoWithCopy)])
//    }
//  }

  private func `MutableAccess Write NoEmission`() {
    if #available(macOS 26.0, *) {
      
      let source = InsulatedVersionedValueRelay(_value: DataState_SendableExample())

      let (_, inoutAccess) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          source.withLockAlwaysEmittingMutableAccess {
            $0.number += 1
          }
        }
      }

      let (_, mutableAccessDoWithRefHandle) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          source.withLockEmittingOnMutableAccess {
            $0.stateEntity.number += 1
          }
        }
      }

      // inout                                         209.30
      // with mutableAccess tracking, DoWithRefHandle  213.66
      
      printTable("MutableAccess Write NoEmission",
                 rows: [("always emiting inout", inoutAccess),
                        ("emitting On MutableAccess", mutableAccessDoWithRefHandle)])
    }
  }
}
