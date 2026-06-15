//
//  InfallibleValueSubject.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 15.06.2026.
//

public import Combine

public final class InfallibleValueSubject<Output>: Subject<Output, Never> {
  internal let _subject: CurrentValueSubject<SequentialSnapshot<Output>, Never>
  
  init(_ value: Output) {
    self._subject = CurrentValueSubject(SequentialSnapshot(initial: value))
  }
  
  public final func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, S.Input == Output {
    
  }
  
  public final func send(_ value: Output) {
    
  }
  
  public final func send(completion: Subscribers.Completion<Failure>) {
    _subject.send(completion: completion)
  }
  
  public final func send(subscription: any Subscription) {
    _subject.send(subscription: subscription)
  }
}
