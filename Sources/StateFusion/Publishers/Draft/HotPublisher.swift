//
//  HotPublisher.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.06.2026.
//

import Combine

func hotPublisher<T>(source: AnyPublisher<T, Never>,
                        initialValue: T) -> AnyPublisher<T, Never> {
  let subject = CurrentValueSubject<T, Never>(initialValue)

  let cancellable = source
    .sink { subject.send($0) }

  // Must store cancellable to keep upstream alive!
  return subject
    .handleEvents(receiveCancel: { cancellable.cancel() })
    .eraseToAnyPublisher()
}

final class HotPublisher<T> {
    private let subject: CurrentValueSubject<T, Never>
    private var cancellable: AnyCancellable?
    
    init(sources: [AnyPublisher<T, Never>], initialValue: T) {
        subject = CurrentValueSubject<T, Never>(initialValue)
        cancellable = Publishers.MergeMany(sources)
            .sink { [subject] in subject.send($0) }
    }
    
    var publisher: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }
}

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
