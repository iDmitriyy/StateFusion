//
//  GetValueTests.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 23.07.2026.
//

@_spi(PerformanceMeasuring) import StateFusion
import Testing

struct GetValueTests {
  let outer: Int = 1000
  let inner: Int = 1000

  @Test func `Get Value Sync`() {
    if #available(macOS 26.0, *) {
      let dataState = DataState_SendableExample()
      let currentValueSubject = CurrentValueSubject<_, Never>(dataState)
      let versionedValueRelay = InsulatedVersionedValueRelay(_value: dataState)
      let publishedState = PublishedState(dataState)

      let (_, tCurrentValueSubject) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          blackHole(currentValueSubject.value)
        }
      }

      let (_, tVersionedValueRelay) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          blackHole(versionedValueRelay.test_get_value)
        }
      }

      let (_, tPublishedState) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          blackHole(publishedState.withLockReadOnlyAccess { $0.stateEntity })
        }
      }

      let (_, tPublishedStateSnapshot) = performMeasuredAction(count: outer) {
        for _ in 0..<inner {
          blackHole(publishedState.snapshot)
        }
      }

      let totalIterations = Double(outer * inner)

      let thCurrentValueSubject = totalIterations * (1000 / tCurrentValueSubject)
      let thVersionedValueRelay = totalIterations * (1000 / tVersionedValueRelay)
      let thPublishedState = totalIterations * (1000 / tPublishedState)
      let thPublishedStateSnapshot = totalIterations * (1000 / tPublishedStateSnapshot)

      printTable("Elements Per Second as Publisher",
                 decimalDigits: 0,
                 rows: [("CurrentValueSubject time", tCurrentValueSubject),
                        ("VersionedValueRelay time", tVersionedValueRelay),
                        ("PublishedState time", tPublishedState),
                        ("PublishedStateSnapshot time", tPublishedStateSnapshot),
                        (" CurrentValueSubject throughput", thCurrentValueSubject),
                        (" VersionedValueRelay throughput", thVersionedValueRelay),
                        (" PublishedState throughput", thPublishedState),
                        (" PublishedStateSnapshot throughput", thPublishedStateSnapshot)])
    }
  }
}
