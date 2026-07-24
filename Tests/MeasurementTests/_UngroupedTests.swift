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

  @Test func `Result Forwarding`() {
    struct Responses {
      @PublishedEvent var didLoadData: AnyInfalliblePublisher<String>
      @PublishedEvent var dataLoadingError: AnyInfalliblePublisher<any Error>
    }

    let successSubject = PassthroughSubject<String, Never>()
    let failureSubject = PassthroughSubject<any Error, Never>()

    let responses = Responses()

    let _didLoadData = PublishedEvent<String>() // responses.$didLoadData
    let _dataLoadingError = PublishedEvent<any Error>() // responses.$dataLoadingError

    let result = Result<String, any Error>.success("success")

    let (_, tSubject) = performMeasuredAction(count: outer) {
      for _ in 0..<(inner * 10) {
        result.forward(successTo: successSubject, failureTo: failureSubject)
      }
    }

    let (_, tPublishedEvent) = performMeasuredAction(count: outer) {
      for _ in 0..<(inner * 10) {
        result.forward(successTo: responses.$didLoadData,
                       failureTo: responses.$dataLoadingError)
      }
    }

    let (_, tPublishedEvent_) = performMeasuredAction(count: outer) {
      for _ in 0..<(inner * 10) {
        result.forward(successTo: _didLoadData,
                       failureTo: _dataLoadingError)
      }
    }

    // PublishedEvent implemented as class:
    // to Subject          232
    // to PublishedEvent   435
    // to PublishedEvent_  239

    // PublishedEvent implemented as struct:
    // to Subject          231
    // to PublishedEvent   599
    // to PublishedEvent_  239

    printTable("Result Forwarding",
               rows: [
                 ("to Subject", tSubject),
                 ("to PublishedEvent", tPublishedEvent),
                 ("to PublishedEvent_", tPublishedEvent_),
               ])
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

  @Test func `Denestify Inlined vs Not Inlined`() {
    if #available(macOS 26.0, *) {
      // 1. Setup mock data that changes slightly to keep the compiler honest
      var tuple = ((("String_A", "String_B"), "String_C"), Duration(attoseconds: 10))
      var preDenestified = denestify(tuple: tuple)
      let inner = Int128(inner * 10)

      // 2. Measure Baseline (Just passing the pre-flattened tuple)
      let (_, tBaseline) = performMeasuredAction(count: outer) {
        for i in 0..<inner {
          // Mutate a small property to prevent loop-invariant code motion
          preDenestified.3 = Duration(attoseconds: i)
          blackHole(preDenestified)
        }
      }

      // 3. Measure Inlined Execution Profile
      let (_, tInlined) = performMeasuredAction(count: outer) {
        for i in 0..<inner {
          tuple.1 = Duration(attoseconds: i)
          blackHole(denestify(tuple: tuple))
        }
      }

      // 4. Measure Non-Inlined Execution Profile
      let (_, tNoInlining) = performMeasuredAction(count: outer) {
        for i in 0..<inner {
          tuple.1 = Duration(attoseconds: i)
          blackHole(denestify_noInlining(tuple: tuple))
        }
      }

      // 5. Explicitly calculate the clean delta
      let overheadOfCallStack = (tNoInlining - tBaseline) - (tInlined - tBaseline)

      // 6. Print Values
      printTable("Denestify Performance",
                 rows: [
                   ("  Baseline (no op)", tBaseline),
                   ("  Denestify (inlined)", tInlined),
                   ("  Denestify (noInlining)", tNoInlining),
                   ("Delta: Inlined - Baseline", tInlined - tBaseline),
                   ("Delta: NoInlining - Baseline", tNoInlining - tBaseline),
                   ("Function Call Overhead", overheadOfCallStack),
                 ])
    }
  }
}

@inline(never)
internal func denestify_noInlining<A, B, C, D>(tuple: (((A, B), C), D)) -> (A, B, C, D) {
  let (((a, b), c), d) = tuple
  return (a, b, c, d)
}
