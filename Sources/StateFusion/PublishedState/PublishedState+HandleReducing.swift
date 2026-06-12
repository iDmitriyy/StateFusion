//
//  PublishedState+HandleReducing.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 30.05.2026.
//

public import Combine

// MARK: - HandleReducing operator

extension Publisher where Failure == Never {
  public func handle<State>(
    reducing publishedState: borrowing PublishedState<State>,
    reduce: sending @escaping (_ state: borrowing State, borrowing Output) -> sending EventReducingResult<State>,
  )
    -> AnyCancellable {
    _handleReducing(state: publishedState, reduce: reduce)
  }
}

extension Publisher where Failure == Never {
  
}

extension Publisher where Failure == Never {
  
}
