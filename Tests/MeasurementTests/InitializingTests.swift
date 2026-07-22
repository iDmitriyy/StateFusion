//
//  InitializingTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 22.07.2026.
//

@_spi(PerformanceMeasuring) import StateFusion
import Testing

struct InitializingTests {
  let outer: Int = 1000
  let inner: Int = 1000
  
  @Test func `All`() {
    let sourceID = SourceID()
    let (_, t) = performMeasuredAction(count: outer) {
      for version in 0..<(UInt32(inner)) {
        blackHole(SequentialSnapshot(_value: version, _version: version, _sourceID: sourceID))
      }
    }
    
    print("___", t)
  }
  
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
