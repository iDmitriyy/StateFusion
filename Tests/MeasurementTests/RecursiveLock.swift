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
}
