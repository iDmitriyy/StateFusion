//
//  PublishedState+FilterReducing.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 30.05.2026.
//

public import Combine

// MARK: FilterReducing operator

extension Publisher where Failure == Never {
  public func filter<State>(
    reducing publishedState: borrowing PublishedState<State>,
    reduce: sending @escaping (_ state: borrowing State, borrowing Output) -> sending EventOutcome<State, Void>,
  )
    -> AnyPublisher<Output, Failure> {
    _filterReducing(state: publishedState, reduce: reduce)
      .map { output, _ in output }
      .eraseToAnyPublisher()
    // FIXME: - + share()
  }

  public func filter<State, ReductionOutput>(
    reducing publishedState: borrowing PublishedState<State>,
    output _: ReductionOutput.Type,
    reduce: sending @escaping (_ state: borrowing State, borrowing Output) -> sending EventOutcome<State, ReductionOutput>,
  )
    -> AnyPublisher<(Output, ReductionOutput), Failure> {
    _filterReducing(state: publishedState, reduce: reduce)
    // FIXME: - + share()
  }
}

extension Publisher where Failure == Never {
  
}

extension Publisher where Failure == Never {
  
}
