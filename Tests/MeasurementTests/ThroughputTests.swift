//
//  ThroughputTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 17.06.2026.
//

@_spi(PerformanceMeasuring) import StateFusion
import Testing

/// Measures and compares throughput (elements per second) when sending
/// values with active subscribers.
///
/// What is compared:
/// - `CurrentValueSubject`: Standard Combine subject
/// - `VersionedValueRelay`: StateFusion's thread-safe relay with versioning
///
/// What measured in common:
/// - Time to send `inner` (1000) values, repeated `outer` (1000) times
/// - Both publishers have a single subscriber attached (via `sink`)
///
/// The test reveals throughput differences between the two publisher types
/// under identical workloads, highlighting the overhead of relay
/// synchronization mechanisms.
struct ThroughputTests: ~Copyable {
  let outer: Int = 1000
  let inner: Int = 1000
  
  let bag = CancellationBag()
  
  /// Measures elements-per-second throughput for both publishers with active subscribers.
  @Test func `Elements Per Second`() {
    let currentValueSubject = CurrentValueSubject<Int, Never>(0)
    let versionedValueRelay = InsulatedVersionedValueRelay<Int>(_value: 0)
    
    bag.insert {
      currentValueSubject.sink { _ in }
      versionedValueRelay.sink { _ in }
    }
    
    let (_, msCurrentValueSubject) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        currentValueSubject.send(i)
      }
    }

    let (_, msVersionedValueRelay) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        versionedValueRelay.send(nextValue: i)
      }
    }
    
    let totalIterations = Double(outer * inner)
    
    let thCurrentValueSubject = totalIterations * (1000 / msCurrentValueSubject)
    let thVersionedValueRelay = totalIterations * (1000 / msVersionedValueRelay)
    
    // CurrentValueSubject  9565905
    // VersionedValueRelay  187149

    printTable("Elements Per Second With Subscriber",
               decimalDigits: 0,
               rows: [("CurrentValueSubject", thCurrentValueSubject),
                      ("VersionedValueRelay", thVersionedValueRelay)])
  }
}
