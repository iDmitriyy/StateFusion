//
//  MeasurementTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 12.06.2026.
//

import Foundation
import StateFusion
import Testing

struct PlaygroundTests {
  let outer: Int = 1000
  let inner: Int = 1000

  var total: Int {
    outer * inner
  }

  @Test func `Denestify Inlined vs Not Inlined`() {
    if #available(macOS 26.0, *) {
      let tuple = ((("String_A", "String_B"), "String_C"), Duration(attoseconds: 10))

      let (_, tDenestify) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          blackHole(denestify(tuple: tuple))
        }
      }

      let (_, tDenestify_noInlining) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          blackHole(denestify_noInlining(tuple: tuple))
        }
      }
      
      printTable("Denestify inlined vs notInlined)",
                 fractionDigits: 0,
                 rows: [("denestify", tDenestify),
                        ("denestify noInlining", tDenestify_noInlining)])
    }
  }

  @Test func `PublishedState withLockAccess RichState`() {
//    if #available(macOS 26.0, *) {
//      let richState = StateCompound(state: LoadingState<Void, any Error>.isLoading, data: DataState_Example())
//      let publishedState = PublishedState(richState)
//
//      let (_, withLockAccess) = performMeasuredAction(count: outer) {
//        for _ in 0..<inner {
//          publishedState.withLockAccess { state in
//            blackHole(state)
//          }
//        }
//      }
//
//      let (_, withLockMutableAccessRead) = performMeasuredAction(count: outer) {
//        for _ in 0..<inner {
//          publishedState.withLockMutableAccess {
//            blackHole($0.stateEntity)
//          }
//        }
//      }
//
//      let (_, withLockMutableAccessWrite) = performMeasuredAction(count: outer) {
//        for _ in 0..<inner {
//          publishedState.withLockMutableAccessStateCompound {
//            $0.data.number += 1
//          }
//        }
//      }
//
//      printTable("PublishedState withLockAccess)",
//                 decimalDigits: 0,
//                 rows: [("withLockAccess", withLockAccess),
//                        ("withLockMutableAccessRead", withLockMutableAccessRead),
//                        ("withLockMutableAccessWrite", withLockMutableAccessWrite)])
//    }
  }

  @Test func `PublishedState withLockAccess`() {
//    if #available(macOS 26.0, *) {
//      let publishedState = PublishedState(DataState_Example())
//
//      let (_, withLockAccess) = performMeasuredAction(count: outer) {
//        for _ in 0..<inner {
//          publishedState.withLockAccess { state in
//            blackHole(state)
//          }
//        }
//      }
//
//      let (_, withLockMutableAccessRead) = performMeasuredAction(count: outer) {
//        for _ in 0..<inner {
//          publishedState.withLockMutableAccess {
//            blackHole($0.stateEntity)
//          }
//        }
//      }
//
//      let (_, withLockMutableAccessWrite) = performMeasuredAction(count: outer) {
//        for _ in 0..<inner {
//          publishedState.withLockMutableAccess {
//            $0.stateEntity.number += 1
//          }
//        }
//      }
//
//      printTable("PublishedState withLockAccess)",
//                 decimalDigits: 0,
//                 rows: [("withLockAccess", withLockAccess),
//                        ("withLockMutableAccessRead", withLockMutableAccessRead),
//                        ("withLockMutableAccessWrite", withLockMutableAccessWrite)])
//    }
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
                 fractionDigits: 0,
                 rows: [("withLockAccess", withLockAccess),
                        ("withLockAccessInlined", withLockAccessInlined),
                        (" withLockAccessMutRef", withLockAccessMutRef),
                        (" withLockAccessMutRefInlined", withLockAccessMutRefInlined),
                        ("withLockAccessPointer", withLockAccessPointer),
                        ("withLockAccessMutPointerInlined", withLockAccessMutPointerInlined)])
    }
  }
}

@inline(never)
fileprivate func denestify_noInlining<A, B, C, D>(tuple: (((A, B), C), D)) -> (A, B, C, D) {
  let (((a, b), c), d) = tuple
  return (a, b, c, d)
}
