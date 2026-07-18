//
//  ValuePublisher+RemoveDuplicates.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

import Combine

extension CurrentValuePublisher {
  public func removeDuplicates(by predicate: @escaping (Self.Output, Self.Output) -> Bool) -> Self {
    let removeDuplicates = Publishers.RemoveDuplicates(upstream: self, predicate: predicate)
    return Self(retained_unverifiedValuePublisher: removeDuplicates)
  }
}

extension CurrentValuePublisher where Output: Equatable {
  public func removeDuplicates() -> Self {
    self.removeDuplicates(by: ==)
  }
}
