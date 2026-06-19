//
//  PublishedState+OperatorImps.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 31.05.2026.
//

import Combine

enum Owning<T: AnyObject> {
  case retained(T)
  case borrowed(Weak<T>)
}

struct Weak<T: AnyObject> {
  weak let instance: T?
}

extension Publisher where Failure == Never {
  // MARK: -  _filterBy

  // State :

  internal func _filterBy<State, EvaluationOutput>(
    state publishedState: borrowing PublishedState<State>,
    evaluate: sending @escaping (_ state: borrowing State) -> sending EventFilteringResult<State, EvaluationOutput>,
  )
    -> AnyPublisher<(Output, EvaluationOutput), Failure> {
    compactMap { [weak publishedState = publishedState._stateImpObject] element -> (Output, EvaluationOutput)? in
      guard let publishedState else {
        assertionFailure(_publishedStateDeallocationAssertMessage(output: Output.self, state: State.self))
        return nil
      }

      // evaluationOutput is typically an associated value from old state
      let evaluationOutput: EvaluationOutput? = publishedState.withLockAccess {
        let eventFilteringResult = evaluate($0)
        switch consume eventFilteringResult {
        case let .handled(eventFilteringOutput):
          return eventFilteringOutput

        case .ignore:
          return nil
        }
      }

      if let evaluationOutput {
        return (element, evaluationOutput)
      } else {
        return nil
      }
    }
    .eraseToAnyPublisher()
  }

  // State of StateAndData :

  internal func _filterBy<State, EvaluationOutput>(
    stateAndDataState publishedState: borrowing PublishedState<StateCompound<State, some Any>>,
    output _: EvaluationOutput.Type = EvaluationOutput.self,
    where evaluate: sending @escaping (borrowing State) -> sending EventFilteringResult<State, EvaluationOutput>,
  )
    -> AnyPublisher<(Output, EvaluationOutput), Failure> {
    compactMap { [weak publishedState = publishedState._stateImpObject] element -> (Output, EvaluationOutput)? in
      guard let publishedState else {
        assertionFailure(_publishedStateDeallocationAssertMessage(output: Output.self, state: State.self))
        return nil
      }

      // evaluationOutput is typically an associated value from old state
      let evaluationOutput: EvaluationOutput? = publishedState.withLockAccess {
        let eventFilteringResult = evaluate($0.state)
        switch consume eventFilteringResult {
        case let .handled(eventFilteringOutput):
          return eventFilteringOutput

        case .ignore:
          return nil
        }
      }

      if let evaluationOutput {
        return (element, evaluationOutput)
      } else {
        return nil
      }
    }
    .eraseToAnyPublisher()
  }

  // StateAndData :

  internal func _filterBy<State, DataState, EvaluationOutput>(
    stateAndData _: borrowing PublishedState<StateCompound<State, DataState>>,
    output _: EvaluationOutput.Type = EvaluationOutput.self,
    where _: sending @escaping (borrowing StateCompound<State, DataState>) -> sending EventFilteringResult<State, EvaluationOutput>,
  )
    -> AnyPublisher<(Output, EvaluationOutput), Failure> {
    fatalError()
  }

  //===-------------------------------------------------------------------------------------------------------------------===//

  // MARK: - _filterReducing

  internal func _filterReducing<State, ReductionOutput>(
    state publishedState: borrowing PublishedState<State>,
    reduce: sending @escaping (_ state: borrowing State, borrowing Output) -> sending EventOutcome<State, ReductionOutput>,
  )
    -> AnyPublisher<(Output, ReductionOutput), Failure> {
    compactMap { [weak publishedState = publishedState._stateImpObject] element -> (Output, ReductionOutput)? in
      guard let publishedState else {
        assertionFailure(_publishedStateDeallocationAssertMessage(output: Output.self, state: State.self))
        return nil
      }

      // `reductionOutput` is typically an associated value from old state
      let reductionOutput: ReductionOutput? = publishedState.withLockMutableAccess {
        let eventOutcome = reduce($0.stateEntity, element)
        switch consume eventOutcome {
        case let .transition(newState, reductionOutput):
          $0.stateEntity = newState
          return reductionOutput

        case let .handled(reductionOutput):
          return reductionOutput

        case .ignore:
          return nil
        }
      }

      if let reductionOutput {
        return (element, reductionOutput)
      } else {
        return nil
      }
    }
    .eraseToAnyPublisher()
  }

  //===-------------------------------------------------------------------------------------------------------------------===//

  // MARK: -  _handleReducing

  internal func _handleReducing<State>(
    state publishedState: borrowing PublishedState<State>,
    reduce: sending @escaping (_ state: borrowing State, borrowing Output) -> sending EventReducingResult<State>,
  )
    -> AnyCancellable {
    sink(receiveValue: { [weak publishedState = publishedState._stateImpObject] element in
      guard let publishedState else {
        assertionFailure(_publishedStateDeallocationAssertMessage(output: Output.self, state: State.self))
        return
      }

      // `reductionOutput` is typically an associated value from old state
      publishedState.withLockMutableAccess {
        let eventOutcome = reduce($0.stateEntity, element)
        switch consume eventOutcome {
        case let .transition(newState):
          $0.stateEntity = newState

        case .ignore:
          break
        }
      }
    })
  }

  //===-------------------------------------------------------------------------------------------------------------------===//

  // MARK: -  _mutate dataState

  // TODO: - sending MutationOutput | sending Void – no need to be sending, rx streams allow pass nonSendable values
  // However, it might be good to push sendable values via rx streams, so MutationOutput should be constrained to Sendable.
  // In practice, all of them are typically sendable. For other cases, make _unsafe operators.

  internal func _mutate<DataState, MutationOutput>(
    dataState publishedState: borrowing PublishedState<DataState>,
    mutation: sending @escaping (inout GenericStateAccessHandle<DataState>, borrowing Output) -> sending MutationOutput,
  )
    -> AnyPublisher<(Output, MutationOutput), Failure> {
    compactMap { [weak publishedState = publishedState._stateImpObject] element -> (Output, MutationOutput)? in
      guard let publishedState else {
        assertionFailure(_publishedStateDeallocationAssertMessage(output: Output.self, state: DataState.self))
        return nil
      }

      let mutationOutput: MutationOutput = publishedState.withLockMutableAccess {
        mutation(&$0, element)
      }

      return (element, mutationOutput)
    }
    .eraseToAnyPublisher()
  }

  // DataState of StateAndData :

  internal func _mutateStateAndData<EnumerableState, DataState, MutationOutput>(
    dataState publishedState: borrowing PublishedState<StateCompound<EnumerableState, DataState>>,
    mutation: sending @escaping (inout StateCompoundDataPropertyAccessHandle<EnumerableState, DataState>, borrowing Output) -> sending MutationOutput,
  )
    -> AnyPublisher<(Output, MutationOutput), Failure> {
    compactMap { [weak publishedState = publishedState._stateImpObject] element -> (Output, MutationOutput)? in
      guard let publishedState else {
        assertionFailure(_publishedStateDeallocationAssertMessage(output: Output.self,
                                                                  state: StateCompound<EnumerableState, DataState>.self))
        return nil
      }

      let mutationOutput: MutationOutput = publishedState.withLockMutableAccessDataState {
        mutation(&$0, element)
      }

      return (element, mutationOutput)
    }
    .eraseToAnyPublisher()
  }

  // DataState of StateAndData :

  internal func _mutateStateCompound<EnumerableState, DataState, MutationOutput>(
    stateCompound publishedState: borrowing PublishedState<StateCompound<EnumerableState, DataState>>,
    mutation: sending @escaping (inout StateCompoundAccessHandle<EnumerableState, DataState>, borrowing Output) -> sending MutationOutput,
  )
    -> AnyPublisher<(Output, MutationOutput), Failure> {
    // 1. Only state mutated
    // 2. Only dataState mutated
    // 3. Both mutated

    compactMap { [weak publishedState = publishedState._stateImpObject] element -> (Output, MutationOutput)? in
      guard let publishedState else {
        assertionFailure(_publishedStateDeallocationAssertMessage(output: Output.self,
                                                                  state: StateCompound<EnumerableState, DataState>.self))
        return nil
      }

      let mutationOutput: MutationOutput = publishedState.withLockMutableAccessStateCompound {
        mutation(&$0, element)
      }

      return (element, mutationOutput)
    }
    .eraseToAnyPublisher()
  }
}

@inline(never)
fileprivate func _publishedStateDeallocationAssertMessage<Output, State>(output _: Output.Type, state _: State.Type) -> String {
  "Lifecycle Mismatch: `PublishedState<\(State.self)>` was deallocated while the reactive pipeline " +
    "derived from `Publisher<\(Output.self)>` was still active. The upstream publisher has outlived " +
    "the owner of the PublishedState. Ensure this subscription is properly cancelled when its owner deinitializes."
}
