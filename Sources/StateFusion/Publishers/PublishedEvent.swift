//
//  PublishedEvent.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 02.06.2026.
//

public import Combine

/// A wrapper that lets you use a PublishSubject as an Observable.
/// Use this when elements are accepted in only 1 place, but subscriptions happen in many.
/// The $ prefix makes it visually clear where elements are being passed into reactive streams.
///
/// - wrappedValue — use when you only need to observe a data stream and .accept(value) is not needed.
///   For example, in a StateTransform implementation.
/// - projectedValue — use when you need to accept values into the PublishSubject.
///   Typically, this is needed inside the interactor itself.
@propertyWrapper
public final class PublishedEvent<Output> {
  public final let wrappedValue: InfalliblePublisher<Output>

  public final var projectedValue: PublishedEvent<Output> {
    self
  }

  private let _subject = PassthroughSubject<Output, Never>()

  public init() {
    wrappedValue = _subject.eraseToAnyPublisher()
  }
  
  public final func send(_ input: Output) {
    _subject.send(input)
  }
}

//@propertyWrapper
//public final class PublishedValue<Output> {
//  public final let wrappedValue: CurrentValuePublisher<Output>
//
//  public final var projectedValue: PublishedValue<Output> {
//    self
//  }
//
//  private let _subject: InfallibleValueSubject<Output>
//
//  public init(initial: Output) {
//    _subject = InfallibleValueSubject<Output>(initial)
//    wrappedValue = _subject.eraseToAnyPublisher()
//  }
//  
//  public final func send(_ input: Output) {
//    _subject.send(input)
//  }
//}
