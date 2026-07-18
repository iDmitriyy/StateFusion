//
//  ValuePublisher+Map.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 17.07.2026.
//

import Combine

extension CurrentValuePublisher {
  public func map<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher<T, Failure> {
    let map = Publishers.Map(upstream: self, transform: transform)
    return CurrentValuePublisher<T, Failure>(retained_unverifiedValuePublisher: map)
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
