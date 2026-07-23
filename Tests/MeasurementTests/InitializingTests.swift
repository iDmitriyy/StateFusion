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
  
  @Test func `Relays Init`() {
    let (_, tCurrentValueSubject) = performMeasuredAction(count: outer) { // reference measurement
      for _ in 0..<inner {
        blackHole(CurrentValueSubject<Int, Never>(0))
      }
    }

    let (_, tInsulatedVersionedValueRelay) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(InsulatedVersionedValueRelay<Int>(_value: 0))
      }
    }
    
    let (_, tPublishedState) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(consuming: PublishedState<Int>(0))
      }
    }
    
    let currentValueSubject = CurrentValueSubject<String, Never>("")
    
    let (_, tCurrentValuePublisher) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(CurrentValuePublisher(currentValueSubject))
      }
    }

    printTable("OperatorsChain Init",
               decimalDigits: 0,
               rows: [("CurrentValueSubject", tCurrentValueSubject),
                      ("InsulatedVersionedValueRelay", tInsulatedVersionedValueRelay),
                      ("PublishedState", tPublishedState),
                      ("CurrentValuePublisher", tCurrentValuePublisher)])
  }
  
  @Test func `SequentialSnapshot Init`() {
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
