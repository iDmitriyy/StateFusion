//
//  InfalliblePublisher.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 02.06.2026.
//

public import Combine

//public typealias EventPublisher<Output> = AnyPublisher<Output, Never>

public typealias InfalliblePublisher<Output> = Publisher<Output, Never> // ?? Publisher<Output, Never>

// TODO: - make another erasure type, if there is more performant one
public typealias AnyInfalliblePublisher<Output> = AnyPublisher<Output, Never>

// Driver:
// -> CurrentValuePublisher -> DriverPublisher | InfallibleDataStream
// continuous-value vs discrete-event
// Signal:
// -> PassthroughPublisher -> SignalPublisher | InfallibleEventStream

// // UIEventStream : UIEventPublisher

// InfallibleValuePublisher

/*
 In RxSwift, these UI Traits serve three core purposes:
 1. they guarantee execution on the MainScheduler
 2. prevent streams from erroring out
 3. control state replaying (Driver replays the last value, while Signal does not).
 */
