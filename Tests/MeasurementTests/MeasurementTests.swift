//
//  MeasurementTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 12.06.2026.
//

import StateFusion
import Testing

@available(macOS 26.0, *)
struct DataState_Example {
  var number: Int = 0
  var title: String = "12345678901234567890"
  var text: String = "12345678901234567890"
  var array: [Int] = [1, 2, 3, 4, 5]
  var dict: [String: Int] = ["1": 1, "2": 2, "3": 3, "4": 4, "5": 5]
  var iarray = InlineArray<20, String>(repeating: "")
}

struct PlaygroundTests {
  let outer: Int = 1000
  let inner: Int = 1000
  
  @Test func `PublishedState withLockAccess RichState`() {
    if #available(macOS 26.0, *) {
      let richState = RichState(state: 0, data: DataState_Example())
      let publishedState = PublishedState(richState)

      let (_, withLockAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockAccess { state in
            blackHole(state)
          }
        }
      }
      
      let (_, withLockMutableAccessRead) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockMutableAccess {
            blackHole($0.stateEntity)
          }
        }
      }
      
      let (_, withLockMutableAccessWrite) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockMutableAccessRichState {
            $0.data.number += 1
          }
        }
      }
      
      print("___", withLockAccess, withLockMutableAccessRead, withLockMutableAccessWrite)
      // 
    }
  }
  
  @Test func `PublishedState withLockAccess`() {
    if #available(macOS 26.0, *) {
      let publishedState = PublishedState(DataState_Example())
      
      let (_, withLockAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockAccess { state in
            blackHole(state)
          }
        }
      }
      
      let (_, withLockMutableAccessRead) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockMutableAccess {
            blackHole($0.stateEntity)
          }
        }
      }
      
      let (_, withLockMutableAccessWrite) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockMutableAccess {
            $0.stateEntity.number += 1
          }
        }
      }
      
      print("___", withLockAccess, withLockMutableAccessRead, withLockMutableAccessWrite)
      // ___ 86.942413 152.744877 317.02686300000005
    }
  }
  
  @Test func playgroundPublishedState() {
    if #available(macOS 26.0, *) {
      let publishedState = _MPublishedState(DataState_Example())

      let (_, withLockAccess) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockAccess { state in
            blackHole(state)
          }
        }
      }
      
      let (_, withLockAccessInlined) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockAccessInlined { state in
            blackHole(state)
          }
        }
      }
      
      let (_, withLockAccessMutRef) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockAccessMutRef { state in
            blackHole(state.value)
          }
        }
      }
      
      let (_, withLockAccessMutRefInlined) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockAccessMutRefInlined { state in
            blackHole(state.value)
          }
        }
      }
      
      let (_, withLockAccessPointer) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockAccessPointer { state in
            blackHole(state.pointee)
          }
        }
      }
      
      let (_, withLockAccessMutPointerInlined) = performMeasuredAction(count: outer) {
        for _ in 1...inner {
          publishedState.withLockAccessMutPointerInlined { state in
            blackHole(state.pointee)
          }
        }
      }

      print("___", withLockAccess, withLockAccessInlined, withLockAccessMutRef, withLockAccessMutRefInlined, withLockAccessPointer, withLockAccessMutPointerInlined)
      // ___ 95.528788 88.474669 158.378432 154.906013 162.00706100000002 160.79825200000002
    }
  }
}
