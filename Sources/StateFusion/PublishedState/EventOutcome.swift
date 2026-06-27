//
//  EventOutcome.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 30.05.2026.
//

// MARK: - EventOutcome

/// The result of evaluating an upstream event against the current state.
///
/// `EventOutcome` models how a state machine responds to a specific event based on its
/// current context. It encapsulates both data filtering (whether the event is allowed through)
/// and state mutations (whether a transition occurs).
public enum EventOutcome<State, Output>: ~Copyable {
  // reduce => event ignored
  // reduce => extractData, eventAllowed
  // reduce => extractData, eventAllowed, setNewState

  /// The event is rejected because it arrived in an unexpected state.
  ///
  /// No state changes occur, and the event is dropped from the publisher chain.
  case ignore

  /// The event is accepted and processed, but the state remains unchanged.
  ///
  /// This represents an internal transition (the state transitions into itself).
  /// The associated `Output` value is forwarded downstream to trigger side effects.
  case handled(output: Output)

  /// The event is accepted, mutating the current state and forwarding data downstream.
  ///
  /// This represents an external transition to a new state. The associated `Output`
  /// value is forwarded downstream to trigger side effects.
  case transition(to: State, output: Output)
}

@available(*, unavailable, message: "EventOutcome is restricted to local use within a reducing function. Use it only as a transient result, not as a sendable value.")
extension EventOutcome: Sendable {}

extension EventOutcome where Output == Void {
  public static var handled: Self {
    .handled(output: Void())
  }

  public static func transition(to newState: State) -> Self {
    .transition(to: newState, output: Void())
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - EventFilteringResult

public enum EventFilteringResult<State, Output>: ~Copyable {
  // reduce => event ignored
  // reduce => extractData, eventAllowed

  /// The event is rejected because it arrived in an unexpected state.
  ///
  /// No state changes occur, and the event is dropped from the publisher chain.
  case ignore

  /// The event is accepted and processed, but the state remains unchanged.
  ///
  /// This represents an internal transition (the state transitions into itself).
  /// The associated `Output` value is forwarded downstream to trigger side effects.
  case handled(output: Output)
}

@available(*, unavailable, message: "EventFilteringResult is restricted to local use within a reducing function. Use it only as a transient result, not as a sendable value.")
extension EventFilteringResult: Sendable {}

extension EventFilteringResult where Output == Void {
  public static var handled: Self {
    .handled(output: Void())
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - EventReducingResult

public enum EventReducingResult<State>: ~Copyable {
  /// The event is rejected because it arrived in an unexpected state.
  ///
  /// No state changes occur, and the event is dropped from the publisher chain.
  case ignore
  
  /// The event is accepted, mutating the current state.
  case transition(to: State)
}

@available(*, unavailable, message: "EventReducingResult is restricted to local use within a reducing function. Use it only as a transient result, not as a sendable value.")
extension EventReducingResult: Sendable {}
