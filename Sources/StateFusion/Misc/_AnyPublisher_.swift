//
//  _AnyPublisher_.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 17.07.2026.
//

public import Combine

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
