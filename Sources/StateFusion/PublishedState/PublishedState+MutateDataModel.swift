//
//  PublishedState+MutateDataModel.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 30.05.2026.
//

public import Combine

// ⚠️ @iDmitriyy
// TODO: - что будет если два раза подряд вызывать mutate {}.mutate{}? какой будет updateReason?

// MARK: - Mutate operator

extension Publisher where Failure == Never {
  public func mutate<State>(
    dataState publishedState: borrowing PublishedState<State>,
    mutation: sending @escaping (inout GenericStateAccessHandle<State>, borrowing Output) -> sending Void,
  )
    -> AnyCancellable {
    _mutate(dataState: publishedState, mutation: mutation)
      .subscribe()
  }
  
  /// Returns `(Output, MutationOutput)` so downstream side-effects have access to the
  /// triggering event payload. Use `.map(\.1)` to discard it when unnecessary.
  public func mutate<State, MutationOutput>(
    dataState publishedState: borrowing PublishedState<State>,
    output _: MutationOutput.Type,
    mutation: sending @escaping (inout GenericStateAccessHandle<State>, borrowing Output) -> sending MutationOutput,
  )
    -> AnyPublisher<(Output, MutationOutput), Failure> {
    _mutate(dataState: publishedState, mutation: mutation)
    // FIXME: - + share()
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - Mutate StateCompound.Data

extension Publisher where Failure == Never {
  public func mutate<EnumerableState, DataState>(
    dataState publishedState: borrowing PublishedState<StateCompound<EnumerableState, DataState>>,
    mutation: sending @escaping (inout StateCompoundDataPropertyAccessHandle<EnumerableState, DataState>, borrowing Output) -> sending Void,
  )
    -> AnyCancellable {
    _mutateStateAndData(dataState: publishedState, mutation: mutation)
      .subscribe()
  }
  
  public func mutate<EnumerableState, DataState, MutationOutput>(
    dataState publishedState: borrowing PublishedState<StateCompound<EnumerableState, DataState>>,
    output _: MutationOutput.Type,
    mutation: sending @escaping (inout StateCompoundDataPropertyAccessHandle<EnumerableState, DataState>, borrowing Output) -> sending MutationOutput,
  )
    -> AnyPublisher<(Output, MutationOutput), Failure> {
    _mutateStateAndData(dataState: publishedState, mutation: mutation)
    // FIXME: - + share()
  }
}

// MARK: - Mutate StateCompound

extension Publisher where Failure == Never {
  public func mutate<EnumerableState, DataState>(
    stateCompound publishedState: borrowing PublishedState<StateCompound<EnumerableState, DataState>>,
    mutation: sending @escaping (inout StateCompoundAccessHandle<EnumerableState, DataState>, borrowing Output) -> sending Void,
  )
    -> AnyCancellable {
      _mutateStateCompound(stateCompound: publishedState, mutation: mutation)
        .subscribe()
    // FIXME: - + share()
  }
  
  public func mutate<EnumerableState, DataState, MutationOutput>(
    stateCompound publishedState: borrowing PublishedState<StateCompound<EnumerableState, DataState>>,
    output _: MutationOutput.Type,
    mutation: sending @escaping (inout StateCompoundAccessHandle<EnumerableState, DataState>, borrowing Output) -> sending MutationOutput,
  )
    -> AnyPublisher<(Output, MutationOutput), Failure> {
      _mutateStateCompound(stateCompound: publishedState, mutation: mutation)
    // FIXME: - + share()
  }
}
