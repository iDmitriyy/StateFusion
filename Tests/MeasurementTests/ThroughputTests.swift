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
  
  @Test func `Elements Per Second as Publisher`() {
    let currentValueSubject = CurrentValueSubject<String, Never>("")
    let currentValuePublisher = CurrentValuePublisher(currentValueSubject)
    
    let outerLocal: Int = 10
    let (_, tCurrentValueSubject) = performMeasuredAction(count: outerLocal) { // reference measurement
      for _ in 0..<inner {
        currentValueSubject.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }
          .sink { _ in }
          .store(in: bag)
      }
    }

    let (_, tCurrentValueSubjectErased) = performMeasuredAction(count: outerLocal) { // reference measurement
      for _ in 0..<inner {
        currentValueSubject.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.eraseToAnyPublisher()
          .sink { _ in }
          .store(in: bag)
      }
    }

    let (_, tValuePublisher) = performMeasuredAction(count: outerLocal) {
      for _ in 0..<inner {
        currentValuePublisher.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }
          .sink { _ in }
          .store(in: bag)
      }
    }
    
    let totalIterations = Double(outerLocal * inner)
    
    let thCurrentValueSubject = totalIterations * (1000 / tCurrentValueSubject)
    let thCurrentValueSubjectErased = totalIterations * (1000 / tCurrentValueSubjectErased)
    let thValuePublisher = totalIterations * (1000 / tValuePublisher)
    
    printTable("Elements Per Second as Publisher",
               decimalDigits: 0,
               rows: [("CurrentValueSubject time", tCurrentValueSubject),
                      ("CurrentValueSubject throughput", thCurrentValueSubject),
                      ("  CurrentValueSubjectErased time", tCurrentValueSubjectErased),
                      ("  CurrentValueSubjectErased throughput", thCurrentValueSubjectErased),
                      ("ValuePublisher time", tValuePublisher),
                      ("ValuePublisher throughput", thValuePublisher)])
  }
  
  /// Measures and compares throughput (elements per second) when sending
  /// values with and without active subscribers.
  ///
  /// What is compared:
  /// - `CurrentValueSubject`: Standard Combine subject
  /// - `VersionedValueRelay`: StateFusion's thread-safe relay with versioning
  ///
  /// What measured in common:
  /// - Time to send `inner` (1000) values, repeated `outer` (1000) times
  /// - Both publishers have with single subscriber attached (via `sink`) and without subscriber.
  ///
  /// The test reveals throughput differences between the two publisher types
  /// under identical workloads, highlighting the overhead of relay
  /// synchronization mechanisms.
  @Test func `Elements Per Second Direct`() {
    `Elements Per Second Direct`(withSubscriber: false)
    `Elements Per Second Direct`(withSubscriber: true)
  }
  
  private func `Elements Per Second Direct`(withSubscriber: Bool) {
    let currentValueSubject = CurrentValueSubject<Int, Never>(0)
    let versionedValueRelay = InsulatedVersionedValueRelay<Int>(_value: 0)
    
    if withSubscriber {
      bag.insert {
        currentValueSubject.sink { _ in }
        versionedValueRelay.sink { _ in }
      }
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

    printTable("Elements Per Second " + (withSubscriber ? "With Subscriber" : "No Subscriber"),
               decimalDigits: 0,
               rows: [("CurrentValueSubject", thCurrentValueSubject),
                      ("VersionedValueRelay", thVersionedValueRelay)])
  }
}
