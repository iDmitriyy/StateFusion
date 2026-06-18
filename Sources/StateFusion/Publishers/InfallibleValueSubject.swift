//
//  InfallibleValueSubject.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 15.06.2026.
//

public import Combine

/// Owned
public struct OwnedInfallibleValueSubject<Output>: ~Copyable {}

//

public final class InfallibleValueSubject<Output>: Subject<Output, Never> {
  internal let _subject: CurrentValueSubject<SequentialSnapshot<Output>, Never>
  private let _version: RecursiveLock<UInt32>

  public final var valueSnapshot: SequentialSnapshot<Output> {
    _subject.value
  }

  public final var value: Output {
    _subject.value.value
  }

  // https://github.com/ReactiveX/RxSwift/blob/132aea4f236ccadc51590b38af0357a331d51fa2/RxSwift/Rx.swift#L71

  public init(_ value: Output) {
    let initial = SequentialSnapshot(initial: value)
    _version = RecursiveLock(initial._version)
    _subject = CurrentValueSubject(initial)
  }

  // Publisher Protocol Imp:

  public final func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Output {
    _subject
      .map { snapshot in snapshot.value }
      .receive(subscriber: subscriber)
  }

  // Subject Protocol Imp:

  public final func send(_ value: Output) {
    _version.withLock { current in
      current += 1
      _subject.send(SequentialSnapshot(value: value, version: current))
    }
  }

  public final func send(completion: Subscribers.Completion<Failure>) {
    _subject.send(completion: completion)
  }

  public final func send(subscription: any Subscription) {
    _subject.send(subscription: subscription)
  }
}

extension InfallibleValueSubject {
  public final func valuePublisher() -> InfallibleValuePublisher<Output> {
    fatalError()
  }
  
  public final func takeUpdates(afterSnapshot snapshot: SequentialSnapshot<Output>) -> AnyPublisher<Output, Never> {
    _subject.drop(while: { [referenceVersion = snapshot._version] in
      $0._version <= referenceVersion
    })
    .map { $0.value }
    .eraseToAnyPublisher()
    // FIXME: + share
  }
}
