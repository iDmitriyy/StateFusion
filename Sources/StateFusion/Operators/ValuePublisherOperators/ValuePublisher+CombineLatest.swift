//
//  ValuePublisher+CombineLatest.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

import Combine

extension CurrentValuePublisher {
  public func combineLatest<O>(_ other: CurrentValuePublisher<O, Failure>) -> CurrentValuePublisher<(Output, O), Failure> {
    let combineLatest = Publishers.CombineLatest(self, other)
    return CurrentValuePublisher<(Output, O), Failure>(retained_unverifiedValuePublisher: combineLatest)
  }
}
