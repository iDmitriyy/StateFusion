//
//  HotPublisher.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.06.2026.
//

import Combine

func latestPublisher<T>(source: AnyPublisher<T, Never>,
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
