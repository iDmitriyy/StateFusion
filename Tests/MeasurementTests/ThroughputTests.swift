//
//  ThroughputTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 17.06.2026.
//

@_spi(PerformanceMeasuring) import StateFusion
import Testing

/// See also: `CreateOperatorsChainTests`
struct ThroughputTests: ~Copyable {
  let outer: Int = 1000
  let inner: Int = 1000

  let bag = CancellationBag()

  @Test func `Elements Per Second as Publisher`() {
    let currentValueSubject = CurrentValueSubject<Int, Never>(0)
    let currentValueSubjectErased = CurrentValueSubject<Int, Never>(0)
    
    let imp_currentSubj = CurrentValueSubject<Int, Never>(0)
    let imp_current = CurrentValuePublisher(imp_currentSubj)
    
    let imp_ExistentialSubj = CurrentValueSubject<Int, Never>(0)
    let imp_Existential = CurrentValuePublisher_Existential(retained_unverifiedValuePublisher: imp_ExistentialSubj)
    
    let imp_ClosureSubj = CurrentValueSubject<Int, Never>(0)
    let imp_Closure = CurrentValuePublisher_Closure(retained_unverifiedValuePublisher: imp_ClosureSubj)
    
    let imp_PointerSubj = CurrentValueSubject<Int, Never>(0)
    let imp_Pointer = CurrentValuePublisher_Pointer(retained_unverifiedValuePublisher: imp_PointerSubj)
    
    let imp_PointerInlineSubj = CurrentValueSubject<Int, Never>(0)
    let imp_PointerInline = CurrentValuePublisher_Inline(retained_unverifiedValuePublisher: imp_PointerInlineSubj)
    
    let imp_AnyObjCastSubj = CurrentValueSubject<Int, Never>(0)
    let imp_AnyObjCast = CurrentValuePublisher_AnyObjCast(retained_unverifiedValuePublisher: imp_AnyObjCastSubj)
    
    // TODO: add chain length: 0, 1, 5
    // - use specific map / map2 operators

    bag.insert {
      currentValueSubject
        .map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.sink { _ in }
      
      currentValueSubjectErased.eraseToAnyPublisher()
        .map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.sink { _ in }
      
      imp_current
        .map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.sink { _ in }
      
      imp_Existential
        .map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.sink { _ in }
      
      imp_Closure
        .map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.sink { _ in }
      
      imp_Pointer
        .map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.sink { _ in }
      
      imp_PointerInline
        .map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.sink { _ in }
      
      imp_AnyObjCast.map { $0 }
        .map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.sink { _ in }
    }
    
    let (_, tCurrentValueSubject) = performMeasuredAction(count: outer) { // reference measurement
      for i in 0..<inner {
        currentValueSubject.send(i)
      }
    }

    let (_, tCurrentValueSubjectErased) = performMeasuredAction(count: outer) { // reference measurement
      for i in 0..<inner {
        currentValueSubjectErased.send(i)
      }
    }

    let (_, tImp_current) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        imp_currentSubj.send(i)
      }
    }

    let (_, tImp_Existential) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        imp_ExistentialSubj.send(i)
      }
    }

    let (_, tImp_Closure) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        imp_ClosureSubj.send(i)
      }
    }

    let (_, tImp_Pointer) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        imp_PointerSubj.send(i)
      }
    }

    let (_, tImp_PointerInline) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        imp_PointerInlineSubj.send(i)
      }
    }
    
    let (_, tImp_AnyObjCast) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        imp_AnyObjCastSubj.send(i)
      }
    }

    let totalIterations = Double(outer * inner)

    let thCurrentValueSubject = totalIterations * (1000 / tCurrentValueSubject)
    let thCurrentValueSubjectErased = totalIterations * (1000 / tCurrentValueSubjectErased)

    let thImp_current = totalIterations * (1000 / tImp_current)
    let thImp_Existential = totalIterations * (1000 / tImp_Existential)
    let thImp_Closure = totalIterations * (1000 / tImp_Closure)
    let thImp_Pointer = totalIterations * (1000 / tImp_Pointer)
    let thImp_PointerInline = totalIterations * (1000 / tImp_PointerInline)
    let thImp_AnyObjCast = totalIterations * (1000 / tImp_AnyObjCast)

    printTable("Elements Per Second as Publisher",
               rows: [("  CurrentValueSubject time", tCurrentValueSubject),
                      ("  CurrentValueSubjectErased time", tCurrentValueSubjectErased),
                      ("  Imp_current time", tImp_current),
                      ("  Imp_Existential time", tImp_Existential),
                      ("  Imp_Closure time", tImp_Closure),
                      ("  Imp_Pointer time", tImp_Pointer),
                      ("  Imp_PointerInline time", tImp_PointerInline),
                      ("  Imp_AnyObjCast time", tImp_AnyObjCast),

                      ("CurrentValueSubject throughput", thCurrentValueSubject),
                      ("CurrentValueSubjectErased throughput", thCurrentValueSubjectErased),
                      ("Imp_current throughput", thImp_current),
                      ("Imp_Existential throughput", thImp_Existential),
                      ("Imp_Closure throughput", thImp_Closure),
                      ("Imp_Pointer throughput", thImp_Pointer),
                      ("Imp_PointerInline throughput", thImp_PointerInline),
                      ("AnyObjCast throughput", thImp_AnyObjCast)])
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
    let publishedState = PublishedState<Int>(0)
    
    // let publishedStateEnumerable = PublishedState()
    // let enumerableStatePublisher = publishedStateEnumerable.asEnumerableStatePublisher()
    
    if withSubscriber {
      bag.insert {
        currentValueSubject.sink { _ in }
        versionedValueRelay.sink { _ in }
        publishedState.asPublisher().sink { _ in }
        
        // TODO: - + publishedState enumerableStatePublisher & dataStatePublisher
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
    
    let (_, msPublishedState) = performMeasuredAction(count: outer) {
      for i in 0..<inner {
        publishedState.withLockEmittingOnMutableAccess { $0.stateEntity = i }
      }
    }

    let totalIterations = Double(outer * inner)

    let thCurrentValueSubject = totalIterations * (1000 / msCurrentValueSubject)
    let thVersionedValueRelay = totalIterations * (1000 / msVersionedValueRelay)
    let thPublishedState = totalIterations * (1000 / msPublishedState)

    printTable("Elements Per Second " + (withSubscriber ? "With Subscriber" : "No Subscriber"),
               rows: [("CurrentValueSubject", thCurrentValueSubject),
                      ("VersionedValueRelay", thVersionedValueRelay),
                      ("PublishedState", thPublishedState),
                     ])
  }
}
