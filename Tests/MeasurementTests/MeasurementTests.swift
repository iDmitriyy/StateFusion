//
//  MeasurementTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 12.06.2026.
//

import StateFusion
import Testing

struct PlaygroundTests {
  let outer: Int = 1000
  let inner: Int = 1000
  
  var total: Int { outer * inner }
  
  @Test func `PublishedState withLockAccess RichState`() {
    if #available(macOS 26.0, *) {
      let richState = StateCompound(state: 0, data: DataState_Example())
      let publishedState = PublishedState(richState)

      let (_, withLockAccess) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockAccess { state in
            blackHole(state)
          }
        }
      }
      
      let (_, withLockMutableAccessRead) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockMutableAccess {
            blackHole($0.stateEntity)
          }
        }
      }
      
      let (_, withLockMutableAccessWrite) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockMutableAccessStateCompound {
            $0.data.number += 1
          }
        }
      }
      
      printTable("PublishedState withLockAccess)",
                 decimalDigits: 0,
                 rows: [("withLockAccess", withLockAccess),
                        ("withLockMutableAccessRead", withLockMutableAccessRead),
                        ("withLockMutableAccessWrite", withLockMutableAccessWrite)])
    }
  }
  
  @Test func `PublishedState withLockAccess`() {
    if #available(macOS 26.0, *) {
      let publishedState = PublishedState(DataState_Example())
      
      let (_, withLockAccess) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockAccess { state in
            blackHole(state)
          }
        }
      }
      
      let (_, withLockMutableAccessRead) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockMutableAccess {
            blackHole($0.stateEntity)
          }
        }
      }
      
      let (_, withLockMutableAccessWrite) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockMutableAccess {
            $0.stateEntity.number += 1
          }
        }
      }
      
      printTable("PublishedState withLockAccess)",
                 decimalDigits: 0,
                 rows: [("withLockAccess", withLockAccess),
                        ("withLockMutableAccessRead", withLockMutableAccessRead),
                        ("withLockMutableAccessWrite", withLockMutableAccessWrite)])
    }
  }
  
  @Test func playgroundPublishedState() {
    if #available(macOS 26.0, *) {
      let publishedState = _MPublishedState(DataState_Example())

      let (_, withLockAccess) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockAccess { state in
            blackHole(state)
          }
        }
      }
      
      let (_, withLockAccessInlined) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockAccessInlined { state in
            blackHole(state)
          }
        }
      }
      
      let (_, withLockAccessMutRef) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockAccessMutRef { state in
            blackHole(state.value)
          }
        }
      }
      
      let (_, withLockAccessMutRefInlined) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockAccessMutRefInlined { state in
            blackHole(state.value)
          }
        }
      }
      
      let (_, withLockAccessPointer) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockAccessPointer { state in
            blackHole(state.pointee)
          }
        }
      }
      
      let (_, withLockAccessMutPointerInlined) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          publishedState.withLockAccessMutPointerInlined { state in
            blackHole(state.pointee)
          }
        }
      }
      
      printTable("_MPublishedState)",
                 decimalDigits: 0,
                 rows: [("withLockAccess", withLockAccess),
                        ("withLockAccessInlined", withLockAccessInlined),
                        (" withLockAccessMutRef", withLockAccessMutRef),
                        (" withLockAccessMutRefInlined", withLockAccessMutRefInlined),
                        ("withLockAccessPointer", withLockAccessPointer),
                        ("withLockAccessMutPointerInlined", withLockAccessMutPointerInlined)])
    }
  }
}
