//
//  AccessPublishedStateTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 22.07.2026.
//

@_spi(PerformanceMeasuring) import StateFusion
import Testing

/// Compare results with `AccessRecursiveLockTests` to see difference.
struct AccessPublishedStateTests {
  let outer: Int = 1000
  let inner: Int = 1000
  
  // MARK: - MutableAccess : Write - Read

  /// Measures combined read/write access performance across different lock implementations.
  /// Compares `inout`, `pointer`, and `mutableAccess tracking` access patterns.
  @Test func `MutableAccess Write-Read`() {
    `MutableAccess ReadOnly`()
    `MutableAccess Write With No Subscriber`()
    `MutableAccess Write With Subscriber`()
  }

  private func `MutableAccess ReadOnly`() {
    if #available(macOS 26.0, *) {
      let source = InsulatedVersionedValueRelay(_value: DataState_SendableExample())

      let (_, inoutAccess) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          source.withLockAlwaysEmittingMutableAccess {
            blackHole($0)
          }
        }
      }

      let (_, mutableAccessDoWithRefHandle) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          source.withLockEmittingOnMutableAccess {
            blackHole($0.stateEntity)
          }
        }
      }
      
      printTable("MutableAccess ReadOnly",
                 rows: [("inout", inoutAccess),
                        ("AccessHandle", mutableAccessDoWithRefHandle)])
    }
  }
  
  private func `MutableAccess Write With No Subscriber`() {
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
      
      printTable("MutableAccess Write With No Subscriber",
                 rows: [("inout", inoutAccess),
                        ("AccessHandle", mutableAccessDoWithRefHandle)])
    }
  }
  
  private func `MutableAccess Write With Subscriber`() {
    if #available(macOS 26.0, *) {
      let source = InsulatedVersionedValueRelay(_value: DataState_SendableExample())
      let bag = CancellationBag()

      source.sink { _ in }.store(in: bag) // add subscriber
      
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
      
      printTable("MutableAccess Write With Subscriber",
                 rows: [("inout", inoutAccess),
                        ("AccessHandle", mutableAccessDoWithRefHandle)])
    }
  }
}
