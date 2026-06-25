//
//  OwnedPublisher.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 20.06.2026.
//

//public import Combine

//public protocol OwnedPublisher<Output, Failure>: ~Copyable {
//    /// The kind of values published by this publisher.
//    associatedtype Output
//
//    /// The kind of errors this publisher might publish.
//    ///
//    /// Use `Never` if this `Publisher` does not publish errors.
//    associatedtype Failure: Error
//  
//    func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input
//}
//
//
//public protocol OwnedRelay: OwnedPublisher, ~Copyable where Failure == Never {
//    associatedtype Output
//
//    /// Relays a value to the subscriber.
//    ///
//    /// - Parameter value: The value to send.
//    func accept(_ value: Output)
//
//    /// Attaches the specified publisher to this relay.
//    ///
//    /// - parameter publisher: An infallible publisher with the relay's Output type
//    ///
//    /// - returns: `AnyCancellable`
//    func subscribe<P: Publisher>(_ publisher: P) -> AnyCancellable where P.Failure == Failure, P.Output == Output
//}
//
//@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
//public extension Publisher where Failure == Never {
//    /// Attaches the specified relay to this publisher.
//    ///
//    /// - parameter relay: Relay to attach to this publisher
//    ///
//    /// - returns: `AnyCancellable`
//    func subscribe<R: Relay>(_ relay: R) -> AnyCancellable where R.Output == Output {
//        relay.subscribe(self)
//    }
//}
//
//@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
//public extension Relay where Output == Void {
//    /// Relay a void to the subscriber.
//    func accept() {
//        accept(())
//    }
//}
