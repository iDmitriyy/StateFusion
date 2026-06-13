//
//  InfalliblePublisher.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 02.06.2026.
//

public import Combine

public typealias EventPublisher<Output> = AnyPublisher<Output, Never>

// Driver:
// -> CurrentValuePublisher -> DriverPublisher | InfallibleDataStream

// Signal:
// -> PassthroughPublisher -> SignalPublisher | InfallibleEventStream

// // UIEventStream : UIEventPublisher
