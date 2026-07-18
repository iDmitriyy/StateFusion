//
//  ValuePublisher+HandleEvents.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.07.2026.
//

public import Combine

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
