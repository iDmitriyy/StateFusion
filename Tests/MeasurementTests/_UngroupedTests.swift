//
//  _UngroupedTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 23.07.2026.
//

@_spi(PerformanceMeasuring) import StateFusion
import Testing

struct UngroupedTests {
  let outer: Int = 1000
  let inner: Int = 1000
  
  @Test func `SequentialSnapshot Version`() {
    let sourceID = SourceID()
    let snapshot = SequentialSnapshot<Int>(_value: 0, _version: 0, _sourceID: sourceID)
    let (_, t) = performMeasuredAction(count: outer) {
      for _ in 0..<(inner * 10) {
        blackHole(snapshot.version)
      }
    }
    
    print("___", t)
  }
}
