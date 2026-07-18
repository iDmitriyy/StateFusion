//
//  ValuePublisher+Merge.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

public import Combine

// MARK: - Merge

extension CurrentValuePublisher {
  public func merge(with other: some Publisher<Output, Failure>) -> CurrentValuePublisher<Output, Failure> {
    let merge = Publishers.Merge(self, other)
    return CurrentValuePublisher(retained_unverifiedValuePublisher: merge)
  }
}

extension Publisher {
  public func merge(with other: CurrentValuePublisher<Output, Failure>) -> CurrentValuePublisher<Output, Failure> {
    other.merge(with: self)
  }
}
