//
//  ValuePublisher+Map.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 17.07.2026.
//

public import Combine

extension CurrentValuePublisher {
  public func map<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher<T, Failure> {
    let map = Publishers.Map(upstream: self, transform: transform)
    return CurrentValuePublisher<T, Failure>(retained_unverifiedValuePublisher: map)
  }
}

extension CurrentValuePublisher {
  public func combineLatest<P: Publisher>(_ other: P) -> CurrentValuePublisher<(Output, P.Output), Failure>
    where Self.Failure == P.Failure {
    let combineLatest = Publishers.CombineLatest(self, other)
    return CurrentValuePublisher<(Output, P.Output), Failure>(retained_unverifiedValuePublisher: combineLatest)
  }
}

extension CurrentValuePublisher {
  public func handleEvents(receiveSubscription: ((any Subscription) -> Void)? = nil,
                           receiveOutput: ((Self.Output) -> Void)? = nil,
                           receiveCompletion: ((Subscribers.Completion<Self.Failure>) -> Void)? = nil,
                           receiveCancel: (() -> Void)? = nil,
                           receiveRequest: ((Subscribers.Demand) -> Void)? = nil) -> CurrentValuePublisher<Output, Failure> {
    let handleEvents = Publishers.HandleEvents(upstream: self,
                                               receiveSubscription: receiveSubscription,
                                               receiveOutput: receiveOutput,
                                               receiveCompletion: receiveCompletion,
                                               receiveCancel: receiveCancel,
                                               receiveRequest: receiveRequest)
    return CurrentValuePublisher<Output, Failure>(retained_unverifiedValuePublisher: handleEvents)
  }
}

// public func combineLatest<P>(_ other: P) -> Publishers.CombineLatest<Self, P> where P : Publisher, Self.Failure == P.Failure
//
// public func combineLatest<P, T>(_ other: P, _ transform: @escaping (Self.Output, P.Output) -> T) -> Publishers.Map<Publishers.CombineLatest<Self, P>, T> where P : Publisher, Self.Failure == P.Failure

extension Publishers {
  struct SingleElement {}
}

/*
 ValuePublisher operators:
 map combineLatest prepend scan? merge(if oneOf is ValuePublisher) throttle? flatMap? replaceError? removeDuplicates singleElement
 zip replaceNil(with: T) mapError catch share shareReplay(1) multicast(subject:)
 eraseToAnyPublisher handleEvents breakpoint

 HotPublisher operators:
 debounce delay

 при прямой подписке (без share) removeDuplicates всегда немедленно эмитит значение, потому что каждый раз
 создаётся новый оператор без истории
 */
