//
//  InfalliblePublisher.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 02.06.2026.
//

public import Combine

//public typealias EventPublisher<Output> = AnyPublisher<Output, Never>

public typealias InfalliblePublisher<Output> = Publisher<Output, Never> // ?? Publisher<Output, Never>

public typealias AnyInfalliblePublisher<Output> = AnyPublisher<Output, Never>

// Driver:
// -> CurrentValuePublisher -> DriverPublisher | InfallibleDataStream
// continuous-value vs discrete-event
// Signal:
// -> PassthroughPublisher -> SignalPublisher | InfallibleEventStream

// // UIEventStream : UIEventPublisher

// InfallibleValuePublisher
