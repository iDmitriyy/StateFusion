//
//  ThroughputTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 17.06.2026.
//

@_spi(PerformanceMeasuring) import StateFusion
import Testing

struct ThroughputTests: ~Copyable {
  let outer: Int = 1000
  let inner: Int = 1000
  
  let bag = CancellationBag()
  
  @Test func `Elements Per Second`() {
    let currentValueSubject = CurrentValueSubject<Int, Never>(0)
    let versionedValueRelay = InsulatedVersionedValueRelay<Int>(_value: 0)
    
    bag.insert {
      currentValueSubject.sink { _ in }
      versionedValueRelay.sink { _ in }
    }
    
    let (_, tCurrentValueSubject) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        currentValueSubject.send(i)
      }
    }

    let (_, tVersionedValueRelay) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        versionedValueRelay.send(nextValue: i)
      }
    }
    
    printTable("MutableAccess Write With No Subscriber",
               rows: [("CurrentValueSubject", tCurrentValueSubject),
                      ("VersionedValueRelay", tVersionedValueRelay)])
  }
}
