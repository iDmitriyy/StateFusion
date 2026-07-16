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

public struct _AnyPublisher_<Output, Failure: Error>: CustomStringConvertible, CustomPlaygroundDisplayConvertible {
  @usableFromInline
  internal let box: PublisherBoxBase<Output, Failure>

  /// Creates a type-erasing publisher to wrap the provided publisher.
  ///
  /// - Parameter publisher: A publisher to wrap with a type-eraser.
  @inlinable
  public init<PublisherType: Publisher>(_ publisher: PublisherType)
    where Output == PublisherType.Output, Failure == PublisherType.Failure {
    // If this has already been boxed, avoid boxing again
    if let erased = publisher as? _AnyPublisher_<Output, Failure> {
      box = erased.box
    } else {
      box = PublisherBox(base: publisher)
    }
  }

  public var description: String {
    "AnyPublisher"
  }

  public var playgroundDescription: Any {
    description
  }
}

extension _AnyPublisher_: Publisher {
  /// This function is called to attach the specified `Subscriber` to this `Publisher`
  /// by `subscribe(_:)`
  ///
  /// - SeeAlso: `subscribe(_:)`
  /// - Parameters:
  ///     - subscriber: The subscriber to attach to this `Publisher`.
  ///                   once attached it can begin to receive values.
  @inlinable
  public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure {
    box.receive(subscriber: subscriber)
  }
}

/// A type-erasing base class. Its concrete subclass is generic over the underlying
/// publisher.
@usableFromInline
internal class PublisherBoxBase<Output, Failure: Error>: Publisher {
  @inlinable
  internal init() {}

  @usableFromInline
  internal func receive<Downstream: Subscriber>(subscriber _: Downstream)
    where Failure == Downstream.Failure, Output == Downstream.Input {
    // abstractMethod()
  }
}

@usableFromInline
internal final class PublisherBox<PublisherType: Publisher>: PublisherBoxBase<PublisherType.Output, PublisherType.Failure> {
  @usableFromInline
  internal let base: PublisherType

  @inlinable
  internal init(base: PublisherType) {
    self.base = base
    super.init()
  }

  @inlinable
  internal override func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Failure == Downstream.Failure, Output == Downstream.Input {
    base.receive(subscriber: subscriber)
  }
}
