//
//  PublishedState+FilterBy.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 30.05.2026.
//

public import Combine

// MARK: - FilterBy State

extension Publisher where Output == Void, Failure == Never {
  public func filter<State, EvaluationOutput>(
    by publishedState: borrowing PublishedState<State>,
    output _: EvaluationOutput.Type = EvaluationOutput.self,
    where evaluate: sending @escaping (borrowing State) -> sending EventFilteringResult<State, EvaluationOutput>,
  )
    -> some Publisher<EvaluationOutput, Failure> {
    _filterBy(state: publishedState, evaluate: evaluate)
      .map { _, evaluationOutput in evaluationOutput }
    // FIXME: - + share()
  }
}

extension Publisher where Failure == Never {
  public func filter<State>(
    by publishedState: borrowing PublishedState<State>,
    where evaluate: sending @escaping (borrowing State) -> sending EventFilteringResult<State, Void>,
  )
    -> some Publisher<Output, Failure> {
    _filterBy(state: publishedState, evaluate: evaluate)
      .map { output, _ in output }
    // FIXME: - + share()
  }

  public func filter<State, EvaluationOutput>(
    by publishedState: borrowing PublishedState<State>,
    output _: EvaluationOutput.Type,
    where evaluate: sending @escaping (borrowing State) -> sending EventFilteringResult<State, EvaluationOutput>,
  )
    -> some Publisher<(Output, EvaluationOutput), Failure> {
    _filterBy(state: publishedState, evaluate: evaluate)
    // FIXME: - + share()
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - FilterBy StateAndData.State

extension Publisher where Failure == Never {
  
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - FilterBy StateAndData

extension Publisher where Failure == Never {
  
}
